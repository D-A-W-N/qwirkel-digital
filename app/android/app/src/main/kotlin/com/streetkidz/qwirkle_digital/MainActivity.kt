package com.streetkidz.qwirkle_digital

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Muss exakt dem Kanal-Namen entsprechen, den
// app/lib/src/update/update_applier_android.dart verwendet - der
// In-App-Updater kann das eigene installierte Paket nicht selbst
// ersetzen (anders als bei macOS/Linux/Windows), sondern übergibt die
// heruntergeladene APK hier an den System-Paketinstaller.
private const val UPDATER_CHANNEL = "com.streetkidz.qwirkle_digital/updater"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("missing_path", "No APK path provided", null)
                        return@setMethodCallHandler
                    }
                    try {
                        installApk(path)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("install_failed", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Reicht die unter [path] heruntergeladene APK an den System-
     * Paketinstaller weiter. Die Datei liegt im App-eigenen Cache-
     * Verzeichnis und ist damit für andere Apps (inkl. des System-
     * Installers) nicht direkt per file://-URI zugänglich - der
     * [FileProvider] stellt stattdessen eine content://-URI mit
     * befristeter Leserechte-Freigabe bereit (siehe
     * res/xml/file_paths.xml + <provider> in AndroidManifest.xml).
     *
     * Die eigentliche Installation läuft danach vollständig im
     * System-Dialog - Android verlangt hier immer eine explizite
     * Bestätigung durch die Person, das lässt sich von der App aus
     * nicht überspringen.
     */
    private fun installApk(path: String) {
        val apkFile = File(path)
        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile,
        )
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(installIntent)
    }
}
