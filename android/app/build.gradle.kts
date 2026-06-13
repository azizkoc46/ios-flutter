import java.util.Properties
import java.io.FileInputStream

// 1. Flutter ve Keystore özelliklerini yükle
val localProperties = Properties()
val localPropertiesFile = rootProject.projectDir.resolve("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.pp.pazarckportal.pazarckportal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Desugaring aktif
        isCoreLibraryDesugaringEnabled = true 
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        // Senin özel imza ayarların
        create("release") {
            keyAlias = "pazarcık portal"
            keyPassword = "147369"
            storeFile = file("pazarcikportal_imza.jks")
            storePassword = "147369"
        }
    }

  defaultConfig {
        applicationId = "com.pp.pazarckportal.pazarckportal"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // 🔥 TEK ELDEN YÖNETİM: Gradle artık otomatik olarak 
        // Flutter'ın versiyonunu okuyacak. 
        // Sen sadece pubspec.yaml'ı güncelleyeceksin.
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // İmza yapılandırması bağlandı
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Modern Java API desteği (Desugaring)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}