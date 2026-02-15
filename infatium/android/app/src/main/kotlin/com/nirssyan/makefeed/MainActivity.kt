package com.nirssyan.makefeed

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.nirssyan.makefeed/app_icon"
        private const val NAMESPACE = "com.nirssyan.makefeed"
        private val ALIASES = listOf("MainActivityDefault", "MainActivityLight")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        val iconName = call.argument<String>("iconName")
                        if (iconName == null || iconName !in ALIASES) {
                            result.error("INVALID_ICON", "Unknown icon: $iconName", null)
                            return@setMethodCallHandler
                        }
                        try {
                            setIcon(iconName)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SET_ICON_FAILED", e.message, null)
                        }
                    }
                    "getCurrentIcon" -> {
                        result.success(getCurrentIcon())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setIcon(targetAlias: String) {
        val pm = packageManager

        // Enable target alias first (so there's always a launcher)
        pm.setComponentEnabledSetting(
            ComponentName(packageName, "$NAMESPACE.$targetAlias"),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )

        // Disable all other aliases
        for (alias in ALIASES) {
            if (alias != targetAlias) {
                pm.setComponentEnabledSetting(
                    ComponentName(packageName, "$NAMESPACE.$alias"),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        }

        Log.d("AppIcon", "Icon switched to $targetAlias (package: $packageName)")
    }

    private fun getCurrentIcon(): String {
        val pm = packageManager
        for (alias in ALIASES) {
            val state = pm.getComponentEnabledSetting(
                ComponentName(packageName, "$NAMESPACE.$alias")
            )
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT) {
                // Check if this alias is actually enabled in manifest (default state)
                if (state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT) {
                    // Default state means "use what's in the manifest"
                    // MainActivityDefault has android:enabled="true" in manifest
                    // MainActivityLight has android:enabled="false"
                    if (alias == "MainActivityDefault") return alias
                } else {
                    return alias
                }
            }
        }
        return "MainActivityDefault"
    }

    override fun onNewIntent(intent: Intent) {
        // CRITICAL: Update intent BEFORE calling super.onNewIntent()
        // This ensures VK SDK and other plugins see the correct intent
        // when they process it in super.onNewIntent()
        setIntent(intent)

        // Now let plugins (VK SDK, app_links, etc.) process the updated intent
        super.onNewIntent(intent)

        // Log deep link for debugging
        val uri = intent.data
        if (uri != null) {
            Log.d("MainActivity", "Deep link received: $uri")
            if (uri.scheme?.startsWith("vk") == true) {
                Log.d("MainActivity", "VK OAuth callback - intent set before super")
            }
        }
    }
}
