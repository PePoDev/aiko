package dev.pepo.aiko

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// A FragmentActivity: local_auth shows its fingerprint/face prompt in a fragment.
class MainActivity : FlutterFragmentActivity() {
    private var capture: CaptureBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        capture = CaptureBridge(this).also {
            it.attach(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        capture?.detach()
        capture = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (capture?.onActivityResult(requestCode) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
