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
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// AGP 8+ requires `namespace` in every Android module. Some older Flutter
// plugins (for example old `file_picker`) do not declare it, so we inject a
// safe fallback during configuration to keep the build working.
subprojects {
    plugins.withId("com.android.library") {
        val androidExtension = extensions.findByName("android") ?: return@withId
        val getNamespace = androidExtension::class.java.methods.find {
            it.name == "getNamespace" && it.parameterCount == 0
        }
        val setNamespace = androidExtension::class.java.methods.find {
            it.name == "setNamespace" && it.parameterCount == 1
        }

        val currentNamespace = getNamespace?.invoke(androidExtension) as? String
        if (currentNamespace.isNullOrBlank() && setNamespace != null) {
            val fallbackNamespace = project.group.toString().takeIf {
                it.isNotBlank() && it.contains('.')
            } ?: "com.example.${project.name.replace('-', '_')}"
            setNamespace.invoke(androidExtension, fallbackNamespace)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
