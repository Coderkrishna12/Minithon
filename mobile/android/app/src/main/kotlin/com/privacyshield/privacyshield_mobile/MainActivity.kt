package com.privacyshield.privacyshield_mobile

import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.hardware.biometrics.BiometricPrompt
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.PermissionInfo
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.net.Uri
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.Locale
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.util.Base64

class MainActivity : FlutterActivity() {
    private val speechRequestCode = 9104
    private val biometricRequestCode = 9105
    private var speechResult: MethodChannel.Result? = null
    private var biometricResult: MethodChannel.Result? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "privacyshield/secure_storage").setMethodCallHandler { call, result ->
            try {
                val key = call.argument<String>("key") ?: "access_token"
                val prefs = getSharedPreferences("privacyshield_secure_values", Context.MODE_PRIVATE)
                when (call.method) {
                    "read" -> {
                        val packed = prefs.getString(key, null)
                        if (packed == null) result.success(null) else {
                            val bytes = Base64.decode(packed, Base64.NO_WRAP)
                            val iv = bytes.copyOfRange(0, 12)
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(Cipher.DECRYPT_MODE, getOrCreateStorageKey(), GCMParameterSpec(128, iv))
                            result.success(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
                        }
                    }
                    "write" -> {
                        val value = call.argument<String>("value") ?: throw IllegalArgumentException("value is required")
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateStorageKey())
                        val packed = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
                        prefs.edit().putString(key, Base64.encodeToString(packed, Base64.NO_WRAP)).apply()
                        result.success(null)
                    }
                    "delete" -> { prefs.edit().remove(key).apply(); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("SECURE_STORAGE_FAILED", e.message, null)
            }
        }
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
                "openUrl" -> {
                    val rawUrl = call.argument<String>("url")
                    val uri = rawUrl?.let { Uri.parse(it) }
                    if (uri == null || uri.scheme !in listOf("http", "https")) {
                        result.error("BAD_URL", "A valid http or https URL is required.", null)
                    } else {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, uri))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_URL_FAILED", e.message, null)
                        }
                    }
                }
                "authenticateBiometric" -> authenticateBiometric(result)
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "privacyshield/voice").setMethodCallHandler { call, result ->
            if (call.method != "listen") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                result.error("VOICE_UNAVAILABLE", "No speech recognition service is available on this phone.", null)
                return@setMethodCallHandler
            }
            if (speechResult != null) {
                result.error("VOICE_BUSY", "Speech recognition is already active.", null)
                return@setMethodCallHandler
            }
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                putExtra(RecognizerIntent.EXTRA_PROMPT, "Ask PrivacyBot")
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            }
            try {
                speechResult = result
                startActivityForResult(intent, speechRequestCode)
            } catch (e: Exception) {
                speechResult = null
                result.error("VOICE_START_FAILED", e.message, null)
            }
        }
    }

    private fun getOrCreateStorageKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "privacyshield_access_token_v1"
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build())
        return generator.generateKey()
    }

    @Deprecated("Deprecated in Android, retained for the system speech-recognition activity result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == biometricRequestCode) {
            val pending = biometricResult ?: return
            biometricResult = null
            pending.success(resultCode == RESULT_OK)
            return
        }
        if (requestCode != speechRequestCode) return
        val pending = speechResult ?: return
        speechResult = null
        if (resultCode == RESULT_OK) {
            val phrases = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            pending.success(phrases?.firstOrNull())
        } else {
            pending.success(null)
        }
    }

    private fun authenticateBiometric(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                val builder = BiometricPrompt.Builder(this)
                    .setTitle("Unlock PrivacyShield")
                    .setSubtitle("Confirm it is you to view your privacy data")
                val executor = java.util.concurrent.Executor { command -> runOnUiThread(command) }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    builder.setAllowedAuthenticators(
                        android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                            android.hardware.biometrics.BiometricManager.Authenticators.DEVICE_CREDENTIAL,
                    )
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    @Suppress("DEPRECATION")
                    builder.setDeviceCredentialAllowed(true)
                } else {
                    builder.setNegativeButton("Cancel", executor) { dialog, _ ->
                        result.success(false)
                        dialog.dismiss()
                    }
                }
                builder.build().authenticate(
                    android.os.CancellationSignal(),
                    executor,
                    object : BiometricPrompt.AuthenticationCallback() {
                        override fun onAuthenticationSucceeded(authenticationResult: BiometricPrompt.AuthenticationResult?) {
                            result.success(true)
                        }

                        override fun onAuthenticationError(errorCode: Int, errString: CharSequence?) {
                            result.success(false)
                        }
                    },
                )
            } catch (e: Exception) {
                result.error("BIOMETRIC_FAILED", e.message, null)
            }
            return
        }
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (!keyguard.isKeyguardSecure) {
            result.error("BIOMETRIC_UNAVAILABLE", "Set up a secure screen lock on this phone first.", null)
            return
        }
        val intent = keyguard.createConfirmDeviceCredentialIntent("Unlock PrivacyShield", "Confirm your screen lock")
        if (intent == null) {
            result.error("BIOMETRIC_UNAVAILABLE", "Device authentication is unavailable.", null)
            return
        }
        biometricResult = result
        startActivityForResult(intent, biometricRequestCode)
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
