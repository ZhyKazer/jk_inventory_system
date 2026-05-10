import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum StartupSystemStatus { online, maintenance, offline }

enum StartupBlockType { none, maintenance, offline, forceUpdate }

class StartupPolicyResult {
  const StartupPolicyResult({
    required this.blockType,
    required this.status,
    required this.remoteVersion,
    required this.currentVersion,
    this.updateUrl,
  });

  final StartupBlockType blockType;
  final StartupSystemStatus status;
  final String remoteVersion;
  final String currentVersion;
  final String? updateUrl;
}

class StartupPolicyService {
  StartupPolicyService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage =
          storage ??
          FirebaseStorage.instanceFor(
            bucket: 'gs://zhyshi-inventory-system.firebasestorage.app',
          );

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<StartupPolicyResult> check({required String currentVersion}) async {
    final snapshot = await _firestore.collection('startup').doc('app').get();
    if (!snapshot.exists) {
      throw StateError('Missing startup/app configuration in Firestore.');
    }

    final data = snapshot.data();
    if (data == null) {
      throw StateError('Invalid startup/app configuration in Firestore.');
    }

    final status = _parseStatus(data['system_status'] as String?);
    final remoteVersion = (data['version'] as String?)?.trim() ?? '';
    final configuredUpdateLink = (data['update_link'] as String?)?.trim() ?? '';

    final updateUrl = await _resolveUpdateUrl(configuredUpdateLink);

    if (status == StartupSystemStatus.offline) {
      return StartupPolicyResult(
        blockType: StartupBlockType.offline,
        status: status,
        remoteVersion: remoteVersion,
        currentVersion: currentVersion,
        updateUrl: updateUrl,
      );
    }

    if (status == StartupSystemStatus.maintenance) {
      return StartupPolicyResult(
        blockType: StartupBlockType.maintenance,
        status: status,
        remoteVersion: remoteVersion,
        currentVersion: currentVersion,
        updateUrl: updateUrl,
      );
    }

    if (remoteVersion.isNotEmpty && remoteVersion != currentVersion) {
      return StartupPolicyResult(
        blockType: StartupBlockType.forceUpdate,
        status: status,
        remoteVersion: remoteVersion,
        currentVersion: currentVersion,
        updateUrl: updateUrl,
      );
    }

    return StartupPolicyResult(
      blockType: StartupBlockType.none,
      status: status,
      remoteVersion: remoteVersion,
      currentVersion: currentVersion,
      updateUrl: updateUrl,
    );
  }

  StartupSystemStatus _parseStatus(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'offline':
        return StartupSystemStatus.offline;
      case 'maintenance':
        return StartupSystemStatus.maintenance;
      case 'online':
      default:
        return StartupSystemStatus.online;
    }
  }

  Future<String?> _resolveUpdateUrl(String configuredUpdateLink) async {
    final trimmed = configuredUpdateLink.trim();
    if (trimmed.isNotEmpty) {
      final gsDownload = await _gsToDownloadUrl(trimmed);
      if (gsDownload != null) {
        return gsDownload;
      }

      final normalized = _normalizeHttpUrl(trimmed);
      if (normalized != null) {
        return normalized;
      }
    }

    try {
      return await _storage.ref('apk/apk-release.apk').getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  String? _normalizeHttpUrl(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }

    final withScheme = raw.contains('://') ? raw : 'https://$raw';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    return uri.toString();
  }

  Future<String?> _gsToDownloadUrl(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'gs' || uri.host.isEmpty) {
      return null;
    }

    final objectPath = uri.path.startsWith('/')
        ? uri.path.substring(1)
        : uri.path;
    if (objectPath.isEmpty) {
      return null;
    }

    try {
      final storage = FirebaseStorage.instanceFor(bucket: 'gs://${uri.host}');
      return await storage.ref(objectPath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }
}
