import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/sold_session.dart';
import 'package:jk_inventory_system/providers/sold_session_provider.dart';
import 'package:jk_inventory_system/ui/widgets/app_loading.dart';

class ReviewPurchasePage extends StatefulWidget {
  const ReviewPurchasePage({super.key, required this.soldSessionProvider});

  final SoldSessionProvider soldSessionProvider;

  @override
  State<ReviewPurchasePage> createState() => _ReviewPurchasePageState();
}

class _ReviewPurchasePageState extends State<ReviewPurchasePage> {
  final List<SoldSession> _pendingArchiveBatch = <SoldSession>[];
  final Set<String> _queuedDeletionIds = <String>{};

  Future<void> _queueDeliveredSessionForDelete(SoldSession session) async {
    if (_queuedDeletionIds.contains(session.id)) {
      return;
    }

    setState(() {
      _queuedDeletionIds.add(session.id);
      _pendingArchiveBatch.add(session);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Queued ${session.username} for deletion (${_pendingArchiveBatch.length} queued).',
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteQueued() async {
    if (_pendingArchiveBatch.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No queued items to delete.')),
      );
      return;
    }

    final count = _pendingArchiveBatch.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Delete $count queued archived instance(s) permanently from database and photos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final batch = _pendingArchiveBatch.toList(growable: false);
    setState(() {
      _pendingArchiveBatch.clear();
    });
    await AppLoading.run<void>(
      context,
      action: () => _finalizeDeletionBatch(batch),
      message: 'Deleting queued sessions...',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted $count queued instance(s).')),
    );
  }

  Future<void> _finalizeDeletionBatch(List<SoldSession> batch) async {
    for (final session in batch) {
      await widget.soldSessionProvider.deleteSession(session.id);
    }
    await _cleanupSessionPhotos(batch);

    if (!mounted) return;
    setState(() {
      for (final session in batch) {
        _queuedDeletionIds.remove(session.id);
      }
    });
  }

  Future<void> _cleanupSessionPhotos(List<SoldSession> batch) async {
    for (final session in batch) {
      for (final line in session.lines) {
        await _deletePhotoReference(line.gcashReceiptImagePath);
        await _deletePhotoReference(line.shopeeCheckoutImagePath);
      }
    }
  }

  Future<void> _deletePhotoReference(String? imagePath) async {
    final normalized = (imagePath ?? '').trim();
    if (normalized.isEmpty) {
      return;
    }

    try {
      if (normalized.startsWith('gs://') || normalized.startsWith('https://')) {
        await FirebaseStorage.instance.refFromURL(normalized).delete();
        return;
      }

      final localFile = File(normalized);
      if (await localFile.exists()) {
        await localFile.delete();
      }
    } catch (_) {}
  }

  Future<void> _showStatusDialog(SoldSession session) async {
    var isPackaging = session.isPackaging;
    var isDroppedOff = session.isDroppedOff;
    var isDelivered = session.isDelivered;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Delivery Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: isPackaging,
                title: const Text('Status 1: Packaged'),
                onChanged: (value) {
                  setDialogState(() {
                    isPackaging = value ?? false;
                    if (!isPackaging) {
                      isDroppedOff = false;
                      isDelivered = false;
                    }
                  });
                },
              ),
              CheckboxListTile(
                value: isDroppedOff,
                title: const Text('Status 2: Dropped-off'),
                onChanged: isPackaging
                    ? (value) {
                        setDialogState(() {
                          isDroppedOff = value ?? false;
                          if (!isDroppedOff) {
                            isDelivered = false;
                          }
                        });
                      }
                    : null,
              ),
              CheckboxListTile(
                value: isDelivered,
                title: const Text('Status 3: Delivered'),
                onChanged: (isPackaging && isDroppedOff)
                    ? (value) {
                        setDialogState(() {
                          isDelivered = value ?? false;
                        });
                      }
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      return;
    }

    await AppLoading.run<void>(
      context,
      action: () => widget.soldSessionProvider.updateDeliveryStatus(
        session.id,
        isPackaging: isPackaging,
        isDroppedOff: isDroppedOff,
        isDelivered: isDelivered,
      ),
      message: 'Updating delivery status...',
    );
  }

  Future<void> _showLargePreview(String imagePath) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
            child: InteractiveViewer(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 36),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _proofPreview({required String label, required String? imagePath}) {
    final path = (imagePath ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: path.isEmpty ? null : () => _showLargePreview(path),
          child: Container(
            width: double.infinity,
            height: 190,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: path.isEmpty
                ? const Center(child: Text('No image'))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _showSessionInfo(SoldSession session) {
    final firstLine = session.lines.isNotEmpty ? session.lines.first : null;
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Purchase Session Info'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer name: ${session.customerName}'),
                Text('Mod/Admin username: ${session.username}'),
                const SizedBox(height: 10),
                _proofPreview(
                  label: 'Gcash image',
                  imagePath: firstLine?.gcashReceiptImagePath,
                ),
                const SizedBox(height: 10),
                _proofPreview(
                  label: 'SCO image',
                  imagePath: firstLine?.shopeeCheckoutImagePath,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _statusLabel(SoldSession session) {
    if (session.isDelivered) {
      return 'Delivered';
    }
    if (session.isDroppedOff) {
      return 'Dropped-off';
    }
    if (session.isPackaging) {
      return 'Packaged';
    }
    return 'Pending';
  }

  Color _statusColor(SoldSession session) {
    if (session.isDelivered) return Colors.green;
    if (session.isDroppedOff) return Colors.blue;
    if (session.isPackaging) return Colors.orange;
    return Colors.grey;
  }

  Future<bool?> _onDeleteSwipe(SoldSession session) async {
    await AppLoading.run<void>(
      context,
      action: () =>
          widget.soldSessionProvider.setArchived(session.id, archived: true),
      message: 'Archiving session...',
    );
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${session.username} moved to Archives.')),
    );
    return false;
  }

  Widget _buildSessionList(
    List<SoldSession> sessions, {
    required bool archived,
  }) {
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            archived
                ? 'No archived sessions yet.'
                : 'No active sold sessions submitted yet.',
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final productNames = session.lines
            .map((line) => line.productName)
            .toSet()
            .join(', ');
        final isDelivered = session.isDelivered;

        return Dismissible(
          key: ValueKey('sold_${session.id}_$archived'),
          direction: ((!archived && isDelivered) || archived)
              ? DismissDirection.endToStart
              : DismissDirection.none,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: archived
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              archived ? Icons.delete_outline : Icons.archive_outlined,
              color: archived ? Colors.red : Colors.blue,
            ),
          ),
          confirmDismiss: (_) => archived
              ? () async {
                  await _queueDeliveredSessionForDelete(session);
                  return false;
                }()
              : _onDeleteSwipe(session),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showSessionInfo(session),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${session.username} • ${session.customerName}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Quantity of Purchase: ${session.totalQuantity.toStringAsFixed(2)}',
                    ),
                    Text('Products Sold: $productNames'),
                    const SizedBox(height: 6),
                    Text(
                      'Status: ${archived ? 'Archived' : _statusLabel(session)}',
                      style: TextStyle(
                        color: archived
                            ? Colors.blueGrey
                            : _statusColor(session),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!archived && isDelivered)
                      const Text('Swipe left to move to Archives.'),
                    if (archived)
                      const Text('Swipe left to queue for manual deletion.'),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _showStatusDialog(session),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Update Status'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemCount: sessions.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.soldSessionProvider,
      builder: (context, _) {
        final visibleSessions = widget.soldSessionProvider.items
            .where((session) => !_queuedDeletionIds.contains(session.id))
            .toList(growable: false);

        final active = visibleSessions
            .where((session) => !session.isArchived)
            .toList(growable: false);
        final archived = visibleSessions
            .where((session) => session.isArchived)
            .toList(growable: false);

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              if (_pendingArchiveBatch.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_pendingArchiveBatch.length} queued for deletion',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _confirmAndDeleteQueued,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Queued'),
                      ),
                    ],
                  ),
                ),
              const TabBar(
                tabs: [
                  Tab(text: 'Active'),
                  Tab(text: 'Archives'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildSessionList(active, archived: false),
                    _buildSessionList(archived, archived: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
