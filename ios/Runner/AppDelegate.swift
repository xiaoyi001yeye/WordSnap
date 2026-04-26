import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let imageProcessingChannelName = "wordsnap/image_processing"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: imageProcessingChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleImageProcessing(call: call, result: result)
      }
    }
    return didFinish
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func handleImageProcessing(call: FlutterMethodCall, result: @escaping FlutterResult) {
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
