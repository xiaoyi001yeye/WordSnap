import Flutter
import UIKit
import Vision

class SceneDelegate: FlutterSceneDelegate {
  private let ocrChannelName = "com.example.wordsnap/native_ocr"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let flutterViewController = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: ocrChannelName,
      binaryMessenger: flutterViewController.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(
          FlutterError(
            code: "ocr_unavailable",
            message: "系统 OCR 当前不可用。",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "recognizeImage":
        guard
          let arguments = call.arguments as? [String: Any],
          let imagePath = arguments["imagePath"] as? String,
          !imagePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
          result(
            FlutterError(
              code: "invalid_args",
              message: "缺少图片路径。",
              details: nil
            )
          )
          return
        }
        self.recognizeImage(at: imagePath, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func recognizeImage(
    at imagePath: String,
    result: @escaping FlutterResult
  ) {
    let imageUrl = URL(fileURLWithPath: imagePath)
    guard FileManager.default.fileExists(atPath: imagePath) else {
      result(
        FlutterError(
          code: "missing_file",
          message: "待识别图片不存在，请重新选择图片。",
          details: nil
        )
      )
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let request = VNRecognizeTextRequest { request, error in
        if let error {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "ocr_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
          return
        }

        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let lines = observations.compactMap { observation -> [String: Any]? in
          guard let candidate = observation.topCandidates(1).first else {
            return nil
          }

          let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
          if text.isEmpty {
            return nil
          }

          return [
            "text": text,
            "score": Double(candidate.confidence),
          ]
        }

        let fullText = lines
          .compactMap { $0["text"] as? String }
          .joined(separator: "\n")

        DispatchQueue.main.async {
          result([
            "lines": lines,
            "fullText": fullText,
            "engineLabel": "iOS Vision",
          ])
        }
      }

      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = false

      do {
        let handler = VNImageRequestHandler(url: imageUrl, options: [:])
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "ocr_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }
}
