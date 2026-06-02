package com.gymengine.gym_engine

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private var photoPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RestNotificationScheduler.channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    RestNotificationScheduler.createChannel(this)
                    result.success(true)
                }

                "requestPermission" -> requestNotificationPermission(result)

                "scheduleRestComplete" -> {
                    val seconds = call.argument<Int>("seconds") ?: 90
                    val title = call.argument<String>("title") ?: "GymEngine"
                    val body = call.argument<String>("body") ?: "Rest is over."

                    RestNotificationScheduler.schedule(
                        context = this,
                        seconds = seconds,
                        title = title,
                        body = body
                    )
                    result.success(true)
                }

                "cancelRestComplete" -> {
                    RestNotificationScheduler.cancel(this)
                    result.success(true)
                }

                "showTrainingOngoing" -> {
                    val title = call.argument<String>("title") ?: "GymEngine"
                    val body = call.argument<String>("body") ?: "Workout is running"

                    RestNotificationScheduler.showOngoing(
                        context = this,
                        title = title,
                        body = body
                    )
                    result.success(true)
                }

                "cancelTrainingOngoing" -> {
                    RestNotificationScheduler.cancelOngoing(this)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gym_engine/external_link"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    openExternalUrl(url, result)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "gym_engine/photo_picker"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickPhoto" -> pickPhoto(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun openExternalUrl(url: String, result: MethodChannel.Result) {
        if (url.isBlank()) {
            result.success(false)
            return
        }

        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            startActivity(intent)
            result.success(true)
        } catch (error: Exception) {
            result.success(false)
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        permissionResult?.success(false)
        permissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            RestNotificationScheduler.permissionRequestCode
        )
    }

    private fun pickPhoto(result: MethodChannel.Result) {
        photoPickerResult?.success(null)
        photoPickerResult = result

        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
            startActivityForResult(intent, photoPickerRequestCode)
        } catch (error: Exception) {
            photoPickerResult = null
            result.success(null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != RestNotificationScheduler.permissionRequestCode) {
            return
        }

        val isGranted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        permissionResult?.success(isGranted)
        permissionResult = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != photoPickerRequestCode) {
            return
        }

        val pendingResult = photoPickerResult ?: return
        photoPickerResult = null

        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            pendingResult.success(null)
            return
        }

        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (_: Exception) {
            // The one-time grant from ACTION_OPEN_DOCUMENT is enough for reading now.
        }

        try {
            val bytes = contentResolver.openInputStream(uri)?.use { stream ->
                stream.readBytes()
            } ?: ByteArray(0)
            if (bytes.isEmpty()) {
                pendingResult.success(null)
                return
            }

            pendingResult.success(
                mapOf(
                    "bytes" to bytes,
                    "mimeType" to (contentResolver.getType(uri) ?: "image/jpeg")
                )
            )
        } catch (_: Exception) {
            pendingResult.success(null)
        }
    }

    companion object {
        private const val photoPickerRequestCode = 4017
    }
}
