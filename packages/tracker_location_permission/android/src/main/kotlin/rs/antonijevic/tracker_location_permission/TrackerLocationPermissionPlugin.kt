package rs.antonijevic.tracker_location_permission

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Android 11+ silently ignores a permission request that bundles
 * ACCESS_BACKGROUND_LOCATION with the foreground ones: no dialog is shown and
 * nothing is granted. The `location` plugin's enableBackgroundMode asks for
 * ACCESS_FINE_LOCATION and ACCESS_BACKGROUND_LOCATION in one call, which is
 * why the "Allow all the time" step stopped appearing. This channel requests
 * the background half on its own, after the foreground one is already granted.
 *
 * One plugin for every tracker app, so the apps' MainActivity is the plain
 * FlutterActivity.
 */
class TrackerLocationPermissionPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener {

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        this.binding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val activity = this.activity
        if (activity == null) {
            result.error("no_activity", "No activity attached", null)
            return
        }
        when (call.method) {
            "hasBackgroundPermission" -> result.success(hasBackgroundPermission(activity))
            "requestBackgroundPermission" -> requestBackgroundPermission(activity, result)
            "requestPrecisePermission" -> requestPrecisePermission(activity, result)
            "openAppSettings" -> {
                activity.startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", activity.packageName, null)
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /** Below API 29 background location is covered by the foreground grant. */
    private fun hasBackgroundPermission(activity: Activity): Boolean =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            true
        } else {
            ContextCompat.checkSelfPermission(
                activity, Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        }

    private fun hasPrecisePermission(activity: Activity): Boolean =
        ContextCompat.checkSelfPermission(
            activity, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

    private fun requestBackgroundPermission(activity: Activity, result: MethodChannel.Result) {
        if (hasBackgroundPermission(activity)) {
            result.success(true)
            return
        }
        request(activity, result, Manifest.permission.ACCESS_BACKGROUND_LOCATION, BACKGROUND_PERMISSION_REQUEST_CODE)
    }

    /**
     * "Approximate location" (Android 12+) is a real grant of COARSE only. The
     * `location` plugin treats coarse as granted and returns at once, so it
     * never shows the system's upgrade-to-precise dialog; a request for
     * ACCESS_FINE_LOCATION on its own is what brings that dialog up.
     */
    private fun requestPrecisePermission(activity: Activity, result: MethodChannel.Result) {
        if (hasPrecisePermission(activity)) {
            result.success(true)
            return
        }
        request(activity, result, Manifest.permission.ACCESS_FINE_LOCATION, PRECISE_PERMISSION_REQUEST_CODE)
    }

    private fun request(activity: Activity, result: MethodChannel.Result, permission: String, requestCode: Int) {
        if (pendingResult != null) {
            /// a request is already on screen — never leave two Dart futures
            /// waiting on a single system callback
            result.success(false)
            return
        }
        pendingResult = result
        ActivityCompat.requestPermissions(activity, arrayOf(permission), requestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        val activity = this.activity ?: return false

        /// On Android 11+ the background request opens the app's location
        /// settings page rather than a dialog, and comes back with empty
        /// grantResults, so the live permission state is the only reliable
        /// answer here.
        val granted = when (requestCode) {
            BACKGROUND_PERMISSION_REQUEST_CODE -> hasBackgroundPermission(activity)
            PRECISE_PERMISSION_REQUEST_CODE -> hasPrecisePermission(activity)
            else -> return false
        }
        pendingResult?.success(granted)
        pendingResult = null
        return true
    }

    companion object {
        const val CHANNEL = "rs.antonijevic.tracker/background_location"

        /// distinct from the location plugin's own request code
        private const val BACKGROUND_PERMISSION_REQUEST_CODE = 4211
        private const val PRECISE_PERMISSION_REQUEST_CODE = 4212
    }
}
