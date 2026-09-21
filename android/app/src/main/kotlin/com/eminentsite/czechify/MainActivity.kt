package com.eminentsite.czechify

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.core.view.WindowCompat
import com.google.android.play.agesignals.AgeSignalsAccessRequest
import com.google.android.play.agesignals.AgeSignalsManager
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.model.AgeSignalsStatus
import com.google.android.play.agesignals.model.SignificantChangeStatus
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityException
import com.google.android.play.core.integrity.StandardIntegrityManager
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import com.google.android.play.core.integrity.model.StandardIntegrityErrorCode
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var ageSignalsManager: AgeSignalsManager
    private lateinit var integrityManager: StandardIntegrityManager
    private var integrityProvider: StandardIntegrityTokenProvider? = null
    private var integrityProjectNumber: Long? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Apply before Flutter creates its content view. Android 15+ enforces
        // edge-to-edge for our target SDK; this call gives older supported
        // Android versions the same layout and lets Play verify the opt-in.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ageSignalsManager = AgeSignalsManagerFactory.create(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AGE_SIGNALS_CHANNEL,
        ).setMethodCallHandler(::handleAgeSignalsCall)

        integrityManager = IntegrityManagerFactory.createStandard(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PLAY_INTEGRITY_CHANNEL,
        ).setMethodCallHandler(::handlePlayIntegrityCall)
    }

    private fun handlePlayIntegrityCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "requestToken") return result.notImplemented()
        val projectNumber = (call.argument<Number>("cloudProjectNumber"))?.toLong()
        val requestHash = call.argument<String>("requestHash")
        if (projectNumber == null || projectNumber <= 0 || requestHash.isNullOrEmpty()) {
            return result.success(mapOf("status" to "misconfigured"))
        }
        requestIntegrityToken(projectNumber, requestHash, result, retried = false)
    }

    // Prepares the token provider once and reuses it; an expired provider is
    // prepared again, once. Play's exception text never reaches Dart.
    private fun requestIntegrityToken(
        projectNumber: Long,
        requestHash: String,
        result: MethodChannel.Result,
        retried: Boolean,
    ) {
        val provider = integrityProvider
        if (provider == null || integrityProjectNumber != projectNumber) {
            integrityManager.prepareIntegrityToken(
                PrepareIntegrityTokenRequest.builder()
                    .setCloudProjectNumber(projectNumber)
                    .build(),
            )
                .addOnSuccessListener { prepared ->
                    integrityProvider = prepared
                    integrityProjectNumber = projectNumber
                    requestIntegrityToken(projectNumber, requestHash, result, retried)
                }
                .addOnFailureListener { error -> result.success(integrityFailure(error)) }
            return
        }
        provider.request(
            StandardIntegrityTokenRequest.builder()
                .setRequestHash(requestHash)
                .build(),
        )
            .addOnSuccessListener { response ->
                result.success(mapOf("status" to "ok", "token" to response.token()))
            }
            .addOnFailureListener { error ->
                val invalid = error is StandardIntegrityException &&
                    error.errorCode == StandardIntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID
                if (invalid && !retried) {
                    integrityProvider = null
                    requestIntegrityToken(projectNumber, requestHash, result, retried = true)
                } else {
                    result.success(integrityFailure(error))
                }
            }
    }

    private fun integrityFailure(error: Exception): Map<String, String> {
        val code = (error as? StandardIntegrityException)?.errorCode
        val status = when (code) {
            StandardIntegrityErrorCode.API_NOT_AVAILABLE,
            StandardIntegrityErrorCode.PLAY_STORE_NOT_FOUND,
            StandardIntegrityErrorCode.PLAY_SERVICES_NOT_FOUND,
            StandardIntegrityErrorCode.APP_NOT_INSTALLED,
            StandardIntegrityErrorCode.APP_UID_MISMATCH,
            StandardIntegrityErrorCode.PLAY_STORE_VERSION_OUTDATED,
            StandardIntegrityErrorCode.PLAY_SERVICES_VERSION_OUTDATED -> "unsupported"
            StandardIntegrityErrorCode.CLOUD_PROJECT_NUMBER_IS_INVALID,
            StandardIntegrityErrorCode.REQUEST_HASH_TOO_LONG -> "misconfigured"
            else -> "retry"
        }
        return mapOf("status" to status)
    }

    private fun handleAgeSignalsCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestAgeSignals" -> requestAgeSignals(result)
            "openPlayStore" -> openPlayStore(result)
            else -> result.notImplemented()
        }
    }

    private fun requestAgeSignals(result: MethodChannel.Result) {
        val request = AgeSignalsAccessRequest.builder()
            .setActivity(this)
            .build()

        ageSignalsManager.requestAgeSignalsAccess(request)
            .addOnSuccessListener { accessResult ->
                when (accessResult.ageSignalsStatus()) {
                    AgeSignalsStatus.SHARED -> retrieveAgeSignals(result)
                    AgeSignalsStatus.NOT_SHARED -> result.success(
                        mapOf("status" to "not_shared"),
                    )
                    AgeSignalsStatus.VERIFICATION_REQUIRED -> result.success(
                        mapOf("status" to "verification_required"),
                    )
                    else -> result.success(mapOf("status" to "error"))
                }
            }
            .addOnFailureListener {
                // Do not pass exception text to Dart: Play errors can contain
                // environment details and the UI only needs a retry state.
                result.success(mapOf("status" to "error"))
            }
    }

    private fun retrieveAgeSignals(result: MethodChannel.Result) {
        ageSignalsManager.checkAgeSignals(AgeSignalsRequest.builder().build())
            .addOnSuccessListener { signals ->
                val significantChange = when (signals.significantChangeStatus()) {
                    SignificantChangeStatus.APPROVED -> "approved"
                    SignificantChangeStatus.PENDING -> "pending"
                    SignificantChangeStatus.DECLINED -> "declined"
                    else -> null
                }

                // Deliberately omit installId and ageRangeSource. Czechify only
                // needs the coarse bounds and approval state to enforce its
                // 16+ policy, and it never persists the response.
                result.success(
                    mapOf(
                        "status" to "shared",
                        "ageLower" to signals.ageLower(),
                        "ageUpper" to signals.ageUpper(),
                        "significantChangeStatus" to significantChange,
                    ),
                )
            }
            .addOnFailureListener {
                result.success(mapOf("status" to "error"))
            }
    }

    private fun openPlayStore(result: MethodChannel.Result) {
        val marketIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("market://details?id=$packageName"),
        ).apply {
            setPackage("com.android.vending")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            startActivity(marketIntent)
            result.success(true)
        } catch (_: ActivityNotFoundException) {
            val webIntent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("https://play.google.com/store/apps/details?id=$packageName"),
            )
            try {
                startActivity(webIntent)
                result.success(true)
            } catch (_: ActivityNotFoundException) {
                result.error(
                    "PLAY_STORE_UNAVAILABLE",
                    "Google Play could not be opened on this device.",
                    null,
                )
            }
        }
    }

    private companion object {
        const val AGE_SIGNALS_CHANNEL = "com.eminentsite.czechify/age_signals"
        const val PLAY_INTEGRITY_CHANNEL = "com.eminentsite.czechify/play_integrity"
    }
}
