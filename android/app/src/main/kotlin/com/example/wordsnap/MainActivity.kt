package com.example.wordsnap

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OCR_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "recognizeImage" -> {
                    val imagePath = call.argument<String>("imagePath")
                    if (imagePath.isNullOrBlank()) {
                        result.error("invalid_args", "缺少图片路径。", null)
                        return@setMethodCallHandler
                    }
                    recognizeImage(imagePath, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun recognizeImage(
        imagePath: String,
        result: MethodChannel.Result,
    ) {
        val imageFile = File(imagePath)
        if (!imageFile.exists()) {
            result.error("missing_file", "待识别图片不存在，请重新选择图片。", null)
            return
        }

        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        try {
            val image = InputImage.fromFilePath(this, Uri.fromFile(imageFile))
            recognizer
                .process(image)
                .addOnSuccessListener { visionText ->
                    val lines = mutableListOf<Map<String, Any>>()
                    for (block in visionText.textBlocks) {
                        for (line in block.lines) {
                            val text = line.text.trim()
                            if (text.isEmpty()) {
                                continue
                            }

                            lines.add(
                                mapOf(
                                    "text" to text,
                                    "score" to DEFAULT_LINE_SCORE,
                                ),
                            )
                        }
                    }

                    result.success(
                        mapOf(
                            "lines" to lines,
                            "fullText" to lines.joinToString("\n") { it["text"].toString() },
                            "engineLabel" to "Android ML Kit",
                        ),
                    )
                    recognizer.close()
                }
                .addOnFailureListener { error ->
                    result.error(
                        "ocr_failed",
                        error.localizedMessage ?: "系统 OCR 识别失败，请稍后重试。",
                        null,
                    )
                    recognizer.close()
                }
        } catch (error: Exception) {
            recognizer.close()
            result.error(
                "ocr_failed",
                error.localizedMessage ?: "系统 OCR 识别失败，请稍后重试。",
                null,
            )
        }
    }

    companion object {
        private const val OCR_CHANNEL = "com.example.wordsnap/native_ocr"
        private const val DEFAULT_LINE_SCORE = 0.9
    }
}
