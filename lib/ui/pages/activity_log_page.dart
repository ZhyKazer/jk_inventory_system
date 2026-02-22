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

  Future<void> _showDetails(BuildContext context, ActivityLog item) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('Type: ${_actionLabel(item.actionType)}'),
                const SizedBox(height: 6),
                Text(
                  'Date: ${DateFormat('MMM d, yyyy • h:mm:ss a').format(item.createdAt)}',
                ),
                const SizedBox(height: 6),
                Text('Description: ${item.description}'),
                const SizedBox(height: 6),
                if (item.actionType == ActivityActionType.outingSubmitted) ...[
                  if (item.displayed != null)
                    Text('Displayed: ${item.displayed!.toStringAsFixed(2)}'),
                  if (item.returned != null)
                    Text('Returned: ${item.returned!.toStringAsFixed(2)}'),
                  if (item.discarded != null)
                    Text('Discarded: ${item.discarded!.toStringAsFixed(2)}'),
                  if (item.replaced != null)
                    Text('Replaced: ${item.replaced!.toStringAsFixed(2)}'),
                  if (item.sold != null)
                    Text('Sold: ${item.sold!.toStringAsFixed(2)}'),
                  if (item.profit != null)
                    Text('Profit: ${item.profit!.toStringAsFixed(2)}'),
                  if (item.lost != null)
                    Text('Lost: ${item.lost!.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                ],
                Text('Reference ID: ${item.referenceId ?? 'N/A'}'),
                const SizedBox(height: 6),
                Text('Activity ID: ${item.id}'),
              ],
            ),
          ),
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
          separatorBuilder: (_, __) => const SizedBox(height: 8),
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
