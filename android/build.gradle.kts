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

subprojects {
    val applyNamespace = {
        if (plugins.hasPlugin("com.android.library")) {
            val android = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            if (android != null && android.namespace == null) {
                android.namespace = when (project.name) {
                    "blue_thermal_printer" -> "id.kakzaki.blue_thermal_printer"
                    else -> "com.plugin.${project.name.replace('-', '_')}"
                }
            }
        }
    }

    if (project.state.executed) {
        applyNamespace()
    } else {
        project.afterEvaluate {
            applyNamespace()
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
