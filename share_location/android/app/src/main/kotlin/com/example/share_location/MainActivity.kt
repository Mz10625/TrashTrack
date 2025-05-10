package com.example.share_location

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log


class MainActivity: FlutterActivity() {
    private val CHANNEL = "trash_track/app_lifecycle"
    private val TAG = "MainActivity"


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        try{
            if (flutterEngine != null) {
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("onAppTerminate", null)
            }
        }
        catch (e: Exception) {
            Log.e(TAG, "Failed to clean up background location services: ${e}")
        }
        finally{
            super.onDestroy()
        }
    }
}