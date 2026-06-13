# Wumble

Aplicación de comunidades hecha en Flutter (Android/iOS) con un panel de administración en Next.js (`admin-dashboard/`).

> Distribución **fuera de Play Store**: la app se instala como APK y se actualiza **OTA** (over‑the‑air) desde **GitHub Releases**.

## Configuración tras clonar

Por seguridad, **los archivos con credenciales NO están en el repositorio**. Debes añadirlos localmente:

| Archivo | Para qué |
|---|---|
| `android/app/google-services.json` | Config Firebase (Android). Descárgalo de tu proyecto Firebase. |
| `ios/Runner/GoogleService-Info.plist` | Config Firebase (iOS). |
| `.firebaserc` / `firebase.json` | Proyecto Firebase / hosting. |
| `android/key.properties` + `*.jks` | Firma de release (ver `android/key.properties.example`). |
| `dart_defines.json` | Claves de API en build (ver `dart_defines.example.json`). |
| `admin-dashboard/lib/firebase.ts` | Config Firebase del panel. |

### Claves de API (dart-define)

Las APIs (Agora, Giphy, Cloudinary) se inyectan en tiempo de compilación, no se hardcodean:

```bash
cp dart_defines.example.json dart_defines.json   # y rellena los valores
```

Compila/ejecuta pasando ese archivo:

```bash
flutter run            --dart-define-from-file=dart_defines.json
flutter build apk      --release --dart-define-from-file=dart_defines.json
flutter build appbundle --release --dart-define-from-file=dart_defines.json
```

## Actualizaciones OTA

La app revisa el **último Release** de este repo (`UpdateService.repo` en
`lib/core/services/update_service.dart`) al iniciar. Si hay una versión más nueva,
muestra un diálogo que descarga e instala el APK.

**Para publicar una actualización:**

1. Sube la versión en `pubspec.yaml` (`version: 1.0.1+40` — el `+40` es el `versionCode`).
2. Compila el APK de release:
   ```bash
   flutter build apk --release --dart-define-from-file=dart_defines.json
   ```
3. Crea un **Release** en GitHub con el tag `v1.0.1+40` y adjunta el APK
   (`build/app/outputs/flutter-apk/app-release.apk`) como asset.

La app compara el número de build del tag (`+40`) con el instalado y ofrece actualizar.
OTA solo aplica en **Android** (instalación de APK sideloaded).
