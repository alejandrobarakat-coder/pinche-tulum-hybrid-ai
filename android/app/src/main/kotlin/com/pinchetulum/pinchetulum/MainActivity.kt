package com.pinchetulum.pinchetulum

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.firebase.Firebase
import com.google.firebase.ai.ai
import com.google.firebase.ai.OnDeviceConfig
import com.google.firebase.ai.InferenceMode
import com.google.firebase.ai.type.*
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(
        SupervisorJob() + Dispatchers.Main
    )

    @OptIn(PublicPreviewAPI::class)
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "pinchetulum/hybrid_search"
        ).setMethodCallHandler { call, result ->

            if (call.method != "searchTerms") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val query = call.argument<String>("query")
                ?.trim()?.take(200).orEmpty()

            if (query.isEmpty()) {
                result.error("EMPTY_QUERY", "Enter a search query.", null)
                return@setMethodCallHandler
            }

            scope.launch {
                try {
                    val model = Firebase.ai(
                        backend = GenerativeBackend.googleAI()
                    ).generativeModel(
                        modelName = "gemini-2.5-flash-lite",
                        onDeviceConfig = OnDeviceConfig(
                            mode = InferenceMode.PREFER_ON_DEVICE
                        )
                    )

                    val response = model.generateContent(
                        "Extract up to five English news search keywords " +
                        "from this query. Return keywords only: $query"
                    )

                    val terms = response.text?.trim().orEmpty()
                    if (terms.isEmpty()) {
                        result.error("EMPTY_RESPONSE", "No search terms were generated.", null)
                    } else {
                        result.success(mapOf(
                            "terms" to terms,
                            "source" to response.inferenceSource.toString()
                        ))
                    }
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    result.error("SMART_SEARCH_UNAVAILABLE", "AI search is unavailable.", null)
                }
            }
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
