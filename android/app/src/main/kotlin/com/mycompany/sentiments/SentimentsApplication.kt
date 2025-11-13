package com.mycompany.sentiments

import android.app.Application
import android.util.Log
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger

class SentimentsApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Initialize Facebook SDK with error handling
        try {
            FacebookSdk.setAutoInitEnabled(true)
            FacebookSdk.setAutoLogAppEventsEnabled(true)
            FacebookSdk.fullyInitialize()
            AppEventsLogger.activateApp(this)
            Log.d("SentimentsApp", "Facebook SDK initialized successfully")
        } catch (e: Exception) {
            Log.e("SentimentsApp", "Error initializing Facebook SDK: ${e.message}", e)
            // Continue app initialization even if Facebook SDK fails
        }
    }
}