import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:jk_inventory_system/models/category.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/models/stock_batch.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/services/inventory_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupException implements Exception {
  BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupFileInfo {
  BackupFileInfo({
    required this.path,
    required this.fileName,
    required this.sequence,
    required this.createdAt,
  });

  final String path;
  final String fileName;
  final int sequence;
  final DateTime createdAt;
}

class BackupCreateResult {
  BackupCreateResult({
    required this.filePath,
    required this.fileName,
    required this.deletedFiles,
    required this.productCount,
    required this.imageCount,
    required this.fileSizeBytes,
    required this.createdAt,
  });

  final String filePath;
  final String fileName;
  final List<String> deletedFiles;
  final int productCount;
  final int imageCount;
  final int fileSizeBytes;
  final DateTime createdAt;
}

class BackupService {
  static const int schemaVersion = 1;
  static const int maxBackupFiles = 10;
  static const String _prefsBackupDirectoryKey = 'backup.directory.path';
  static final RegExp _backupFileRegex = RegExp(
    r'^backup_(\d+)_(\d{2})_(\d{2})_(\d{4})_(\d{2})_(\d{2})_(\d{2})\.(json|zip)$',
    caseSensitive: false,
  );

  Future<String?> getSavedBackupDirectory() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_prefsBackupDirectoryKey);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  Future<String?> pickAndSaveBackupDirectory() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select backup folder',
    );

    if (selected == null || selected.trim().isEmpty) {
      return null;
    }

    if (Platform.isAndroid && selected.startsWith('content://')) {
      throw BackupException(
        'Selected folder is not directly writable on Android. The app will use an internal external backup folder instead.',
      );
    }

    final directory = Directory(selected);
    if (!await directory.exists()) {
      throw BackupException('Selected folder is not accessible.');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_prefsBackupDirectoryKey, selected);
    return selected;
  }

  Future<BackupCreateResult> createBackup({
    void Function(String statusMessage)? onProgress,
    bool validateAfterSave = true,
    bool Function()? shouldContinueValidation,
  }) async {
    final backupDirectory = await _resolveBackupDirectory();
    return _createBackupInDirectory(
      backupDirectory,
      onProgress: onProgress,
      validateAfterSave: validateAfterSave,
      shouldContinueValidation: shouldContinueValidation,
    );
  }

  Future<BackupCreateResult> _createBackupInDirectory(
    String backupDirectory, {
    void Function(String statusMessage)? onProgress,
    required bool validateAfterSave,
    bool Function()? shouldContinueValidation,
  }) async {
    await _ensureDirectoryWritable(backupDirectory);

    final directory = Directory(backupDirectory);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final existingBackups = await _listBackupFiles(directory.path);
    var nextSequence = 1;
    if (existingBackups.isNotEmpty) {
      final highestSequence = existingBackups
          .map((entry) => entry.sequence)
          .fold<int>(0, (current, value) => value > current ? value : current);
      nextSequence = highestSequence + 1;
    }

    final now = DateTime.now();
    final fileName = _buildFileName(sequence: nextSequence, createdAt: now);
    final filePath = path.join(directory.path, fileName);
    final temporaryPath = '$filePath.tmp';

    final imagesToBackup = await _collectProductImagesForBackup();
    onProgress?.call('saving json information');
    final payload = await _buildBackupPayload(
      createdAt: now,
      productImageArchivePaths: {
        for (final entry in imagesToBackup) entry.productId: entry.archivePath,
      },
    );
    final jsonContent = const JsonEncoder.withIndent('  ').convert(payload);

    List<String> deletedFiles;
    try {
      final archive = Archive();
      archive.addFile(ArchiveFile.string('backup.json', jsonContent));

      for (final imageEntry in imagesToBackup) {
        final imageFile = File(imageEntry.sourcePath);
        if (!await imageFile.exists()) {
          continue;
        }

        onProgress?.call('saving ${imageEntry.productName} image...');

        final imageBytes = await imageFile.readAsBytes();
        archive.addFile(ArchiveFile.bytes(imageEntry.archivePath, imageBytes));

        final shouldValidateThisImage =
            validateAfterSave && (shouldContinueValidation?.call() ?? true);
        if (shouldValidateThisImage) {
          onProgress?.call(
            'validating ${imageEntry.productName} image is saved',
          );
          final archivedImage = archive.findFile(imageEntry.archivePath);
          if (archivedImage == null ||
              archivedImage.size != imageBytes.length) {
            throw BackupException(
              'Backup validation failed for ${imageEntry.productName} image.',
            );
          }
        }
      }

      final encodedArchive = ZipEncoder().encode(archive);

      final temporaryFile = File(temporaryPath);
      await temporaryFile.writeAsBytes(encodedArchive, flush: true);

      final targetFile = File(filePath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      await temporaryFile.rename(filePath);

      deletedFiles = await _applyRetentionPolicy(directory.path);
    } on BackupException catch (error) {
      await _deleteFileIfExists(temporaryPath);
      await _deleteFileIfExists(filePath);

      if (error.message.startsWith('Backup validation failed')) {
        throw BackupException(
          'Backup validation failed. Broken backup was deleted. Please retry backup.',
        );
      }

      rethrow;
    } on FileSystemException {
      await _deleteFileIfExists(temporaryPath);
      await _deleteFileIfExists(filePath);
      throw BackupException('Cannot write backup to the selected folder.');
    }

    return BackupCreateResult(
      filePath: filePath,
      fileName: fileName,
      deletedFiles: deletedFiles,
      productCount: Hive.box<Product>(InventoryStorage.productsBoxName).length,
      imageCount: imagesToBackup.length,
      fileSizeBytes: File(filePath).lengthSync(),
      createdAt: now,
    );
  }

  Future<List<BackupFileInfo>> listRecentBackups({int limit = 5}) async {
    final directoryPath = await getSavedBackupDirectory();
    if (directoryPath == null) {
      return [];
    }

    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return [];
    }

    final backups = await _listBackupFiles(directory.path);
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (backups.length <= limit) {
      return backups;
    }

    return backups.take(limit).toList();
  }

  Future<void> _deleteFileIfExists(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return;
    }

    try {
      await file.delete();
    } on FileSystemException {}
  }

  Future<void> restoreFromQuickBackup(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw BackupException('Backup file no longer exists.');
    }

    await _restoreFromFile(file);
  }

  Future<String?> pickBackupFileForImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip', 'json'],
      dialogTitle: 'Import backup file',
      allowMultiple: false,
    );

    final selectedPath = result?.files.single.path;
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return null;
    }

    return selectedPath;
  }

  Future<void> restoreFromAnyFilePath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw BackupException('Selected backup file does not exist.');
    }

    await _restoreFromFile(file);
  }

  Future<String?> importBackupAndRestore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip', 'json'],
      dialogTitle: 'Import backup file',
      allowMultiple: false,
    );

    final selectedPath = result?.files.single.path;
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return null;
    }

    final file = File(selectedPath);
    if (!await file.exists()) {
      throw BackupException('Selected backup file does not exist.');
    }

    await _restoreFromFile(file);
    return path.basename(selectedPath);
  }

  Future<void> _restoreFromFile(File file) async {
    final extension = path.extension(file.path).toLowerCase();
    if (extension == '.zip') {
      await _restoreFromZipFile(file);
      return;
    }

    if (extension != '.json') {
      throw BackupException(
        'Unsupported backup file type. Please select a .zip or .json backup.',
      );
    }

    final rawContent = await file.readAsString();
    final parsed = _parseAndValidateBackup(rawContent);
    await _replaceAllData(parsed);
  }

  Future<void> _restoreFromZipFile(File file) async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'jk_inventory_restore_',
    );

    try {
      final input = InputFileStream(file.path);
      late Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } catch (_) {
        throw BackupException('Backup archive is invalid or corrupted.');
      } finally {
        input.close();
      }

      extractArchiveToDisk(archive, tempDirectory.path);

      final backupJsonFile = await _findBackupJsonFile(tempDirectory.path);
      final rawContent = await backupJsonFile.readAsString();
      final parsed = _parseAndValidateBackup(rawContent);

      final restoredImagePaths = await _restoreArchivedImages(
        tempDirectory.path,
      );
      final resolved = _resolveRestoredProductImagePaths(
        parsed,
        restoredImagePaths,
      );

      await _replaceAllData(resolved);
    } finally {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    }
  }

  Future<String> _resolveBackupDirectory() async {
    final savedDirectory = await getSavedBackupDirectory();
    if (savedDirectory != null &&
        _isFileSystemDirectoryPath(savedDirectory) &&
        await Directory(savedDirectory).exists()) {
      return savedDirectory;
    }

    final pickedDirectory = await pickAndSaveBackupDirectory();
    if (pickedDirectory == null) {
      if (savedDirectory != null) {
        throw BackupException(
          'Backup folder is invalid. Please select a new folder.',
        );
      }
      throw BackupException('Backup folder selection was cancelled.');
    }

    return pickedDirectory;
  }

  bool _isFileSystemDirectoryPath(String directoryPath) {
    return !directoryPath.startsWith('content://');
  }

  Future<void> _ensureDirectoryWritable(String directoryPath) async {
    if (!Platform.isAndroid) {
      return;
    }

    if (!_needsBroadExternalStoragePermission(directoryPath)) {
      return;
    }

    final hasAccess = await _requestAndroidStorageAccess();
    if (!hasAccess) {
      throw BackupException(
        'Storage permission is required to write to this folder. Please allow Files access and try again.',
      );
    }
  }

  bool _needsBroadExternalStoragePermission(String directoryPath) {
    final normalized = directoryPath.replaceAll('\\', '/').toLowerCase();
    if (!normalized.startsWith('/storage/emulated/0/')) {
      return false;
    }

    return !normalized.contains('/android/data/');
  }

  Future<bool> _requestAndroidStorageAccess() async {
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    final manageStatus = await Permission.manageExternalStorage.request();
    if (manageStatus.isGranted) {
      return true;
    }

    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  Future<List<BackupFileInfo>> _listBackupFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return [];
    }

    final files = await directory
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    final backups = <BackupFileInfo>[];

    for (final file in files) {
      final fileName = path.basename(file.path);
      final match = _backupFileRegex.firstMatch(fileName);
      if (match == null) {
        continue;
      }

      final sequence = int.tryParse(match.group(1) ?? '');
      final day = int.tryParse(match.group(2) ?? '');
      final month = int.tryParse(match.group(3) ?? '');
      final year = int.tryParse(match.group(4) ?? '');
      final hour = int.tryParse(match.group(5) ?? '');
      final minute = int.tryParse(match.group(6) ?? '');
      final second = int.tryParse(match.group(7) ?? '');

      if (sequence == null ||
          day == null ||
          month == null ||
          year == null ||
          hour == null ||
          minute == null ||
          second == null) {
        continue;
      }

      final createdAt = DateTime(year, month, day, hour, minute, second);

      backups.add(
        BackupFileInfo(
          path: file.path,
          fileName: fileName,
          sequence: sequence,
          createdAt: createdAt,
        ),
      );
    }

    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  Future<List<String>> _applyRetentionPolicy(String directoryPath) async {
    final backups = await _listBackupFiles(directoryPath);
    if (backups.length <= maxBackupFiles) {
      return [];
    }

    final overflow = backups.skip(maxBackupFiles).toList();
    final deleted = <String>[];

    for (final backup in overflow) {
      final file = File(backup.path);
      if (await file.exists()) {
        await file.delete();
        deleted.add(backup.fileName);
      }
    }

    return deleted;
  }

  Future<Map<String, dynamic>> _buildBackupPayload({
    required DateTime createdAt,
    required Map<String, String> productImageArchivePaths,
  }) async {
    final categories = Hive.box<Category>(
      InventoryStorage.categoriesBoxName,
    ).values.map(_categoryToJson).toList();
    final products = Hive.box<Product>(InventoryStorage.productsBoxName).values
        .map(
          (product) => _productToJson(
            product,
            imageArchivePath: productImageArchivePaths[product.id],
          ),
        )
        .toList();
    final stockBatches = Hive.box<StockBatch>(
      InventoryStorage.stockBatchesBoxName,
    ).values.map(_stockBatchToJson).toList();
    final outings = Hive.box<OutingRecord>(
      InventoryStorage.outingsBoxName,
    ).values.map(_outingToJson).toList();
    final activityLogs = Hive.box<ActivityLog>(
      InventoryStorage.activityLogsBoxName,
    ).values.map(_activityLogToJson).toList();

    final packageInfo = await PackageInfo.fromPlatform();

    return {
      'meta': {
        'schemaVersion': schemaVersion,
        'appVersion': packageInfo.version,
        'createdAt': createdAt.toUtc().toIso8601String(),
      },
      'data': {
        'categories': categories,
        'products': products,
        'stockBatches': stockBatches,
        'outings': outings,
        'activityLogs': activityLogs,
        'settings': <String, dynamic>{},
      },
    };
  }

  String _buildFileName({required int sequence, required DateTime createdAt}) {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year.toString().padLeft(4, '0');
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final second = createdAt.second.toString().padLeft(2, '0');

    return 'backup_${sequence}_${day}_${month}_${year}_${hour}_${minute}_$second.zip';
  }

  Future<List<_BackupImageEntry>> _collectProductImagesForBackup() async {
    final products = Hive.box<Product>(InventoryStorage.productsBoxName).values;
    final uniqueArchivePaths = <String>{};
    final entries = <_BackupImageEntry>[];

    for (final product in products) {
      final imagePath = product.imagePath;
      if (imagePath == null || imagePath.trim().isEmpty) {
        continue;
      }

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        continue;
      }

      final archivePath = _buildUniqueImageArchivePath(
        productId: product.id,
        sourceImagePath: imagePath,
        existingPaths: uniqueArchivePaths,
      );
      uniqueArchivePaths.add(archivePath);

      entries.add(
        _BackupImageEntry(
          productId: product.id,
          productName: product.name.trim().isEmpty ? product.id : product.name,
          sourcePath: imagePath,
          archivePath: archivePath,
        ),
      );
    }

    return entries;
  }

  String _buildUniqueImageArchivePath({
    required String productId,
    required String sourceImagePath,
    required Set<String> existingPaths,
  }) {
    final originalName = path.basename(sourceImagePath);
    final safeName = _sanitizeFileName(
      originalName.isEmpty ? 'product_image.png' : originalName,
    );
    final safeProductId = _sanitizeFileName(productId);

    var candidate = 'images/${safeProductId}_$safeName';
    var counter = 1;
    while (existingPaths.contains(candidate)) {
      final baseName = path.basenameWithoutExtension(safeName);
      final extension = path.extension(safeName);
      candidate = 'images/${safeProductId}_${baseName}_$counter$extension';
      counter += 1;
    }

    return candidate;
  }

  String _sanitizeFileName(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  Future<File> _findBackupJsonFile(String extractedPath) async {
    final exactPath = path.join(extractedPath, 'backup.json');
    final exactFile = File(exactPath);
    if (await exactFile.exists()) {
      return exactFile;
    }

    final files = await Directory(extractedPath)
        .list(recursive: true)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => path.extension(file.path).toLowerCase() == '.json')
        .toList();

    if (files.isEmpty) {
      throw BackupException(
        'Backup archive does not contain a JSON backup file.',
      );
    }

    files.sort((a, b) {
      final aName = path.basename(a.path).toLowerCase();
      final bName = path.basename(b.path).toLowerCase();
      if (aName == 'backup.json') return -1;
      if (bName == 'backup.json') return 1;
      return aName.compareTo(bName);
    });

    return files.first;
  }

  Future<Map<String, String>> _restoreArchivedImages(
    String extractedPath,
  ) async {
    final extractedImagesDirectory = Directory(
      path.join(extractedPath, 'images'),
    );
    if (!await extractedImagesDirectory.exists()) {
      return {};
    }

    final docsDirectory = await getApplicationDocumentsDirectory();
    final targetImagesDirectory = Directory(
      path.join(docsDirectory.path, 'product_images'),
    );
    if (!await targetImagesDirectory.exists()) {
      await targetImagesDirectory.create(recursive: true);
    }

    final restoredMap = <String, String>{};

    final files = await extractedImagesDirectory
        .list(recursive: true)
        .where((entity) => entity is File)
        .cast<File>()
        .toList();

    for (final file in files) {
      final relativeFromExtracted = path
          .relative(file.path, from: extractedPath)
          .replaceAll('\\', '/');

      final originalFileName = path.basename(file.path);
      final safeFileName = _sanitizeFileName(
        originalFileName.isEmpty ? 'image.png' : originalFileName,
      );
      final targetPath = await _buildUniqueTargetImagePath(
        targetImagesDirectory.path,
        safeFileName,
      );

      await file.copy(targetPath);
      restoredMap[relativeFromExtracted] = targetPath;
    }

    return restoredMap;
  }

  Future<String> _buildUniqueTargetImagePath(
    String directoryPath,
    String fileName,
  ) async {
    var candidatePath = path.join(directoryPath, fileName);
    final baseName = path.basenameWithoutExtension(fileName);
    final extension = path.extension(fileName);
    var counter = 1;

    while (await File(candidatePath).exists()) {
      candidatePath = path.join(
        directoryPath,
        '${baseName}_$counter$extension',
      );
      counter += 1;
    }

    return candidatePath;
  }

  _ParsedBackupData _resolveRestoredProductImagePaths(
    _ParsedBackupData parsed,
    Map<String, String> restoredImagePaths,
  ) {
    final products = parsed.products.map((product) {
      final imagePath = product.imagePath;
      if (imagePath == null || imagePath.trim().isEmpty) {
        return product;
      }

      final normalized = imagePath.replaceAll('\\', '/');
      if (!normalized.startsWith('images/')) {
        return product;
      }

      final restoredPath = restoredImagePaths[normalized];
      if (restoredPath == null) {
        return product;
      }

      return product.copyWith(imagePath: restoredPath);
    }).toList();

    return _ParsedBackupData(
      categories: parsed.categories,
      products: products,
      stockBatches: parsed.stockBatches,
      outings: parsed.outings,
      activityLogs: parsed.activityLogs,
    );
  }

  _ParsedBackupData _parseAndValidateBackup(String jsonContent) {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonContent);
    } catch (_) {
      throw BackupException('Backup file is not valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw BackupException('Backup file format is invalid.');
    }

    final meta = decoded['meta'];
    final data = decoded['data'];
    if (meta is! Map<String, dynamic> || data is! Map<String, dynamic>) {
      throw BackupException('Backup file is missing required sections.');
    }

    final parsedSchemaVersion = meta['schemaVersion'];
    if (parsedSchemaVersion is! int) {
      throw BackupException('Backup schema version is invalid.');
    }

    if (parsedSchemaVersion != schemaVersion) {
      throw BackupException(
        'Unsupported backup schema version: $parsedSchemaVersion.',
      );
    }

    final categoriesRaw = _requireList(data, 'categories');
    final productsRaw = _requireList(data, 'products');
    final stockBatchesRaw = _requireList(data, 'stockBatches');
    final outingsRaw = _requireList(data, 'outings');
    final activityLogsRaw = _requireList(data, 'activityLogs');

    final categories = categoriesRaw.map(_categoryFromJson).toList();
    final products = productsRaw.map(_productFromJson).toList();
    final stockBatches = stockBatchesRaw.map(_stockBatchFromJson).toList();
    final outings = outingsRaw.map(_outingFromJson).toList();
    final activityLogs = activityLogsRaw.map(_activityLogFromJson).toList();

    return _ParsedBackupData(
      categories: categories,
      products: products,
      stockBatches: stockBatches,
      outings: outings,
      activityLogs: activityLogs,
    );
  }

  List<Map<String, dynamic>> _requireList(
    Map<String, dynamic> source,
    String key,
  ) {
    final value = source[key];
    if (value is! List) {
      throw BackupException('Backup data "$key" is missing or invalid.');
    }

    try {
      return value.cast<Map<String, dynamic>>();
    } catch (_) {
      throw BackupException('Backup data "$key" has invalid entries.');
    }
  }

  Future<void> _replaceAllData(_ParsedBackupData parsed) async {
    final categoriesBox = Hive.box<Category>(
      InventoryStorage.categoriesBoxName,
    );
    final productsBox = Hive.box<Product>(InventoryStorage.productsBoxName);
    final stockBatchesBox = Hive.box<StockBatch>(
      InventoryStorage.stockBatchesBoxName,
    );
    final outingsBox = Hive.box<OutingRecord>(InventoryStorage.outingsBoxName);
    final activityLogsBox = Hive.box<ActivityLog>(
      InventoryStorage.activityLogsBoxName,
    );

    await categoriesBox.clear();
    await productsBox.clear();
    await stockBatchesBox.clear();
    await outingsBox.clear();
    await activityLogsBox.clear();

    await categoriesBox.putAll({
      for (final item in parsed.categories) item.id: item,
    });
    await productsBox.putAll({
      for (final item in parsed.products) item.id: item,
    });
    await stockBatchesBox.putAll({
      for (final item in parsed.stockBatches) item.id: item,
    });
    await outingsBox.putAll({for (final item in parsed.outings) item.id: item});
    await activityLogsBox.putAll({
      for (final item in parsed.activityLogs) item.id: item,
    });
  }

  Map<String, dynamic> _categoryToJson(Category item) => {
    'id': item.id,
    'name': item.name,
    'colorHex': item.colorHex,
    'requireProductImage': item.requireProductImage,
    'allowFlexibleSellingPrice': item.allowFlexibleSellingPrice,
    'createdAt': item.createdAt.toUtc().toIso8601String(),
    'updatedAt': item.updatedAt.toUtc().toIso8601String(),
  };

  Category _categoryFromJson(Map<String, dynamic> json) {
    return Category(
      id: _requireString(json, 'id'),
      name: _requireString(json, 'name'),
      colorHex: _requireString(json, 'colorHex'),
      requireProductImage: _readCategoryRequireProductImage(json),
      allowFlexibleSellingPrice: _readCategoryAllowFlexibleSellingPrice(json),
      createdAt: _parseDateTime(_requireString(json, 'createdAt')),
      updatedAt: _parseDateTime(_requireString(json, 'updatedAt')),
    );
  }

  bool _readCategoryRequireProductImage(Map<String, dynamic> json) {
    final requireProductImage = json['requireProductImage'];
    if (requireProductImage is bool) {
      return requireProductImage;
    }

    // Backward compatibility for legacy backups that still store `defaultUnit`.
    final legacyDefaultUnit = json['defaultUnit'];
    if (legacyDefaultUnit is String) {
      return false;
    }

    return false;
  }

  bool _readCategoryAllowFlexibleSellingPrice(Map<String, dynamic> json) {
    final allowFlexibleSellingPrice = json['allowFlexibleSellingPrice'];
    if (allowFlexibleSellingPrice is bool) {
      return allowFlexibleSellingPrice;
    }
    return false;
  }

  Map<String, dynamic> _productToJson(
    Product item, {
    String? imageArchivePath,
  }) => {
    'id': item.id,
    'categoryId': item.categoryId,
    'name': item.name,
    'imagePath': imageArchivePath ?? item.imagePath,
    'costPrice': item.costPrice,
    'sellingPrice': item.sellingPrice,
    'createdAt': item.createdAt.toUtc().toIso8601String(),
    'updatedAt': item.updatedAt.toUtc().toIso8601String(),
  };

  Product _productFromJson(Map<String, dynamic> json) {
    return Product(
      id: _requireString(json, 'id'),
      categoryId: _requireString(json, 'categoryId'),
      name: _requireString(json, 'name'),
      imagePath: _requireOptionalString(json, 'imagePath'),
      costPrice: _requireDouble(json, 'costPrice'),
      sellingPrice: _requireDouble(json, 'sellingPrice'),
      createdAt: _parseDateTime(_requireString(json, 'createdAt')),
      updatedAt: _parseDateTime(_requireString(json, 'updatedAt')),
    );
  }

  Map<String, dynamic> _stockBatchToJson(StockBatch item) => {
    'id': item.id,
    'batchName': item.batchName,
    'createdAt': item.createdAt.toUtc().toIso8601String(),
    'items': item.items
        .map(
          (entry) => {
            'productId': entry.productId,
            'unitType': entry.unitType.name,
            'unitValue': entry.unitValue,
            'originalPrice': entry.originalPrice,
            'sellingPrice': entry.sellingPrice,
          },
        )
        .toList(),
  };

  StockBatch _stockBatchFromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    if (itemsRaw is! List) {
      throw BackupException('Stock batch items are invalid.');
    }

    final items = itemsRaw.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw BackupException('Stock batch item is invalid.');
      }

      return BatchItem(
        productId: _requireString(entry, 'productId'),
        unitType: _unitTypeFromString(_requireString(entry, 'unitType')),
        unitValue: _requireDouble(entry, 'unitValue'),
        originalPrice: _requireDouble(entry, 'originalPrice'),
        sellingPrice: _requireDouble(entry, 'sellingPrice'),
      );
    }).toList();

    return StockBatch(
      id: _requireString(json, 'id'),
      batchName: _requireString(json, 'batchName'),
      createdAt: _parseDateTime(_requireString(json, 'createdAt')),
      items: items,
    );
  }

  Map<String, dynamic> _outingToJson(OutingRecord item) => {
    'id': item.id,
    'date': item.date.toUtc().toIso8601String(),
    'status': item.status.name,
    'displayedProducts': _outingLinesToJson(item.displayedProducts),
    'returnedProducts': _outingLinesToJson(item.returnedProducts),
    'discardedProducts': _outingLinesToJson(item.discardedProducts),
    'replacedDiscardedProducts': _outingLinesToJson(
      item.replacedDiscardedProducts,
    ),
    'submittedAt': item.submittedAt?.toUtc().toIso8601String(),
    'totalDisplayed': item.totalDisplayed,
    'totalReturned': item.totalReturned,
    'totalDiscarded': item.totalDiscarded,
    'totalReplaced': item.totalReplaced,
    'totalSold': item.totalSold,
    'totalRevenue': item.totalRevenue,
    'totalCapital': item.totalCapital,
    'approximateProfit': item.approximateProfit,
  };

  OutingRecord _outingFromJson(Map<String, dynamic> json) {
    return OutingRecord(
      id: _requireString(json, 'id'),
      date: _parseDateTime(_requireString(json, 'date')),
      status: _outingStatusFromString(_requireString(json, 'status')),
      displayedProducts: _outingLinesFromJson(
        json['displayedProducts'],
        'displayedProducts',
      ),
      returnedProducts: _outingLinesFromJson(
        json['returnedProducts'],
        'returnedProducts',
      ),
      discardedProducts: _outingLinesFromJson(
        json['discardedProducts'],
        'discardedProducts',
      ),
      replacedDiscardedProducts: _outingLinesFromJson(
        json['replacedDiscardedProducts'],
        'replacedDiscardedProducts',
      ),
      submittedAt: _parseOptionalDateTime(json['submittedAt']),
      totalDisplayed: _parseOptionalDouble(json['totalDisplayed']),
      totalReturned: _parseOptionalDouble(json['totalReturned']),
      totalDiscarded: _parseOptionalDouble(json['totalDiscarded']),
      totalReplaced: _parseOptionalDouble(json['totalReplaced']),
      totalSold: _parseOptionalDouble(json['totalSold']),
      totalRevenue: _parseOptionalDouble(json['totalRevenue']),
      totalCapital: _parseOptionalDouble(json['totalCapital']),
      approximateProfit: _parseOptionalDouble(json['approximateProfit']),
    );
  }

  List<Map<String, dynamic>> _outingLinesToJson(List<OutingLine> lines) {
    return lines
        .map(
          (line) => {
            'productId': line.productId,
            'unitType': line.unitType.name,
            'value': line.value,
            'sellingPriceOverride': line.sellingPriceOverride,
          },
        )
        .toList();
  }

  List<OutingLine> _outingLinesFromJson(dynamic value, String key) {
    if (value is! List) {
      throw BackupException('Outing "$key" is invalid.');
    }

    return value.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw BackupException('Outing line in "$key" is invalid.');
      }

      return OutingLine(
        productId: _requireString(entry, 'productId'),
        unitType: _unitTypeFromString(_requireString(entry, 'unitType')),
        value: _requireDouble(entry, 'value'),
        sellingPriceOverride: _parseOptionalDouble(
          entry['sellingPriceOverride'],
        ),
      );
    }).toList();
  }

  Map<String, dynamic> _activityLogToJson(ActivityLog item) => {
    'id': item.id,
    'actionType': item.actionType.name,
    'title': item.title,
    'description': item.description,
    'referenceId': item.referenceId,
    'createdAt': item.createdAt.toUtc().toIso8601String(),
    'displayed': item.displayed,
    'returned': item.returned,
    'discarded': item.discarded,
    'replaced': item.replaced,
    'sold': item.sold,
    'profit': item.profit,
    'lost': item.lost,
    'productDetails': item.productDetails,
  };

  ActivityLog _activityLogFromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: _requireString(json, 'id'),
      actionType: _activityActionTypeFromString(
        _requireString(json, 'actionType'),
      ),
      title: _requireString(json, 'title'),
      description: _requireString(json, 'description'),
      referenceId: _requireOptionalString(json, 'referenceId'),
      createdAt: _parseDateTime(_requireString(json, 'createdAt')),
      displayed: _parseOptionalDouble(json['displayed']),
      returned: _parseOptionalDouble(json['returned']),
      discarded: _parseOptionalDouble(json['discarded']),
      replaced: _parseOptionalDouble(json['replaced']),
      sold: _parseOptionalDouble(json['sold']),
      profit: _parseOptionalDouble(json['profit']),
      lost: _parseOptionalDouble(json['lost']),
      productDetails: _requireOptionalString(json, 'productDetails'),
    );
  }

  String _requireString(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is! String || value.trim().isEmpty) {
      throw BackupException('Backup value "$key" is missing or invalid.');
    }
    return value;
  }

  String? _requireOptionalString(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value == null) return null;
    if (value is String) return value;
    throw BackupException('Backup value "$key" is invalid.');
  }

  double _requireDouble(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is num) {
      return value.toDouble();
    }
    throw BackupException('Backup value "$key" is missing or invalid.');
  }

  double? _parseOptionalDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    throw BackupException('Backup numeric value is invalid.');
  }

  DateTime _parseDateTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw BackupException('Backup date value is invalid.');
    }
    return parsed;
  }

  DateTime? _parseOptionalDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw BackupException('Backup date value is invalid.');
    }
    return _parseDateTime(value);
  }

  UnitType _unitTypeFromString(String value) {
    for (final unit in UnitType.values) {
      if (unit.name == value) {
        return unit;
      }
    }
    throw BackupException('Backup unit type "$value" is invalid.');
  }

  OutingStatus _outingStatusFromString(String value) {
    for (final status in OutingStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    throw BackupException('Backup outing status "$value" is invalid.');
  }

  ActivityActionType _activityActionTypeFromString(String value) {
    for (final actionType in ActivityActionType.values) {
      if (actionType.name == value) {
        return actionType;
      }
    }
    throw BackupException('Backup activity action "$value" is invalid.');
  }
}

class _ParsedBackupData {
  _ParsedBackupData({
    required this.categories,
    required this.products,
    required this.stockBatches,
    required this.outings,
    required this.activityLogs,
  });

  final List<Category> categories;
  final List<Product> products;
  final List<StockBatch> stockBatches;
  final List<OutingRecord> outings;
  final List<ActivityLog> activityLogs;
}

class _BackupImageEntry {
  _BackupImageEntry({
    required this.productId,
    required this.productName,
    required this.sourcePath,
    required this.archivePath,
  });

  final String productId;
  final String productName;
  final String sourcePath;
  final String archivePath;
}
