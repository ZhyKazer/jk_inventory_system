import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageProcessingService {
  Future<String?> processAndStoreAsPng({
    required String sourcePath,
    required String folderName,
    required String filenamePrefix,
    required int index,
  }) async {
    try {
      final sourceBytes = await File(sourcePath).readAsBytes();
      final outputBytes = await compute<Uint8List, Uint8List?>(
        _transformImageToPng,
        sourceBytes,
      );
      if (outputBytes == null) {
        return null;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory(p.join(docsDir.path, folderName));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final fileName =
          '${filenamePrefix}_${DateTime.now().microsecondsSinceEpoch}_$index.png';
      final outputPath = p.join(outputDir.path, fileName);
      await File(outputPath).writeAsBytes(outputBytes, flush: true);
      return outputPath;
    } catch (_) {
      return null;
    }
  }
}

Uint8List? _transformImageToPng(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    return null;
  }

  var output = decoded;
  const maxSide = 1600;
  if (output.width > maxSide || output.height > maxSide) {
    if (output.width >= output.height) {
      output = img.copyResize(
        output,
        width: maxSide,
        interpolation: img.Interpolation.average,
      );
    } else {
      output = img.copyResize(
        output,
        height: maxSide,
        interpolation: img.Interpolation.average,
      );
    }
  }

  return Uint8List.fromList(img.encodePng(output, level: 9));
}
