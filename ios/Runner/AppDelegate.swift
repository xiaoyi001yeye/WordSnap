import Flutter
import AVFoundation
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let imageProcessingChannelName = "wordsnap/image_processing"
  private let pronunciationChannelName = "wordsnap/pronunciation"
  private let feedbackChannelName = "wordsnap/feedback"
  private let shareChannelName = "wordsnap/share"
  private let speechSynthesizer = AVSpeechSynthesizer()
  private var pronunciationPlayer: AVPlayer?
  private var answerFeedbackPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let imageProcessingChannel = FlutterMethodChannel(
        name: imageProcessingChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      imageProcessingChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleImageProcessing(call: call, result: result)
      }

      let pronunciationChannel = FlutterMethodChannel(
        name: pronunciationChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      pronunciationChannel.setMethodCallHandler { [weak self] call, result in
        self?.handlePronunciation(call: call, result: result)
      }

      let feedbackChannel = FlutterMethodChannel(
        name: feedbackChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      feedbackChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleFeedback(call: call, result: result)
      }

      let shareChannel = FlutterMethodChannel(
        name: shareChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      shareChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleShare(call: call, result: result)
      }
      try? ensureAnswerFeedbackPlayer()
    }
    return didFinish
  }

  private func handleImageProcessing(call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "recognizeText" {
      handleRecognizeText(call: call, result: result)
      return
    }

    guard call.method == "prepareRecognitionImage" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard
      let args = call.arguments as? [String: Any],
      let imagePath = args["imagePath"] as? String,
      let sourceImage = UIImage(contentsOfFile: imagePath)
    else {
      result(FlutterError(code: "image_processing_failed", message: "invalid image arguments", details: nil))
      return
    }

    let left = (args["left"] as? Double ?? 0).clamped(to: 0...1)
    let top = (args["top"] as? Double ?? 0).clamped(to: 0...1)
    let right = (args["right"] as? Double ?? 1).clamped(to: 0...1)
    let bottom = (args["bottom"] as? Double ?? 1).clamped(to: 0...1)
    let maxLongSide = args["maxLongSide"] as? Int ?? 2200
    let normalizedImage = sourceImage.wordsnapNormalized()
    let originalBytes = (try? Data(contentsOf: URL(fileURLWithPath: imagePath)).count) ?? 0

    guard let cgImage = normalizedImage.cgImage else {
      result(FlutterError(code: "image_processing_failed", message: "unable to decode image", details: nil))
      return
    }

    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    let cropRect = CGRect(
      x: width * left,
      y: height * top,
      width: max(1, width * max(0.001, right - left)),
      height: max(1, height * max(0.001, bottom - top))
    ).integral
    let safeCropRect = cropRect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
    guard let croppedCgImage = cgImage.cropping(to: safeCropRect) else {
      result(FlutterError(code: "image_processing_failed", message: "unable to crop image", details: nil))
      return
    }

    let croppedImage = UIImage(cgImage: croppedCgImage)
    let scaledImage = croppedImage.wordsnapScaled(maxLongSide: CGFloat(maxLongSide))
    let didCrop = safeCropRect.origin.x > 0 ||
      safeCropRect.origin.y > 0 ||
      safeCropRect.width < width ||
      safeCropRect.height < height
    let didResize = Int(scaledImage.size.width.rounded()) != Int(croppedImage.size.width.rounded()) ||
      Int(scaledImage.size.height.rounded()) != Int(croppedImage.size.height.rounded())

    do {
      let compressed = try scaledImage.wordsnapCompressedSmaller(than: originalBytes)
      let outputPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(
        "wordsnap-recognition-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
      )
      try compressed.data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
      result([
        "path": outputPath,
        "originalBytes": originalBytes,
        "outputBytes": compressed.data.count,
        "width": Int(scaledImage.size.width.rounded()),
        "height": Int(scaledImage.size.height.rounded()),
        "quality": compressed.quality,
        "didCrop": didCrop,
        "didResize": didResize || compressed.didExtraResize,
      ])
    } catch {
      result(FlutterError(code: "image_processing_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func handleRecognizeText(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 13.0, *) else {
      result(FlutterError(code: "native_ocr_failed", message: "iOS 13 or later is required for Vision OCR", details: nil))
      return
    }

    guard
      let args = call.arguments as? [String: Any],
      let imagePath = args["imagePath"] as? String,
      FileManager.default.fileExists(atPath: imagePath)
    else {
      result(FlutterError(code: "native_ocr_failed", message: "invalid image path", details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let imageUrl = URL(fileURLWithPath: imagePath)
      let request = VNRecognizeTextRequest { request, error in
        if let error = error {
          DispatchQueue.main.async {
            result(FlutterError(code: "native_ocr_failed", message: error.localizedDescription, details: nil))
          }
          return
        }

        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let candidates = observations.compactMap { observation in
          observation.topCandidates(1).first
        }
        let lines = candidates
          .map { candidate in
            [
              "text": candidate.string,
              "score": Double(candidate.confidence),
            ] as [String: Any]
          }
          .filter { item in
            guard let text = item["text"] as? String else {
              return false
            }
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          }
        let fullText = candidates.map(\.string).joined(separator: "\n")
        let averageScore = candidates.isEmpty
          ? 0.85
          : candidates
              .map { Double($0.confidence) }
              .reduce(0.0, +) / Double(candidates.count)

        DispatchQueue.main.async {
          result([
            "fullText": fullText,
            "lines": lines,
            "averageScore": averageScore,
            "engineLabel": "iOS Vision OCR",
          ])
        }
      }
      request.recognitionLevel = .accurate
      request.recognitionLanguages = ["zh-Hans", "en-US"]
      request.usesLanguageCorrection = true

      do {
        let handler = VNImageRequestHandler(url: imageUrl, options: [:])
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "native_ocr_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func handlePronunciation(call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "playAudioUrl" {
      handlePronunciationAudio(call: call, result: result)
      return
    }

    guard call.method == "speakWord" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard
      let args = call.arguments as? [String: Any],
      let word = (args["word"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
      !word.isEmpty
    else {
      result(FlutterError(code: "pronunciation_failed", message: "missing word", details: nil))
      return
    }

    if speechSynthesizer.isSpeaking {
      speechSynthesizer.stopSpeaking(at: .immediate)
    }

    let utterance = AVSpeechUtterance(string: word)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = 0.46
    speechSynthesizer.speak(utterance)
    result(nil)
  }

  private func handlePronunciationAudio(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let rawUrl = (args["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
      let url = URL(string: rawUrl),
      !rawUrl.isEmpty
    else {
      result(FlutterError(code: "pronunciation_failed", message: "missing audio url", details: nil))
      return
    }

    if speechSynthesizer.isSpeaking {
      speechSynthesizer.stopSpeaking(at: .immediate)
    }

    try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    let player = AVPlayer(url: url)
    pronunciationPlayer = player
    player.play()
    result(nil)
  }

  private func handleFeedback(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "playAnswerSelected" else {
      result(FlutterMethodNotImplemented)
      return
    }

    do {
      let player = try ensureAnswerFeedbackPlayer()
      player.currentTime = 0
      player.play()
      result(nil)
    } catch {
      result(FlutterError(code: "feedback_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func handleShare(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "shareImage" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard
      let args = call.arguments as? [String: Any],
      let imagePath = args["imagePath"] as? String,
      FileManager.default.fileExists(atPath: imagePath)
    else {
      result(FlutterError(code: "share_failed", message: "invalid image path", details: nil))
      return
    }

    var items: [Any] = [URL(fileURLWithPath: imagePath)]
    if let text = args["text"] as? String, !text.isEmpty {
      items.append(text)
    }

    DispatchQueue.main.async { [weak self] in
      guard let controller = self?.window?.rootViewController else {
        result(FlutterError(code: "share_failed", message: "root view controller unavailable", details: nil))
        return
      }

      let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
      if let popover = activityController.popoverPresentationController {
        popover.sourceView = controller.view
        popover.sourceRect = CGRect(
          x: controller.view.bounds.midX,
          y: controller.view.bounds.midY,
          width: 0,
          height: 0
        )
        popover.permittedArrowDirections = []
      }
      controller.present(activityController, animated: true)
      result(nil)
    }
  }

  private func ensureAnswerFeedbackPlayer() throws -> AVAudioPlayer {
    if let player = answerFeedbackPlayer {
      return player
    }

    let assetKey = FlutterDartProject.lookupKey(forAsset: "bell_fast.wav")
    guard let assetPath = Bundle.main.path(forResource: assetKey, ofType: nil) else {
      throw NSError(
        domain: "WordSnapFeedback",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "answer feedback sound not found"]
      )
    }

    try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: assetPath))
    player.prepareToPlay()
    answerFeedbackPlayer = player
    return player
  }
}

private struct CompressedImageResult {
  let data: Data
  let quality: Int
  let didExtraResize: Bool
}

private extension UIImage {
  func wordsnapNormalized() -> UIImage {
    if imageOrientation == .up {
      return self
    }

    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }

  func wordsnapScaled(maxLongSide: CGFloat) -> UIImage {
    let longestSide = max(size.width, size.height)
    if longestSide <= maxLongSide {
      return self
    }

    let ratio = maxLongSide / longestSide
    let targetSize = CGSize(
      width: max(1, (size.width * ratio).rounded()),
      height: max(1, (size.height * ratio).rounded())
    )
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }

  func wordsnapCompressedSmaller(than originalBytes: Int) throws -> CompressedImageResult {
    let qualities: [CGFloat] = [0.92, 0.88, 0.84, 0.80, 0.76, 0.72, 0.68, 0.64, 0.60, 0.56, 0.52, 0.48, 0.44, 0.40]
    var workingImage = self
    var bestData: Data?
    var bestQuality = 92
    var didExtraResize = false

    for attempt in 0..<5 {
      for quality in qualities {
        guard let data = workingImage.jpegData(compressionQuality: quality) else {
          continue
        }
        if bestData == nil || data.count < bestData!.count {
          bestData = data
          bestQuality = Int((quality * 100).rounded())
        }
        if data.count < originalBytes {
          return CompressedImageResult(
            data: data,
            quality: Int((quality * 100).rounded()),
            didExtraResize: didExtraResize
          )
        }
      }

      if attempt == 4 {
        break
      }

      let nextSize = CGSize(
        width: max(1, (workingImage.size.width * 0.85).rounded()),
        height: max(1, (workingImage.size.height * 0.85).rounded())
      )
      if nextSize == workingImage.size {
        break
      }
      let renderer = UIGraphicsImageRenderer(size: nextSize)
      workingImage = renderer.image { _ in
        workingImage.draw(in: CGRect(origin: .zero, size: nextSize))
      }
      didExtraResize = true
    }

    guard let fallback = bestData, fallback.count < originalBytes else {
      throw NSError(
        domain: "WordSnapImageProcessing",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "compressed image is still not smaller than original"]
      )
    }
    return CompressedImageResult(
      data: fallback,
      quality: bestQuality,
      didExtraResize: didExtraResize
    )
  }
}

private extension Comparable {
  func clamped(to limits: ClosedRange<Self>) -> Self {
    min(max(self, limits.lowerBound), limits.upperBound)
  }
}
