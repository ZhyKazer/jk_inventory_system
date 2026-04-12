import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:jk_inventory_system/models/sold_session.dart';
import 'package:jk_inventory_system/providers/sold_session_provider.dart';
import 'package:path/path.dart' as p;

class ReviewPurchasePage extends StatelessWidget {
  const ReviewPurchasePage({super.key, required this.soldSessionProvider});

  final SoldSessionProvider soldSessionProvider;

  Future<void> _markDone(BuildContext context, SoldSession session) async {
    await soldSessionProvider.markDone(session.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Marked purchase session from ${session.username} as done.',
        ),
      ),
    );
  }

  Future<void> _downloadSessionImages(
    BuildContext context,
    SoldSession session,
  ) async {
    final targetBasePath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select where to save purchase screenshots',
    );

    if (!context.mounted || targetBasePath == null || targetBasePath.isEmpty) {
      return;
    }

    final sanitizedUsername = session.username
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        .trim();
    final usernameFolder = sanitizedUsername.isEmpty
        ? 'unknown_user'
        : sanitizedUsername;
    final outputDir = Directory(p.join(targetBasePath, usernameFolder));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final datePart = DateFormat('ddMMyyyy_HH-mm').format(session.createdAt);
    var exportCount = 0;

    for (var i = 0; i < session.lines.length; i++) {
      final line = session.lines[i];
      final seq = (i + 1).toString().padLeft(2, '0');
      final gcashName = 'GCASH_${usernameFolder}_${datePart}_$seq.jpg';
      final scoName = 'SCO_${usernameFolder}_${datePart}_$seq.jpg';

      if ((line.gcashReceiptImagePath ?? '').trim().isNotEmpty) {
        final saved = await _saveAsJpg(
          sourcePath: line.gcashReceiptImagePath!,
          targetPath: p.join(outputDir.path, gcashName),
        );
        if (saved) exportCount++;
      }

      if ((line.shopeeCheckoutImagePath ?? '').trim().isNotEmpty) {
        final saved = await _saveAsJpg(
          sourcePath: line.shopeeCheckoutImagePath!,
          targetPath: p.join(outputDir.path, scoName),
        );
        if (saved) exportCount++;
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved $exportCount image(s) to ${outputDir.path}'),
      ),
    );
  }

  Future<bool> _saveAsJpg({
    required String sourcePath,
    required String targetPath,
  }) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        await File(targetPath).writeAsBytes(bytes, flush: true);
        return true;
      }

      final encoded = img.encodeJpg(decoded, quality: 88);
      await File(targetPath).writeAsBytes(encoded, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showSessionDetails(BuildContext context, SoldSession session) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Session Details'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: ${session.username}'),
                Text(
                  'Date: ${DateFormat('MMM d, yyyy • h:mm a').format(session.createdAt)}',
                ),
                Text(
                  'Total Quantity: ${session.totalQuantity.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 10),
                for (final line in session.lines)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${line.productName} • Qty ${line.quantity.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _detailImagePreview(
                            context,
                            imagePath: line.gcashReceiptImagePath,
                            label: 'GCash Receipt',
                          ),
                          const SizedBox(height: 6),
                          _detailImagePreview(
                            context,
                            imagePath: line.shopeeCheckoutImagePath,
                            label: 'Shopee Checkout Info',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => _downloadSessionImages(context, session),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download Images'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLargePreview(BuildContext context, String imagePath) {
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

  Widget _detailImagePreview(
    BuildContext context, {
    required String? imagePath,
    required String label,
  }) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_not_supported_outlined),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showLargePreview(context, imagePath),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  alignment: Alignment.center,
                  color: Colors.red.withValues(alpha: 0.15),
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: soldSessionProvider,
      builder: (context, _) {
        final sessions = soldSessionProvider.items;
        if (sessions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No sold sessions submitted yet.'),
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
            final isDone = session.status == SoldSessionStatus.done;

            return Dismissible(
              key: ValueKey('sold_${session.id}'),
              direction: isDone
                  ? DismissDirection.none
                  : DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
              ),
              confirmDismiss: (_) async {
                await _markDone(context, session);
                return false;
              },
              child: Card(
                color: isDone
                    ? Colors.green.withValues(alpha: 0.15)
                    : Theme.of(context).colorScheme.surfaceContainerLowest,
                child: ListTile(
                  onLongPress: () => _showSessionDetails(context, session),
                  title: Text(session.username),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Quantity of Purchase: ${session.totalQuantity.toStringAsFixed(2)}',
                      ),
                      Text('Products Sold: $productNames'),
                    ],
                  ),
                  trailing: isDone
                      ? const Icon(Icons.verified, color: Colors.green)
                      : const Icon(Icons.swipe_left_alt_outlined),
                ),
              ),
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemCount: sessions.length,
        );
      },
    );
  }
}
