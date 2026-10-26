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
    val configureAndroid: (Project) -> Unit = { proj ->
        if (proj.hasProperty("android")) {
            val android = proj.extensions.findByName("android")
            if (android != null) {
                for (m in android.javaClass.methods) {
                    if (m.name in listOf("compileSdkVersion", "setCompileSdkVersion", "setCompileSdk") && m.parameterCount == 1) {
                        val paramType = m.parameterTypes[0]
                        if (paramType == Int::class.javaPrimitiveType || paramType == java.lang.Integer::class.java) {
                            try {
                                m.invoke(android, 35)
                            } catch (_: Exception) {}
                        }
                    }
                }
            }
        }
    }

    if (project.state.executed) {
        configureAndroid(project)
    } else {
        project.afterEvaluate {
            configureAndroid(project)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
