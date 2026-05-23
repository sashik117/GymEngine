package com.gymengine.gym_engine

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

object RestNotificationScheduler {
    const val channelName = "gym_engine/rest_notifications"
    const val permissionRequestCode = 4180
    private const val notificationChannelId = "gym_engine_rest_timer"
    private const val notificationId = 4181
    private const val alarmRequestCode = 4182
    private const val launchRequestCode = 4183
    private const val extraTitle = "title"
    private const val extraBody = "body"

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            notificationChannelId,
            "GymEngine rest timer",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Signals when rest between sets is over."
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 120, 90, 120, 90, 160)
        }

        notificationManager(context).createNotificationChannel(channel)
    }

    fun schedule(context: Context, seconds: Int, title: String, body: String) {
        createChannel(context)
        cancel(context)

        val intent = Intent(context, RestNotificationReceiver::class.java).apply {
            putExtra(extraTitle, title)
            putExtra(extraBody, body)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmRequestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val triggerAt = System.currentTimeMillis() + seconds.coerceAtLeast(1) * 1000L
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    fun cancel(context: Context) {
        val intent = Intent(context, RestNotificationReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmRequestCode,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        if (pendingIntent != null) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    fun show(context: Context, title: String, body: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        createChannel(context)

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                context,
                launchRequestCode,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, notificationChannelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .setVibrate(longArrayOf(0, 120, 90, 120, 90, 160))
            .build()

        notificationManager(context).notify(notificationId, notification)
    }

    private fun notificationManager(context: Context): NotificationManager {
        return context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }

    fun titleFrom(intent: Intent): String {
        return intent.getStringExtra(extraTitle) ?: "GymEngine"
    }

    fun bodyFrom(intent: Intent): String {
        return intent.getStringExtra(extraBody) ?: "Rest is over."
    }
}

class RestNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        RestNotificationScheduler.show(
            context = context,
            title = RestNotificationScheduler.titleFrom(intent),
            body = RestNotificationScheduler.bodyFrom(intent)
        )
    }
}
