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
    project.evaluationDependsOn(":app")
}
// 强制所有子项目（包括第三方插件）使用 compileSdk 36，
// 解决 file_picker(33) 和 flutter_inappwebview_android(34) 硬编码旧版的问题。
gradle.afterProject {
    if (project != rootProject) {
        extensions.findByType<com.android.build.api.dsl.LibraryExtension>()?.let {
            it.compileSdk = 36
        }
        extensions.findByType<com.android.build.api.dsl.ApplicationExtension>()?.let {
            it.compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
