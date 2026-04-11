import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ProductImageCacheService {
  static final Map<String, Future<String?>> _inflight = {};

  Future<String?> resolveImagePath(String? imagePath) async {
    try {
      final normalized = imagePath?.trim();
      if (normalized == null || normalized.isEmpty) {
        debugPrint('Image resolve: no imagePath provided.');
        return null;
      }

      final localFile = File(normalized);
      if (await localFile.exists()) {
        debugPrint('Image resolve: local file exists -> ${localFile.path}');
        return localFile.path;
      }

      if (normalized.startsWith('gs://')) {
        debugPrint('Image resolve: gs path detected -> $normalized');
        return _resolveGsPath(normalized);
      }

      debugPrint(
        'Image resolve: unsupported/non-existing path format -> $normalized',
      );
      return null;
    } catch (error, stackTrace) {
      debugPrint('ProductImageCacheService.resolveImagePath failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<String?> _resolveGsPath(String gsPath) {
    return _inflight.putIfAbsent(gsPath, () async {
      try {
        final parsed = Uri.parse(gsPath);
        if (parsed.scheme != 'gs') {
          return null;
        }

        final bucket = parsed.host;
        final objectPath = parsed.path.startsWith('/')
            ? parsed.path.substring(1)
            : parsed.path;

        if (bucket.isEmpty || objectPath.isEmpty) {
          return null;
        }

        final cacheFile = await _cacheFileForGsPath(bucket, objectPath);
        if (await cacheFile.exists()) {
          debugPrint(
            'Image fetch: cache hit for gs path -> $gsPath, file=${cacheFile.path}',
          );
          return cacheFile.path;
        }

        await cacheFile.parent.create(recursive: true);

        if (Platform.isWindows) {
          debugPrint('Image fetch: using HTTP downloader on Windows -> $gsPath');
          final downloaded = await _downloadViaHttp(
            bucket: bucket,
            objectPath: objectPath,
            outputFile: cacheFile,
          );
          if (!downloaded) {
            return null;
          }
        } else {
          final storage = FirebaseStorage.instanceFor(bucket: 'gs://$bucket');
          debugPrint('Image fetch: downloading from gs -> $gsPath');
          await storage.ref(objectPath).writeToFile(cacheFile);
        }

        debugPrint('Image fetch: download success -> ${cacheFile.path}');
        return cacheFile.path;
      } catch (error, stackTrace) {
        debugPrint('ProductImageCacheService._resolveGsPath failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return null;
      } finally {
        _inflight.remove(gsPath);
      }
    });
  }

  Future<File> _cacheFileForGsPath(String bucket, String objectPath) async {
    final baseDir = await getApplicationSupportDirectory();
    final extension = path.extension(objectPath);
    final safeBucket = _sanitizeSegment(bucket);
    final safeObject = _sanitizeSegment(objectPath);
    final checksum = _simpleChecksum('$bucket|$objectPath');
    final fileName =
        '${safeObject}_$checksum${extension.isEmpty ? '' : extension}';

    return File(
      path.join(baseDir.path, 'product_image_cache', safeBucket, fileName),
    );
  }

  String _sanitizeSegment(String value) {
    final replaced = value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (replaced.length <= 80) {
      return replaced;
    }
    return replaced.substring(0, 80);
  }

  String _simpleChecksum(String input) {
    var hash = 0;
    for (final code in input.codeUnits) {
      hash = ((hash << 5) - hash) + code;
      hash &= 0x7fffffff;
    }
    return hash.toRadixString(16);
  }

  Future<bool> _downloadViaHttp({
    required String bucket,
    required String objectPath,
    required File outputFile,
  }) async {
    final encodedObject = Uri.encodeComponent(objectPath);
    final uri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedObject?alt=media',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Image fetch HTTP failed: status=${response.statusCode}, bucket=$bucket, object=$objectPath',
        );
        return false;
      }

      await outputFile.writeAsBytes(response.bodyBytes, flush: true);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Image fetch HTTP exception: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
