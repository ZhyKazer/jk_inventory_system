import 'dart:convert';
import 'dart:io';

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
  });

  final String filePath;
  final String fileName;
  final List<String> deletedFiles;
}

class BackupService {
  static const int schemaVersion = 1;
  static const int maxBackupFiles = 10;
  static const String _prefsBackupDirectoryKey = 'backup.directory.path';
  static final RegExp _backupFileRegex = RegExp(
    r'^backup_(\d+)_(\d{2})_(\d{2})_(\d{4})_(\d{2})_(\d{2})_(\d{2})\.json$',
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

  Future<BackupCreateResult> createBackup() async {
    final backupDirectory = await _resolveBackupDirectory();
    return _createBackupInDirectory(backupDirectory);
  }

  Future<BackupCreateResult> _createBackupInDirectory(String backupDirectory) async {
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

    final payload = await _buildBackupPayload(createdAt: now);
    final jsonContent = const JsonEncoder.withIndent('  ').convert(payload);

    List<String> deletedFiles;
    try {
      final temporaryFile = File(temporaryPath);
      await temporaryFile.writeAsString(jsonContent, flush: true);

      final targetFile = File(filePath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      await temporaryFile.rename(filePath);

      deletedFiles = await _applyRetentionPolicy(directory.path);
    } on FileSystemException {
      throw BackupException(
        'Cannot write backup to the selected folder.',
      );
    }

    return BackupCreateResult(
      filePath: filePath,
      fileName: fileName,
      deletedFiles: deletedFiles,
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
      allowedExtensions: const ['json'],
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
      allowedExtensions: const ['json'],
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
    final rawContent = await file.readAsString();
    final parsed = _parseAndValidateBackup(rawContent);
    await _replaceAllData(parsed);
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
        throw BackupException('Backup folder is invalid. Please select a new folder.');
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

    final files = await directory.list().where((entity) => entity is File).cast<File>().toList();
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

      final createdAt = DateTime(
        year,
        month,
        day,
        hour,
        minute,
        second,
      );

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

  Future<Map<String, dynamic>> _buildBackupPayload({required DateTime createdAt}) async {
    final categories = Hive.box<Category>(InventoryStorage.categoriesBoxName)
        .values
        .map(_categoryToJson)
        .toList();
    final products = Hive.box<Product>(InventoryStorage.productsBoxName)
        .values
        .map(_productToJson)
        .toList();
    final stockBatches = Hive.box<StockBatch>(InventoryStorage.stockBatchesBoxName)
        .values
        .map(_stockBatchToJson)
        .toList();
    final outings = Hive.box<OutingRecord>(InventoryStorage.outingsBoxName)
        .values
        .map(_outingToJson)
        .toList();
    final activityLogs = Hive.box<ActivityLog>(InventoryStorage.activityLogsBoxName)
        .values
        .map(_activityLogToJson)
        .toList();

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

  String _buildFileName({
    required int sequence,
    required DateTime createdAt,
  }) {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year.toString().padLeft(4, '0');
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final second = createdAt.second.toString().padLeft(2, '0');

    return 'backup_${sequence}_${day}_${month}_${year}_${hour}_${minute}_$second.json';
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

  List<Map<String, dynamic>> _requireList(Map<String, dynamic> source, String key) {
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
    final categoriesBox = Hive.box<Category>(InventoryStorage.categoriesBoxName);
    final productsBox = Hive.box<Product>(InventoryStorage.productsBoxName);
    final stockBatchesBox = Hive.box<StockBatch>(InventoryStorage.stockBatchesBoxName);
    final outingsBox = Hive.box<OutingRecord>(InventoryStorage.outingsBoxName);
    final activityLogsBox = Hive.box<ActivityLog>(InventoryStorage.activityLogsBoxName);

    await categoriesBox.clear();
    await productsBox.clear();
    await stockBatchesBox.clear();
    await outingsBox.clear();
    await activityLogsBox.clear();

    await categoriesBox.putAll({for (final item in parsed.categories) item.id: item});
    await productsBox.putAll({for (final item in parsed.products) item.id: item});
    await stockBatchesBox.putAll({for (final item in parsed.stockBatches) item.id: item});
    await outingsBox.putAll({for (final item in parsed.outings) item.id: item});
    await activityLogsBox.putAll({for (final item in parsed.activityLogs) item.id: item});
  }

  Map<String, dynamic> _categoryToJson(Category item) => {
        'id': item.id,
        'name': item.name,
        'colorHex': item.colorHex,
        'defaultUnit': item.defaultUnit.name,
        'createdAt': item.createdAt.toUtc().toIso8601String(),
        'updatedAt': item.updatedAt.toUtc().toIso8601String(),
      };

  Category _categoryFromJson(Map<String, dynamic> json) {
    return Category(
      id: _requireString(json, 'id'),
      name: _requireString(json, 'name'),
      colorHex: _requireString(json, 'colorHex'),
      defaultUnit: _unitTypeFromString(_requireString(json, 'defaultUnit')),
      createdAt: _parseDateTime(_requireString(json, 'createdAt')),
      updatedAt: _parseDateTime(_requireString(json, 'updatedAt')),
    );
  }

  Map<String, dynamic> _productToJson(Product item) => {
        'id': item.id,
        'categoryId': item.categoryId,
        'name': item.name,
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
        'replacedDiscardedProducts': _outingLinesToJson(item.replacedDiscardedProducts),
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
      displayedProducts: _outingLinesFromJson(json['displayedProducts'], 'displayedProducts'),
      returnedProducts: _outingLinesFromJson(json['returnedProducts'], 'returnedProducts'),
      discardedProducts: _outingLinesFromJson(json['discardedProducts'], 'discardedProducts'),
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
      };

  ActivityLog _activityLogFromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: _requireString(json, 'id'),
      actionType: _activityActionTypeFromString(_requireString(json, 'actionType')),
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
