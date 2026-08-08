import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release-Signing: liest aus android/key.properties (lokal, nie eingecheckt -
// siehe android/.gitignore) bzw. in CI aus einer vor dem Build generierten
// gleichnamigen Datei (siehe .github/workflows/desktop-build.yml, aus
// Repo-Secrets zusammengesetzt). Ohne diese Datei (z. B. bei einem
// Contributor-Checkout ohne Zugriff auf den Release-Key) fällt der
// Release-Build bewusst auf die Debug-Signatur zurück, damit `flutter build
// apk --release` trotzdem funktioniert - nur eben nicht mit dem "echten",
// für Updates kompatiblen Signing-Key.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.streetkidz.qwirkle_digital"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.streetkidz.qwirkle_digital"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Für androidx.core.content.FileProvider in MainActivity.kt (In-App-
    // Updater übergibt die heruntergeladene APK darüber an den System-
    // Paketinstaller). Wahrscheinlich ohnehin schon transitiv über das
    // Flutter-Embedding vorhanden, aber explizit deklariert, um nicht
    // stillschweigend davon abhängig zu sein.
    implementation("androidx.core:core-ktx:1.13.1")
}
