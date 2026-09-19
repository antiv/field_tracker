// Built as part of each app's Gradle project: the Android Gradle plugin
// version comes from the app's settings, so none is pinned here. Kotlin is
// AGP's built-in one (Flutter 3.47+); applying the Kotlin Gradle plugin here
// is what the tool now warns about.
group = "rs.antonijevic.tracker_location_permission"
version = "1.0"

plugins {
    id("com.android.library")
}

android {
    namespace = "rs.antonijevic.tracker_location_permission"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 23
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
}
