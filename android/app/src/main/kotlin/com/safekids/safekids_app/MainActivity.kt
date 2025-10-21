package com.safekids.safekids_app

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import com.google.android.gms.maps.MapsInitializer
import com.google.android.gms.maps.MapsInitializer.Renderer
import com.google.android.gms.maps.OnMapsSdkInitializedCallback

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        runCatching {
            MapsInitializer.initialize(
                applicationContext,
                Renderer.LATEST,
                object : OnMapsSdkInitializedCallback {
                    override fun onMapsSdkInitialized(renderer: Renderer) {
                        Log.i("[MAP_INIT]", "Maps initialized with renderer: $renderer")
                    }
                }
            )
        }.onFailure { throwable ->
            val status = MapsInitializer.initialize(applicationContext)
            Log.w("[MAP_INIT]", "Fallback initialize result: $status (reason: $throwable)")
        }
    }

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun getTransparencyMode(): TransparencyMode = TransparencyMode.opaque

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    }
}
