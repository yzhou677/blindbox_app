import org.gradle.api.tasks.compile.JavaCompile
import org.gradle.jvm.toolchain.JavaLanguageVersion

plugins {
    id("java-base")
}

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

    // AGP's JdkImageTransform uses JavaCompiler.installationPath; a broken Studio path can leak in here.
    // Force a Gradle Java 17 toolchain (Foojay resolver in settings.gradle.kts) for all JavaCompile tasks.
    afterEvaluate {
        tasks.withType(JavaCompile::class.java).configureEach {
            javaCompiler.set(
                rootProject.javaToolchains.compilerFor {
                    languageVersion.set(JavaLanguageVersion.of(17))
                },
            )
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

if (tasks.findByName("clean") == null) {
    tasks.register<Delete>("clean") {
        delete(rootProject.layout.buildDirectory)
    }
}
