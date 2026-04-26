package com.example.wordsnap

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "wordsnap/image_processing",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareRecognitionImage" -> handlePrepareRecognitionImage(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handlePrepareRecognitionImage(call: MethodCall, result: MethodChannel.Result) {
        try {
            val imagePath = call.argument<String>("imagePath")
                ?: throw IllegalArgumentException("missing imagePath")
            val left = call.argument<Double>("left") ?: 0.0
            val top = call.argument<Double>("top") ?: 0.0
            val right = call.argument<Double>("right") ?: 1.0
            val bottom = call.argument<Double>("bottom") ?: 1.0
            val maxLongSide = call.argument<Int>("maxLongSide") ?: 2200

            val imageFile = File(imagePath)
            if (!imageFile.exists()) {
                throw IllegalArgumentException("image file not found")
            }

            val originalBytes = imageFile.length().toInt()
            val decodedBitmap = BitmapFactory.decodeFile(imagePath)
                ?: throw IllegalStateException("unable to decode image")
            val orientedBitmap = applyExifOrientation(decodedBitmap, imagePath)

            val normalizedLeft = left.coerceIn(0.0, 1.0)
            val normalizedTop = top.coerceIn(0.0, 1.0)
            val normalizedRight = right.coerceIn(0.0, 1.0)
            val normalizedBottom = bottom.coerceIn(0.0, 1.0)
            val cropLeft = (normalizedLeft * orientedBitmap.width).roundToInt()
                .coerceIn(0, max(0, orientedBitmap.width - 1))
            val cropTop = (normalizedTop * orientedBitmap.height).roundToInt()
                .coerceIn(0, max(0, orientedBitmap.height - 1))
            val cropRight = (normalizedRight * orientedBitmap.width).roundToInt()
                .coerceIn(cropLeft + 1, orientedBitmap.width)
            val cropBottom = (normalizedBottom * orientedBitmap.height).roundToInt()
                .coerceIn(cropTop + 1, orientedBitmap.height)
            val cropWidth = max(1, cropRight - cropLeft)
            val cropHeight = max(1, cropBottom - cropTop)
            val didCrop =
                cropLeft > 0 ||
                    cropTop > 0 ||
                    cropRight < orientedBitmap.width ||
                    cropBottom < orientedBitmap.height

            val croppedBitmap = Bitmap.createBitmap(
                orientedBitmap,
                cropLeft,
                cropTop,
                cropWidth,
                cropHeight,
            )
            val scaledBitmap = scaleBitmapIfNeeded(croppedBitmap, maxLongSide)
            val didResize =
                scaledBitmap.width != croppedBitmap.width ||
                    scaledBitmap.height != croppedBitmap.height

            if (decodedBitmap !== orientedBitmap && !decodedBitmap.isRecycled) {
                decodedBitmap.recycle()
            }
            if (orientedBitmap !== croppedBitmap && !orientedBitmap.isRecycled) {
                orientedBitmap.recycle()
            }
            if (croppedBitmap !== scaledBitmap && !croppedBitmap.isRecycled) {
                croppedBitmap.recycle()
            }

            val compressed = compressToSmallerJpeg(
                bitmap = scaledBitmap,
                originalBytes = originalBytes,
            )
            val outputFile = File(
                cacheDir,
                "wordsnap-recognition-${System.currentTimeMillis()}.jpg",
            )
            outputFile.writeBytes(compressed.bytes)

            if (!scaledBitmap.isRecycled) {
                scaledBitmap.recycle()
            }

            result.success(
                mapOf(
                    "path" to outputFile.absolutePath,
                    "originalBytes" to originalBytes,
                    "outputBytes" to compressed.bytes.size,
                    "width" to compressed.width,
                    "height" to compressed.height,
                    "quality" to compressed.quality,
                    "didCrop" to didCrop,
                    "didResize" to (didResize || compressed.didExtraResize),
                ),
            )
        } catch (error: Exception) {
            result.error("image_processing_failed", error.message, null)
        }
    }

    private fun applyExifOrientation(bitmap: Bitmap, imagePath: String): Bitmap {
        val exif = ExifInterface(imagePath)
        val orientation = exif.getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
            else -> return bitmap
        }

        return Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            matrix,
            true,
        )
    }

    private fun scaleBitmapIfNeeded(bitmap: Bitmap, maxLongSide: Int): Bitmap {
        val longestSide = max(bitmap.width, bitmap.height)
        if (longestSide <= maxLongSide) {
            return bitmap
        }

        val ratio = maxLongSide.toDouble() / longestSide.toDouble()
        val targetWidth = max(1, (bitmap.width * ratio).roundToInt())
        val targetHeight = max(1, (bitmap.height * ratio).roundToInt())
        return Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true)
    }

    private fun compressToSmallerJpeg(
        bitmap: Bitmap,
        originalBytes: Int,
    ): CompressedResult {
        var workingBitmap = bitmap
        var bestBytes: ByteArray? = null
        var bestQuality = 92
        var didExtraResize = false
        val qualities = listOf(92, 88, 84, 80, 76, 72, 68, 64, 60, 56, 52, 48, 44, 40)

        for (attempt in 0 until 5) {
            for (quality in qualities) {
                val output = ByteArrayOutputStream()
                workingBitmap.compress(Bitmap.CompressFormat.JPEG, quality, output)
                val bytes = output.toByteArray()
                if (bestBytes == null || bytes.size < bestBytes!!.size) {
                    bestBytes = bytes
                    bestQuality = quality
                }
                if (bytes.size < originalBytes) {
                    return CompressedResult(
                        bytes = bytes,
                        quality = quality,
                        width = workingBitmap.width,
                        height = workingBitmap.height,
                        didExtraResize = didExtraResize,
                    )
                }
            }

            if (attempt == 4) {
                break
            }

            val nextWidth = max(1, (workingBitmap.width * 0.85).roundToInt())
            val nextHeight = max(1, (workingBitmap.height * 0.85).roundToInt())
            if (nextWidth == workingBitmap.width && nextHeight == workingBitmap.height) {
                break
            }
            val resized = Bitmap.createScaledBitmap(workingBitmap, nextWidth, nextHeight, true)
            if (workingBitmap !== bitmap && !workingBitmap.isRecycled) {
                workingBitmap.recycle()
            }
            workingBitmap = resized
            didExtraResize = true
        }

        val fallbackBytes = bestBytes
            ?: throw IllegalStateException("unable to compress image")
        if (fallbackBytes.size >= originalBytes) {
            throw IllegalStateException("compressed image is still not smaller than original")
        }
        return CompressedResult(
            bytes = fallbackBytes,
            quality = bestQuality,
            width = workingBitmap.width,
            height = workingBitmap.height,
            didExtraResize = didExtraResize,
        )
    }

    private data class CompressedResult(
        val bytes: ByteArray,
        val quality: Int,
        val width: Int,
        val height: Int,
        val didExtraResize: Boolean,
    )
}
