package rs.antonijevic.herp_tracker

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android 11+ silently ignores a permission request that bundles
 * ACCESS_BACKGROUND_LOCATION with the foreground ones: no dialog is shown and
 * nothing is granted. The `location` plugin's enableBackgroundMode asks for
 * ACCESS_FINE_LOCATION and ACCESS_BACKGROUND_LOCATION in one call, which is
 * why the "Allow all the time" step stopped appearing. This channel requests
 * the background half on its own, after the foreground one is already granted.
 */
class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> onMethodCall(call, result) }
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasBackgroundPermission" -> result.success(hasBackgroundPermission())
            "requestBackgroundPermission" -> requestBackgroundPermission(result)
            "openAppSettings" -> {
                startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null)
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /** Below API 29 background location is covered by the foreground grant. */
    private fun hasBackgroundPermission(): Boolean =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            true
        } else {
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        }

    private fun requestBackgroundPermission(result: MethodChannel.Result) {
        if (hasBackgroundPermission()) {
            result.success(true)
            return
        }
        if (pendingResult != null) {
            /// a request is already on screen — never leave two Dart futures
            /// waiting on a single system callback
            result.success(false)
            return
        }
        pendingResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            BACKGROUND_PERMISSION_REQUEST_CODE
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != BACKGROUND_PERMISSION_REQUEST_CODE) return

        /// On Android 11+ the request opens the app's location settings page
        /// rather than a dialog, and comes back with empty grantResults, so
        /// the live permission state is the only reliable answer here.
        pendingResult?.success(hasBackgroundPermission())
        pendingResult = null
    }

    companion object {
        private const val CHANNEL = "rs.antonijevic.herp_tracker/background_location"

        /// distinct from the location plugin's own request code
        private const val BACKGROUND_PERMISSION_REQUEST_CODE = 4211
    }
}
