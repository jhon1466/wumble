import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:wumble/core/services/update_service.dart';
import 'package:wumble/core/theme.dart';

/// Checks GitHub Releases and, if a newer build exists, shows the update dialog.
///
/// Call after the first frame (e.g. from the home screen) with a valid context.
Future<void> checkAndPromptUpdate(BuildContext context,
    {bool silent = true}) async {
  final info = await UpdateService().checkForUpdate();
  if (info == null) {
    if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya tienes la última versión.')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  void _startUpdate() {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      OtaUpdate()
          .execute(widget.info.apkUrl, destinationFilename: 'wumble-update.apk')
          .listen((OtaEvent event) {
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            final pct = double.tryParse(event.value ?? '0') ?? 0;
            if (mounted) setState(() => _progress = pct / 100.0);
            break;
          case OtaStatus.INSTALLING:
            // System installer takes over here.
            break;
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            if (mounted) {
              setState(() {
                _downloading = false;
                _error =
                    'Permiso de instalación denegado. Habilítalo en Ajustes.';
              });
            }
            break;
          case OtaStatus.CANCELED:
            if (mounted) setState(() => _downloading = false);
            break;
          case OtaStatus.DOWNLOAD_ERROR:
          case OtaStatus.INTERNAL_ERROR:
          case OtaStatus.CHECKSUM_ERROR:
          case OtaStatus.ALREADY_RUNNING_ERROR:
            if (mounted) {
              setState(() {
                _downloading = false;
                _error = 'Error al actualizar: ${event.status}';
              });
            }
            break;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'No se pudo iniciar la actualización: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Wumbleheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.system_update, color: Wumbleheme.secondaryColor),
          const SizedBox(width: 10),
          Text('Versión ${widget.info.version}',
              style: const TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hay una nueva versión disponible.',
              style: TextStyle(color: Colors.white70)),
          if (widget.info.releaseNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(
                  widget.info.releaseNotes.trim(),
                  style: const TextStyle(
                      color: Wumbleheme.textSecondary, fontSize: 13),
                ),
              ),
            ),
          ],
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.white12,
              color: Wumbleheme.secondaryColor,
            ),
            const SizedBox(height: 6),
            Text('Descargando… ${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: Wumbleheme.textSecondary, fontSize: 12)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
      actions: _downloading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Más tarde',
                    style: TextStyle(color: Wumbleheme.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Wumbleheme.secondaryColor),
                onPressed: _startUpdate,
                child: const Text('Actualizar',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
    );
  }
}
