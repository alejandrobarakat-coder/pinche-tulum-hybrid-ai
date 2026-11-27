# Pinche Tulum

Pinche Tulum is an independent newsroom app. Smart Search helps readers find published articles. Videos features original reporting presented by Barakat, and Pinche Market shows editorial forecasts alongside Polymarket probabilities with links to the articles behind each call.

## Android setup

1. Install Flutter 3.44.9, JDK 17 and the Android SDK.
2. Register Android package com.pinchetulum.pinchetulum in your Firebase project. Enable Firebase AI Logic with the Gemini Developer API and configure App Check for the certificate used by your test build.
3. Put the Android Firebase configuration at android/app/google-services.json.
4. Run:

   ~~~sh
   flutter pub get
   flutter analyze lib
   flutter build apk --debug
   ~~~

For a signed release, configure android/key.properties locally with storeFile, storePassword, keyAlias and keyPassword. Then run flutter build apk --release. Keep signing material outside the repository.

## Test hybrid inference

Open Archive, enter a topic and tap Smart Search. The Kotlin method channel invokes Firebase AI Logic with PREFER_ON_DEVICE. The app labels the result On-device Gemini or Cloud Gemini using the SDK's reported inference source. If inference fails or times out, the archive searches the original query and labels that route Archive search used.

Test on a compatible device with the on-device model available, then verify the cloud path on a device without the model and with working network access and App Check. The archive results are served by the Pinche Tulum API.

## iOS

The project includes the Swift integration for Firebase AI Logic. On macOS, add your GoogleService-Info.plist to the Runner target's bundle resources and configure App Attest in Firebase. Build and test in Xcode on a compatible iPhone. iOS device verification is pending.

## Pinche Market

Open Pinche Market, compare Barakat and Polymarket, and open an article link. The app reads the public results feed. Forecast fingerprints have been prepared locally. The first verified on-chain Stamp is pending.

The app source is licensed under Apache-2.0. The vendored video_thumbnail plugin retains its own license.
