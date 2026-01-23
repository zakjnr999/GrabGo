package com.grabgo.customer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.grabgo.customer.location.NativeLocationPlugin

class MainActivity : FlutterActivity() {
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register Native Location Plugin
        flutterEngine.plugins.add(NativeLocationPlugin())
    }
}
