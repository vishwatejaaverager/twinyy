package com.privateai.privateai_app

import android.app.RemoteInput
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class MyNotificationListenerService : NotificationListenerService() {

    private val TAG = "MyNotificationListener"
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private var instance: MyNotificationListenerService? = null
        private val notificationMap = ConcurrentHashMap<String, StatusBarNotification>()

        fun sendReply(notificationKey: String, message: String): Boolean {
            val sbn = notificationMap[notificationKey] ?: return false
            return instance?.replyToNotification(sbn, message) ?: false
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) instance = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val pkg = sbn.packageName ?: return
        // Filter for Teams and WhatsApp
        if (pkg != "com.microsoft.teams" && pkg != "com.whatsapp") return

        val extras = sbn.notification.extras
        val title = extras.getString("android.title") ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val ts = sbn.postTime
        val key = sbn.key ?: return

        notificationMap[key] = sbn

        Log.d(TAG, "Incoming Notification ($pkg): $title - $text (Key: $key)")

        // 1. Store notification locally
        saveNotification(key, pkg, title, text, ts)

        // 2. Notify Flutter on the main thread (handled by Firebase AI + Cloud Firestore)
        val notificationData = mapOf(
            "key" to key,
            "package" to pkg,
            "title" to title,
            "text" to text,
            "timestamp" to ts
        )
        mainHandler.post {
            MainActivity.notifyFlutter("onNotificationReceived", notificationData)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        val k = sbn?.key
        if (k != null) {
            notificationMap.remove(k)
        }
    }

    fun replyToNotification(sbn: StatusBarNotification, message: String): Boolean {
        val actions = sbn.notification.actions ?: return false

        for (action in actions) {
            val remoteInputs = action.remoteInputs ?: continue
            for (remoteInput in remoteInputs) {
                try {
                    val resultBundle = Bundle()
                    resultBundle.putCharSequence(remoteInput.resultKey, message)

                    val intent = Intent()
                    RemoteInput.addResultsToIntent(arrayOf(remoteInput), intent, resultBundle)

                    action.actionIntent.send(applicationContext, 0, intent)
                    Log.d(TAG, "Reply sent successfully for ${sbn.key}")
                    return true
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to send reply: ${e.message}")
                }
            }
        }
        return false
    }

    private fun saveNotification(key: String, pkg: String, title: String, text: String, ts: Long) {
        try {
            val dir = File(filesDir, "memory")
            if (!dir.exists()) dir.mkdirs()

            val file = File(dir, "notifications.json")
            val root = if (file.exists()) {
                try { JSONObject(file.readText()) } catch (e: Exception) { JSONObject() }
            } else {
                JSONObject()
            }

            if (!root.has("notifications")) {
                root.put("notifications", JSONArray())
            }

            val notifications = root.getJSONArray("notifications")

            for (i in 0 until notifications.length()) {
                val item = notifications.getJSONObject(i)
                if (item.optString("key") == key) {
                    return // Already saved
                }
            }

            val notificationObj = JSONObject().apply {
                put("key", key)
                put("package", pkg)
                put("title", title)
                put("text", text)
                put("timestamp", ts)
            }

            notifications.put(notificationObj)
            file.writeText(root.toString(2))
        } catch (e: Exception) {
            Log.e(TAG, "Error saving notification: ${e.message}")
        }
    }
}
