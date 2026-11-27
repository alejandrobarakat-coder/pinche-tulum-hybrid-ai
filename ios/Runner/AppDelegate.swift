import FirebaseAILogic
import FirebaseCore
import Flutter
import FoundationModels
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if FirebaseApp.app() == nil, let options = FirebaseOptions.defaultOptions() {
      FirebaseApp.configure(options: options)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "pinchetulum/hybrid_search",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      guard call.method == "searchTerms" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let arguments = call.arguments as? [String: Any]
      let input = arguments?["query"] as? String ?? ""
      let query = String(input.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
      guard !query.isEmpty else {
        result("")
        return
      }

      Task { @MainActor in
        let prompt = "Extract up to five news archive search terms. Keep proper names unchanged. Return search terms only. Query: \(query)"
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
          do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let terms = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !terms.isEmpty {
              result(terms)
              return
            }
          } catch {
            // Use Gemini if the device model cannot complete the request.
          }
        }

        do {
          let ai = FirebaseAI.firebaseAI(backend: .googleAI())
          let response = try await ai.generativeModel(
            modelName: "gemini-2.5-flash-lite"
          ).generateContent(prompt)
          let terms = (response.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
          if terms.isEmpty {
            result(FlutterError(
              code: "EMPTY_RESPONSE",
              message: "No search terms were generated.",
              details: nil
            ))
          } else {
            result(terms)
          }
        } catch {
          result(FlutterError(
            code: "SMART_SEARCH_FAILED",
            message: "Smart Search is unavailable.",
            details: nil
          ))
        }
      }
    }
  }
}
