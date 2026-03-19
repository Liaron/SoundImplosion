package io.flutter.plugins

import io.flutter.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin

object GeneratedPluginRegistrant {
    private const val TAG = "GeneratedPluginRegistrant"

    @JvmStatic
    fun registerWith(flutterEngine: FlutterEngine) {
        registerPlugin(
            flutterEngine,
            "cloud_functions",
            "io.flutter.plugins.firebase.functions.FlutterFirebaseFunctionsPlugin",
        )
        registerPlugin(
            flutterEngine,
            "firebase_analytics",
            "io.flutter.plugins.firebase.analytics.FlutterFirebaseAnalyticsPlugin",
        )
        registerPlugin(
            flutterEngine,
            "firebase_auth",
            "io.flutter.plugins.firebase.auth.FlutterFirebaseAuthPlugin",
        )
        registerPlugin(
            flutterEngine,
            "firebase_core",
            "io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin",
        )
        registerPlugin(
            flutterEngine,
            "firebase_crashlytics",
            "io.flutter.plugins.firebase.crashlytics.FlutterFirebaseCrashlyticsPlugin",
        )
        registerPlugin(
            flutterEngine,
            "firebase_database",
            "io.flutter.plugins.firebase.database.FirebaseDatabasePlugin",
        )
        registerPlugin(
            flutterEngine,
            "firebase_messaging",
            "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingPlugin",
        )
        registerPlugin(
            flutterEngine,
            "flutter_local_notifications",
            "com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin",
        )
        registerPlugin(
            flutterEngine,
            "flutter_timezone",
            "net.wolverinebeach.flutter_timezone.FlutterTimezonePlugin",
        )
        registerPlugin(
            flutterEngine,
            "google_sign_in_android",
            "io.flutter.plugins.googlesignin.GoogleSignInPlugin",
        )
        registerPlugin(
            flutterEngine,
            "package_info_plus",
            "dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin",
        )
    }

    private fun registerPlugin(
        flutterEngine: FlutterEngine,
        pluginName: String,
        className: String,
    ) {
        try {
            val pluginClass = Class.forName(className)
            val plugin = pluginClass.getDeclaredConstructor().newInstance() as FlutterPlugin
            flutterEngine.plugins.add(plugin)
        } catch (error: Exception) {
            Log.e(TAG, "Error registering plugin $pluginName, $className", error)
        }
    }
}
