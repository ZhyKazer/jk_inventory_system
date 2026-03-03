import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jk_inventory_system/models/activity_log.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';

class ActivityLogPage extends StatelessWidget {
  const ActivityLogPage({super.key, required this.activityLogProvider});

  final ActivityLogProvider activityLogProvider;

  String _actionLabel(ActivityActionType actionType) {
    switch (actionType) {
      case ActivityActionType.categoryCreated:
        return 'Category Created';
      case ActivityActionType.categoryUpdated:
        return 'Category Updated';
      case ActivityActionType.categoryDeleted:
        return 'Category Deleted';
      case ActivityActionType.productCreated:
        return 'Product Created';
      case ActivityActionType.productUpdated:
        return 'Product Updated';
      case ActivityActionType.productDeleted:
        return 'Product Deleted';
      case ActivityActionType.batchCreated:
        return 'Batch Created';
      case ActivityActionType.outingSubmitted:
        return 'Outing Submitted';
    }
  }

  Widget _receiptLine({
    required String label,
    required String value,
    bool emphasized = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetails(BuildContext context, ActivityLog item) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Receipt Preview'),
          content: SingleChildScrollView(
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'JK INVENTORY SYSTEM',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text('OFFICIAL ACTIVITY RECEIPT'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _receiptLine(label: 'Activity', value: _actionLabel(item.actionType)),
                  _receiptLine(
                    label: 'Date/Time',
                    value: DateFormat('MMM d, yyyy • h:mm:ss a').format(item.createdAt),
                  ),
                  _receiptLine(label: 'Title', value: item.title),
                  _receiptLine(label: 'Reference ID', value: item.referenceId ?? 'N/A'),
                  _receiptLine(label: 'Activity ID', value: item.id),
                  const SizedBox(height: 8),
                  Text(
                    'Details',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.description),
                  if (item.actionType == ActivityActionType.outingSubmitted) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Text(
                      'Outing Summary',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (item.displayed != null)
                      _receiptLine(label: 'Displayed', value: item.displayed!.toStringAsFixed(2)),
                    if (item.returned != null)
                      _receiptLine(label: 'Returned', value: item.returned!.toStringAsFixed(2)),
                    if (item.discarded != null)
                      _receiptLine(label: 'Discarded', value: item.discarded!.toStringAsFixed(2)),
                    if (item.replaced != null)
                      _receiptLine(label: 'Replaced', value: item.replaced!.toStringAsFixed(2)),
                    if (item.sold != null)
                      _receiptLine(label: 'Sold', value: item.sold!.toStringAsFixed(2)),
                    if (item.profit != null)
                      _receiptLine(
                        label: 'Approx. Profit',
                        value: item.profit!.toStringAsFixed(2),
                        emphasized: true,
                      ),
                    if (item.lost != null)
                      _receiptLine(label: 'Lost', value: item.lost!.toStringAsFixed(2)),
                  ],
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'System-generated receipt',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: activityLogProvider,
      builder: (context, _) {
        final items = activityLogProvider.items;
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No activity yet. Actions will appear here automatically.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                onTap: () => _showDetails(context, item),
                title: Text(item.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(item.description),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMM d, yyyy • h:mm a').format(item.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }
}
