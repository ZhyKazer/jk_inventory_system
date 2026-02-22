import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/unit_type.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/stock_batch_provider.dart';

class BatchesPage extends StatelessWidget {
  const BatchesPage({
    super.key,
    required this.stockBatchProvider,
    required this.productProvider,
  });

  final StockBatchProvider stockBatchProvider;
  final ProductProvider productProvider;

  String _productName(String productId) {
    final matched = productProvider.items.where((item) => item.id == productId);
    return matched.isEmpty ? 'Unknown Product' : matched.first.name;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([stockBatchProvider, productProvider]),
      builder: (context, _) {
        final batches = stockBatchProvider.items;
        if (batches.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No batches yet. Use the action button to add a stock batch.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: batches.length,
          itemBuilder: (context, index) {
            final batch = batches[index];
            return Card(
              child: ExpansionTile(
                title: Text(batch.batchName),
                subtitle: Text(
                  '${batch.items.length} item(s) • ${batch.createdAt.toLocal()}',
                ),
                children: [
                  for (final item in batch.items)
                    ListTile(
                      title: Text(_productName(item.productId)),
                      subtitle: Text(item.unitType.label),
                      trailing: Text(
                        '${item.unitValue.toStringAsFixed(2)} • Cost ${item.originalPrice.toStringAsFixed(2)} • Sell ${item.sellingPrice.toStringAsFixed(2)}',
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
