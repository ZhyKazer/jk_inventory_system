import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ApkUpdateException implements Exception {
  ApkUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApkUpdateService {
  Future<void> downloadAndInstallApk({
    required String downloadUrl,
    void Function(String message)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw ApkUpdateException(
        'In-app APK install is supported on Android only.',
      );
    }

    final url = downloadUrl.trim();
    if (url.isEmpty) {
      throw ApkUpdateException('Update link is missing.');
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw ApkUpdateException('Update link is invalid.');
    }

    final installPermission = Permission.requestInstallPackages;
    if (!await installPermission.isGranted) {
      final status = await installPermission.request();
      if (!status.isGranted) {
        throw ApkUpdateException(
          'Install permission denied. Allow "Install unknown apps" for this app and retry.',
        );
      }
    }

    final targetFile = await _prepareTargetFile();

    onProgress?.call('Downloading update...');
    await _downloadToFile(
      uri: uri,
      targetFile: targetFile,
      onProgress: onProgress,
    );

    onProgress?.call('Opening installer...');
    final result = await OpenFile.open(
      targetFile.path,
      type: 'application/vnd.android.package-archive',
    );

    if (result.type != ResultType.done) {
      throw ApkUpdateException(
        result.message.isEmpty
            ? 'Unable to open installer.'
            : 'Unable to open installer: ${result.message}',
      );
    }
  }

  Future<File> _prepareTargetFile() async {
    final baseDir = await getApplicationSupportDirectory();
    final updatesDir = Directory(path.join(baseDir.path, 'updates'));
    if (!await updatesDir.exists()) {
      await updatesDir.create(recursive: true);
    }

    final file = File(path.join(updatesDir.path, 'app-release.apk'));
    if (await file.exists()) {
      await file.delete();
    }
    return file;
  }

  Future<void> _downloadToFile({
    required Uri uri,
    required File targetFile,
    void Function(String message)? onProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApkUpdateException(
          'Download failed (HTTP ${response.statusCode}).',
        );
      }

      final sink = targetFile.openWrite();
      try {
        final total = response.contentLength;
        var downloaded = 0;

        await for (final chunk in response) {
          sink.add(chunk);
          downloaded += chunk.length;

          if (total > 0) {
            final percent = ((downloaded / total) * 100)
                .clamp(0, 100)
                .toStringAsFixed(0);
            onProgress?.call('Downloading update... $percent%');
          }
        }
      } finally {
        await sink.close();
      }
    } on ApkUpdateException {
      rethrow;
    } catch (_) {
      throw ApkUpdateException('Failed to download update package.');
    } finally {
      client.close(force: true);
    }
  }
}
