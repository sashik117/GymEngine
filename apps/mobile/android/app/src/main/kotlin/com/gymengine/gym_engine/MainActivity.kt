package com.gymengine.gym_engine

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

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

                else -> result.notImplemented()
            }
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
}
