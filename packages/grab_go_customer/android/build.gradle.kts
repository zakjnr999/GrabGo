import java.io.File
import java.util.Properties

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val flutterSdkPath = localProperties.getProperty("flutter.sdk")
val flutterToolPath = flutterSdkPath?.let { "$it/bin" }
val dartToolPath = flutterSdkPath?.let { "$it/bin/cache/dart-sdk/bin" }

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (name == "rive_native" && flutterSdkPath != null) {
        tasks.withType<Exec>().configureEach {
            val existingPath =
                (environment["PATH"] as? String)
                    ?: System.getenv("PATH").orEmpty()
            val patchedPath =
                listOfNotNull(dartToolPath, flutterToolPath, existingPath)
                    .filter { it.isNotBlank() }
                    .joinToString(File.pathSeparator)

            environment("PATH", patchedPath)
            environment("FLUTTER_ROOT", flutterSdkPath)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
