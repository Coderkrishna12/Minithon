package com.privacyshield.privacyshield_mobile

import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.PermissionInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "privacyshield/device").setMethodCallHandler { call, result ->
            when (call.method) {
                "scanApps" -> worker.execute {
                    try {
                        val apps = scanApps()
                        main.post { result.success(apps) }
                    } catch (e: Exception) {
                        main.post { result.error("SCAN_FAILED", e.message, null) }
                    }
                }
                "devicePosture" -> result.success(devicePosture())
                "openAppSettings" -> {
                    val pkg = call.argument<String>("package")
                    if (pkg == null) {
                        result.error("BAD_ARGS", "package is required", null)
                    } else {
                        launch(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", pkg, null)))
                        result.success(true)
                    }
                }
                "openSettings" -> {
                    val action = when (call.argument<String>("screen")) {
                        "security" -> Settings.ACTION_SECURITY_SETTINGS
                        "accessibility" -> Settings.ACTION_ACCESSIBILITY_SETTINGS
                        "notification_listeners" -> "android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"
                        "developer" -> Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS
                        "device_admin" -> "android.settings.DEVICE_ADMIN_SETTINGS"
                        else -> Settings.ACTION_SETTINGS
                    }
                    launch(Intent(action))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    private fun launch(intent: Intent) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    private fun enabledComponents(key: String, separator: Char): Set<String> {
        val raw = Settings.Secure.getString(contentResolver, key) ?: return emptySet()
        return raw.split(separator)
            .mapNotNull { ComponentName.unflattenFromString(it.trim())?.packageName }
            .toSet()
    }

    private fun isDangerous(pm: PackageManager, permission: String): Boolean = try {
        val info = pm.getPermissionInfo(permission, 0)
        val protection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.protection
        } else {
            @Suppress("DEPRECATION")
            info.protectionLevel and PermissionInfo.PROTECTION_MASK_BASE
        }
        protection == PermissionInfo.PROTECTION_DANGEROUS
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun packageInfo(pm: PackageManager, pkg: String): PackageInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(pkg, PackageManager.GET_PERMISSIONS)
        }

    private fun installer(pm: PackageManager, pkg: String): String? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            pm.getInstallSourceInfo(pkg).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            pm.getInstallerPackageName(pkg)
        }
    } catch (e: Exception) {
        null
    }

    private fun category(info: ApplicationInfo): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return "unknown"
        return when (info.category) {
            ApplicationInfo.CATEGORY_GAME -> "game"
            ApplicationInfo.CATEGORY_AUDIO -> "audio"
            ApplicationInfo.CATEGORY_VIDEO -> "video"
            ApplicationInfo.CATEGORY_IMAGE -> "image"
            ApplicationInfo.CATEGORY_SOCIAL -> "social"
            ApplicationInfo.CATEGORY_NEWS -> "news"
            ApplicationInfo.CATEGORY_MAPS -> "maps"
            ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
            else -> "unknown"
        }
    }

    private fun scanApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(launcher, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(launcher, 0)
        }.map { it.activityInfo.packageName }.toSet() - packageName

        val accessibility = enabledComponents(Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES, ':')
        val listeners = enabledComponents("enabled_notification_listeners", ':')
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val admins = dpm.activeAdmins?.map { it.packageName }?.toSet() ?: emptySet()

        return packages.mapNotNull { pkg ->
            try {
                val info = packageInfo(pm, pkg)
                val app = info.applicationInfo ?: return@mapNotNull null
                val requested = info.requestedPermissions ?: emptyArray()
                val flags = info.requestedPermissionsFlags ?: IntArray(0)
                val granted = requested.indices
                    .filter { i -> i < flags.size && (flags[i] and PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0 }
                    .map { i -> requested[i] }
                    .filter { isDangerous(pm, it) }
                mapOf(
                    "package" to pkg,
                    "label" to pm.getApplicationLabel(app).toString(),
                    "category" to category(app),
                    "system" to ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                    "installer" to installer(pm, pkg),
                    "targetSdk" to app.targetSdkVersion,
                    "installedAt" to info.firstInstallTime,
                    "updatedAt" to info.lastUpdateTime,
                    "granted" to granted,
                    "accessibility" to (pkg in accessibility),
                    "notificationListener" to (pkg in listeners),
                    "deviceAdmin" to (pkg in admins),
                )
            } catch (e: PackageManager.NameNotFoundException) {
                null
            }
        }
    }

    private fun devicePosture(): Map<String, Any?> {
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "release" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "securityPatch" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Build.VERSION.SECURITY_PATCH else null),
            "screenLock" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) keyguard.isDeviceSecure else keyguard.isKeyguardSecure),
            "developerOptions" to (Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1),
            "usbDebugging" to (Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0) == 1),
            "encrypted" to (dpm.storageEncryptionStatus in setOf(
                DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE,
                DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_PER_USER,
                DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_DEFAULT_KEY,
            )),
        )
    }
}
