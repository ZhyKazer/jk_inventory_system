import 'package:flutter/material.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/stock_batch_provider.dart';
import 'package:jk_inventory_system/ui/pages/batches_page.dart';
import 'package:jk_inventory_system/ui/pages/categories_page.dart';
import 'package:jk_inventory_system/ui/pages/create_batch_page.dart';
import 'package:jk_inventory_system/ui/pages/outing_stepper_page.dart';
import 'package:jk_inventory_system/ui/pages/products_page.dart';
import 'package:jk_inventory_system/ui/widgets/forms/category_form_sheet.dart';
import 'package:jk_inventory_system/ui/widgets/forms/product_form_sheet.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.categoryProvider,
    required this.productProvider,
    required this.stockBatchProvider,
    required this.outingProvider,
  });

  final CategoryProvider categoryProvider;
  final ProductProvider productProvider;
  final StockBatchProvider stockBatchProvider;
  final OutingProvider outingProvider;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  bool _actionsFabExpanded = false;

  Future<void> _onAddProduct() async {
    setState(() => _actionsFabExpanded = false);
    if (widget.categoryProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create at least one category first.')),
      );
      return;
    }
    await showProductFormSheet(
      context,
      provider: widget.productProvider,
      categories: widget.categoryProvider.items,
    );
  }

  Future<void> _onAddCategory() async {
    setState(() => _actionsFabExpanded = false);
    await showCategoryFormSheet(
      context,
      provider: widget.categoryProvider,
    );
  }

  Future<void> _onAddBatch() async {
    setState(() => _actionsFabExpanded = false);
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateBatchPage(
          stockBatchProvider: widget.stockBatchProvider,
          productProvider: widget.productProvider,
        ),
      ),
    );

    if (created == true) {
      await widget.stockBatchProvider.load();
    }
  }

  Future<void> _onStartOuting() async {
    setState(() => _actionsFabExpanded = false);
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OutingStepperPage(
          outingProvider: widget.outingProvider,
          productProvider: widget.productProvider,
        ),
      ),
    );

    if (submitted == true) {
      await widget.outingProvider.load();
    }
  }

  Future<void> _onManageCategories() async {
    setState(() => _actionsFabExpanded = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoriesPage(
          categoryProvider: widget.categoryProvider,
          productProvider: widget.productProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProductsPage(
        productProvider: widget.productProvider,
        categoryProvider: widget.categoryProvider,
      ),
      BatchesPage(
        stockBatchProvider: widget.stockBatchProvider,
        productProvider: widget.productProvider,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Product List' : 'Batch List & History'),
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _actionsFabExpanded = false;
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            label: 'Batches',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_actionsFabExpanded) ...[
            FloatingActionButton.extended(
              heroTag: 'addProductFab',
              onPressed: _onAddProduct,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Add Product'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'addCategoryFab',
              onPressed: _onAddCategory,
              icon: const Icon(Icons.category_outlined),
              label: const Text('Add Category'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'addBatchFab',
              onPressed: _onAddBatch,
              icon: const Icon(Icons.settings_backup_restore_outlined),
              label: const Text('Add Stock Batch'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'outingFlowFab',
              onPressed: _onStartOuting,
              icon: const Icon(Icons.format_list_numbered_rtl_outlined),
              label: const Text('Start Outing Flow'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'manageCategoriesFab',
              onPressed: _onManageCategories,
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('Manage Categories'),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            heroTag: 'mainActionsFab',
            onPressed: () => setState(() => _actionsFabExpanded = !_actionsFabExpanded),
            child: Icon(_actionsFabExpanded ? Icons.close : Icons.add),
          ),
        ],
      ),
    );
  }
}
