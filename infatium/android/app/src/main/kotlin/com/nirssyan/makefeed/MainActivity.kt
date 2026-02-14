package com.nirssyan.makefeed

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
