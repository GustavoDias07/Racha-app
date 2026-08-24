import java.io.FileInputStream
import java.util.Properties

// Credenciais da chave de upload. Ficam em android/key.properties, que NAO
// esta no controle de versao (contem a senha do keystore) -- por isso a
// leitura e condicional: sem o arquivo o build continua funcionando e cai
// na assinatura de debug, que e o que permite `flutter run --release` numa
// maquina que nao tem a chave.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val temChaveDeUpload = keystorePropertiesFile.exists()

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.gustavodias.rachaapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Exigido pelo flutter_local_notifications (usa APIs do java.time
        // via desugaring em vez de depender direto do minSdk pra elas).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.gustavodias.rachaapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Sobrescrito para 23: exigido pelas versões atuais do Firebase Auth
        // (o default do template Flutter costuma ficar abaixo disso).
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // So existe quando key.properties existe -- criar um signingConfig
        // com storeFile nulo faz o Gradle falhar na configuracao, antes
        // mesmo de saber se alguem ia pedir um build de release.
        if (temChaveDeUpload) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Sem a chave de upload o release sai assinado em debug: serve pra
            // rodar no aparelho, mas a Play recusa o upload. O build avisa em
            // vez de falhar calado, pra ninguem descobrir isso so no Console.
            signingConfig = if (temChaveDeUpload) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "AVISO: android/key.properties nao encontrado -- o build de " +
                        "release vai sair assinado com a chave de DEBUG e a Play " +
                        "Store vai recusar o upload. Ver docs/tarefas.md, T19."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
