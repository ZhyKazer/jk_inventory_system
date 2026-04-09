import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ProductImageCacheService {
  static final Map<String, Future<String?>> _inflight = {};

  Future<String?> resolveImagePath(String? imagePath) async {
    final normalized = imagePath?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final localFile = File(normalized);
    if (await localFile.exists()) {
      return localFile.path;
    }

    if (normalized.startsWith('gs://')) {
      return _resolveGsPath(normalized);
    }

    return null;
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
          return cacheFile.path;
        }

        await cacheFile.parent.create(recursive: true);

        final storage = FirebaseStorage.instanceFor(bucket: 'gs://$bucket');
        await storage.ref(objectPath).writeToFile(cacheFile);
        return cacheFile.path;
      } catch (_) {
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
}
