allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
subprojects {
    afterEvaluate {
        project.extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
            compileSdk = 34
            if (namespace == null) {
                var extractedNamespace = "com.example.namespace"
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val content = manifestFile.readText()
                    val matchResult = """package="([^"]+)"""".toRegex().find(content)
                    if (matchResult != null) {
                        extractedNamespace = matchResult.groupValues[1]
                    }
                }
                namespace = extractedNamespace
            }
        }
    }
}

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
