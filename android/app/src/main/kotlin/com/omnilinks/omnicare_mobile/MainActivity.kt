package com.omnilinks.omnicare_mobile

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.AutocompleteSessionToken
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.net.FetchPlaceRequest
import com.google.android.libraries.places.api.net.FindAutocompletePredictionsRequest
import com.google.android.libraries.places.api.net.PlacesClient

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val CHANNEL = "omnicare/emergency_places"
        const val MAPS_CONFIGURATION_CHANNEL = "omnicare/maps_configuration"
        const val SECURE_SCREEN_CHANNEL = "omnicare/secure_screen"
        const val API_KEY_META_DATA = "com.google.android.geo.API_KEY"
    }

    private var placesClient: PlacesClient? = null
    private var sessionToken: AutocompleteSessionToken? = null
    private var predictionsCancellation: CancellationTokenSource? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSession" -> {
                        sessionToken = AutocompleteSessionToken.newInstance()
                        result.success(null)
                    }

                    "predictions" -> findPredictions(call.argument<String>("query"), result)
                    "fetchPlace" -> fetchPlace(call.argument<String>("placeId"), result)
                    "endSession" -> {
                        predictionsCancellation?.cancel()
                        predictionsCancellation = null
                        sessionToken = null
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        // G-2 FT-3: FLAG_SECURE while the « Dossier médical » is shown.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }

                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPS_CONFIGURATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(
                        mapOf(
                            "configured" to isConfiguredGoogleMapsKey(readMapsApiKey()),
                            "platform" to "android",
                        ),
                    )

                    else -> result.notImplemented()
                }
            }
    }

    private fun findPredictions(query: String?, result: MethodChannel.Result) {
        val normalizedQuery = query?.trim().orEmpty()
        if (normalizedQuery.length < 3) {
            result.success(emptyList<Map<String, String>>())
            return
        }
        try {
            val client = getPlacesClient()
            val token = sessionToken ?: AutocompleteSessionToken.newInstance().also {
                sessionToken = it
            }
            predictionsCancellation?.cancel()
            val cancellation = CancellationTokenSource()
            predictionsCancellation = cancellation
            val request = FindAutocompletePredictionsRequest.builder()
                .setQuery(normalizedQuery)
                .setCountries(listOf("TN"))
                .setRegionCode("TN")
                .setSessionToken(token)
                .setCancellationToken(cancellation.token)
                .build()
            client.findAutocompletePredictions(request)
                .addOnSuccessListener { response ->
                    result.success(
                        response.autocompletePredictions.map { prediction ->
                            mapOf(
                                "placeId" to prediction.placeId,
                                "primaryText" to prediction.getPrimaryText(null).toString(),
                                "secondaryText" to prediction.getSecondaryText(null).toString(),
                            )
                        },
                    )
                }
                .addOnFailureListener {
                    result.error(
                        "PLACES_UNAVAILABLE",
                        "Address suggestions are temporarily unavailable.",
                        null,
                    )
                }
        } catch (_: Exception) {
            result.error("PLACES_UNAVAILABLE", "Address suggestions are unavailable.", null)
        }
    }

    private fun fetchPlace(placeId: String?, result: MethodChannel.Result) {
        val normalizedPlaceId = placeId?.trim().orEmpty()
        if (normalizedPlaceId.isEmpty()) {
            result.error("INVALID_PLACE", "The selected address is invalid.", null)
            return
        }
        try {
            val fields = listOf(Place.Field.FORMATTED_ADDRESS, Place.Field.LOCATION)
            val requestBuilder = FetchPlaceRequest.builder(normalizedPlaceId, fields)
                .setSessionToken(sessionToken)
                .setRegionCode("TN")
            getPlacesClient().fetchPlace(requestBuilder.build())
                .addOnSuccessListener { response ->
                    val place = response.place
                    val coordinate = place.location
                    val address = place.formattedAddress?.trim().orEmpty()
                    if (coordinate == null || address.isEmpty()) {
                        result.error("PLACE_INCOMPLETE", "The selected address is incomplete.", null)
                    } else {
                        result.success(
                            mapOf(
                                "latitude" to coordinate.latitude,
                                "longitude" to coordinate.longitude,
                                "formattedAddress" to address,
                            ),
                        )
                    }
                    discardSession()
                }
                .addOnFailureListener {
                    discardSession()
                    result.error("PLACE_UNAVAILABLE", "The selected address is unavailable.", null)
                }
        } catch (_: Exception) {
            discardSession()
            result.error("PLACE_UNAVAILABLE", "The selected address is unavailable.", null)
        }
    }

    private fun getPlacesClient(): PlacesClient {
        placesClient?.let { return it }
        val apiKey = readMapsApiKey()
            ?.takeIf(::isConfiguredGoogleMapsKey)
            ?: throw IllegalStateException("Maps API key is unavailable")
        Places.initializeWithNewPlacesApiEnabled(applicationContext, apiKey)
        return Places.createClient(this).also { placesClient = it }
    }

    private fun readMapsApiKey(): String? =
        applicationInfo.metaData?.getString(API_KEY_META_DATA)

    private fun isConfiguredGoogleMapsKey(value: String?): Boolean {
        val normalized = value?.trim().orEmpty()
        return normalized.startsWith("AIza") &&
            normalized.length >= 30 &&
            !normalized.contains("$(") &&
            !normalized.contains('%')
    }

    private fun discardSession() {
        predictionsCancellation?.cancel()
        predictionsCancellation = null
        sessionToken = null
    }

    override fun onDestroy() {
        discardSession()
        super.onDestroy()
    }
}
