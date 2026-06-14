import 'dart:io';
import 'package:wumble/core/localization/translations.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

class ShareHelper {
  static Future<void> share({
    required BuildContext context,
    required String text,
    required String subject,
    String? imageUrl,
  }) async {
    try {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Show loading indicator in snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text(tr('Preparando para compartir...')),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1E1E2C),
          ),
        );

        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final temp = await getTemporaryDirectory();
          final fileName = imageUrl.split('/').last.split('?').first;
          final filePath = '${temp.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(bytes);

          await Share.shareXFiles(
            [XFile(filePath)],
            text: text,
            subject: subject,
          );
          return;
        }
      }
      
      // Fallback to text only if image fails or is null
      await Share.share(text, subject: subject);
      
    } catch (e) {
      debugPrint('ShareHelper Error: $e');
      // Final fallback
      await Share.share(text, subject: subject);
    }
  }
}
