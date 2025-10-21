package com.safekids.safekids_app

import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.safekids/device_usage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceUsage" -> {
                        val startTime = call.argument<Long>("startTime")
                        val endTime = call.argument<Long>("endTime")
                        
                        if (startTime != null && endTime != null) {
                            val usage = getDeviceUsage(startTime, endTime)
                            result.success(usage)
                        } else {
                            result.error("INVALID_ARGS", "startTime and endTime required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getDeviceUsage(startTime: Long, endTime: Long): Map<String, Any> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
        val usageMap = mutableMapOf<String, Any>()

        if (usageStatsManager != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val queryUsageStats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
            
            var totalAppUsageTime = 0L
            val appUsages = mutableListOf<Map<String, Any?>>()

            for (stat in queryUsageStats) {
                val packageName = stat.packageName
                val foregroundTime = stat.totalTimeInForeground
                
                if (foregroundTime > 0) {
                    totalAppUsageTime += foregroundTime
                    appUsages.add(mapOf(
                        "packageName" to packageName,
                        "totalTimeInForeground" to foregroundTime
                    ))
                }
            }

            usageMap["totalAppUsageMinutes"] = totalAppUsageTime / 60000 // Convert to minutes
            usageMap["appUsages"] = appUsages
        }

        return usageMap
    }
}
