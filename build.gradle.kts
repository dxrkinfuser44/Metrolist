plugins {
    alias(libs.plugins.hilt) apply (false)
    alias(libs.plugins.kotlin.ksp) apply (false)
}

buildscript {
    repositories {
        google()
        mavenCentral()
        maven { setUrl("https://jitpack.io") }
    }
    dependencies {
        classpath(libs.gradle)
        classpath(kotlin("gradle-plugin", libs.versions.kotlin.get()))
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Custom task to build all phone APKs
tasks.register("buildPhoneApks") {
    group = "build"
    description = "Build all phone APK variants (arm64, armeabi, x86, x86_64, universal)"
    
    dependsOn(
        ":app:assembleArm64Release",
        ":app:assembleArmeabiRelease",
        ":app:assembleX86Release",
        ":app:assembleX86_64Release",
        ":app:assembleUniversalRelease"
    )
}

// Custom task to build watch APKs
tasks.register("buildWatchApks") {
    group = "build"
    description = "Build watch/Wear OS APKs (debug and release)"
    
    dependsOn(
        ":wear:assembleDebug",
        ":wear:assembleRelease"
    )
}

// Custom task to build all APKs (phone + watch)
tasks.register("buildAllApks") {
    group = "build"
    description = "Build all phone and watch APKs"
    
    dependsOn("buildPhoneApks", "buildWatchApks")
}

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            if (project.findProperty("enableComposeCompilerReports") == "true") {
                arrayOf("reports", "metrics").forEach {
                    freeCompilerArgs.add("-P")
                    freeCompilerArgs.add("plugin:androidx.compose.compiler.plugins.kotlin:${it}Destination=${project.layout.buildDirectory}/compose_metrics")
                }
            }
        }
    }
}
