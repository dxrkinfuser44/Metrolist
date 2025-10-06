import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    kotlin("android")
    alias(libs.plugins.hilt)
    alias(libs.plugins.kotlin.ksp)
    alias(libs.plugins.compose.compiler)
}

android {
    namespace = "com.metrolist.wear"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.metrolist.wear"
        minSdk = 30 // Wear OS requires minimum API 30
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            applicationIdSuffix = ".debug"
            isDebuggable = true
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlin {
        jvmToolchain(21)
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_21)
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // Wear OS
    implementation("androidx.wear:wear:1.3.0")
    implementation("androidx.wear.compose:compose-material:1.5.0")
    implementation("androidx.wear.compose:compose-foundation:1.5.0")
    implementation("androidx.wear.compose:compose-navigation:1.5.0")
    
    // Compose
    implementation(libs.compose.runtime)
    implementation(libs.compose.foundation)
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling)
    implementation(libs.activity)
    
    // Media
    implementation(libs.media3)
    implementation(libs.media3.session)
    
    // Hilt
    implementation(libs.hilt)
    ksp(libs.hilt.compiler)
    
    // Coil for images
    implementation(libs.coil)
    
    // Ktor for networking (MetroSync)
    implementation(libs.ktor.client.core)
    implementation(libs.ktor.serialization.json)
    
    // Coroutines
    implementation(libs.guava)
    implementation(libs.coroutines.guava)
    
    coreLibraryDesugaring(libs.desugaring)
}
