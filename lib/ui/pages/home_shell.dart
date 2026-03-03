import 'package:flutter/material.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/stock_batch_provider.dart';
import 'package:jk_inventory_system/ui/pages/activity_log_page.dart';
import 'package:jk_inventory_system/ui/pages/analytics_page.dart';
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
    required this.activityLogProvider,
  });

  final ActivityLogProvider activityLogProvider;
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

  final GlobalKey _mainActionsFabKey = GlobalKey();
  final GlobalKey _addProductFabKey = GlobalKey();
  final GlobalKey _addCategoryFabKey = GlobalKey();
  final GlobalKey _addBatchFabKey = GlobalKey();
  final GlobalKey _outingFlowFabKey = GlobalKey();
  final GlobalKey _manageCategoriesFabKey = GlobalKey();
  final GlobalKey _helpFabKey = GlobalKey();
  final GlobalKey _productsNavKey = GlobalKey();
  final GlobalKey _batchesNavKey = GlobalKey();
  final GlobalKey _activityNavKey = GlobalKey();
  final GlobalKey _analyticsNavKey = GlobalKey();

  final List<_HelpStep> _helpSteps = const [
    _HelpStep(
      title: 'Action Button',
      message:
          'This is where everything starts. Tap the action button to open all available actions.',
      icon: Icons.add_circle_outline,
    ),
    _HelpStep(
      title: 'Add Product',
      message:
          'Add Product is where you can add your different types of products.',
      icon: Icons.inventory_2_outlined,
    ),
    _HelpStep(
      title: 'Add Category',
      message:
          'Add Category lets you create product groupings for better organization.',
      icon: Icons.category_outlined,
    ),
    _HelpStep(
      title: 'Add Stock Batch',
      message:
          'Add Stock Batch is where you record incoming stock quantities and costs.',
      icon: Icons.settings_backup_restore_outlined,
    ),
    _HelpStep(
      title: 'Start Outing Flow',
      message:
          'Start Outing Flow guides you when recording released, sold, and discarded items.',
      icon: Icons.format_list_numbered_rtl_outlined,
    ),
    _HelpStep(
      title: 'Manage Categories',
      message:
          'Manage Categories is where you review, rename, or remove categories.',
      icon: Icons.list_alt_outlined,
    ),
    _HelpStep(
      title: 'Help',
      message:
          'Use Help anytime to replay these speech bubbles and learn each action quickly.',
      icon: Icons.question_answer_rounded,
    ),
    _HelpStep(
      title: 'Product List',
      message:
          'Product List is where you can view and review all products currently in your inventory.',
      icon: Icons.inventory_2_outlined,
    ),
    _HelpStep(
      title: 'Batch List & History',
      message:
          'Batch List & History is where you can track stock batches and review movement history.',
      icon: Icons.history_outlined,
    ),
    _HelpStep(
      title: 'Activity Log',
      message:
          'Activity Log is where you can see recorded system activities and recent inventory actions.',
      icon: Icons.receipt_long_outlined,
    ),
  ];

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
    await showCategoryFormSheet(context, provider: widget.categoryProvider);
  }

  Future<void> _onAddBatch() async {
    setState(() => _actionsFabExpanded = false);
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateBatchPage(
          stockBatchProvider: widget.stockBatchProvider,
          productProvider: widget.productProvider,
          categoryProvider: widget.categoryProvider,
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

  Future<void> _onHelpInActionBar() async {
    if (!_actionsFabExpanded) {
      setState(() => _actionsFabExpanded = true);
    }

    await WidgetsBinding.instance.endOfFrame;

    final steps = [
      (_helpSteps[0], _mainActionsFabKey),
      (_helpSteps[1], _addProductFabKey),
      (_helpSteps[2], _addCategoryFabKey),
      (_helpSteps[3], _addBatchFabKey),
      (_helpSteps[4], _outingFlowFabKey),
      (_helpSteps[5], _manageCategoriesFabKey),
      (_helpSteps[6], _helpFabKey),
      (_helpSteps[7], _productsNavKey),
      (_helpSteps[8], _batchesNavKey),
      (_helpSteps[9], _activityNavKey),
    ];

    for (var index = 0; index < steps.length; index++) {
      final (step, key) = steps[index];
      if (!mounted) return;

      final targetRect = _targetRectForKey(key);
      if (targetRect == null) {
        continue;
      }

      final shouldContinue = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Help Tour',
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => _AnchoredHelpOverlay(
          step: step,
          targetRect: targetRect,
          currentStep: index + 1,
          totalSteps: steps.length,
        ),
      );

      if (shouldContinue != true) {
        break;
      }
    }
  }

  Rect? _targetRectForKey(GlobalKey key) {
    final currentContext = key.currentContext;
    if (currentContext == null) return null;

    final renderBox = currentContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final position = renderBox.localToGlobal(Offset.zero);
    return position & renderBox.size;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProductsPage(
        productProvider: widget.productProvider,
        categoryProvider: widget.categoryProvider,
        outingProvider: widget.outingProvider,
      ),
      BatchesPage(
        stockBatchProvider: widget.stockBatchProvider,
        productProvider: widget.productProvider,
      ),
      ActivityLogPage(activityLogProvider: widget.activityLogProvider),
      AnalyticsPage(
        productProvider: widget.productProvider,
        outingProvider: widget.outingProvider,
      ),
    ];

    final titles = ['Product List', 'Batch List & History', 'Activity Log', 'Analytics'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_currentIndex])),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _actionsFabExpanded = false;
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined, key: _productsNavKey),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined, key: _batchesNavKey),
            label: 'Batches',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined, key: _activityNavKey),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, key: _analyticsNavKey),
            label: 'Analytics',
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
              key: _addProductFabKey,
              heroTag: 'addProductFab',
              onPressed: _onAddProduct,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Add Product'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              key: _addCategoryFabKey,
              heroTag: 'addCategoryFab',
              onPressed: _onAddCategory,
              icon: const Icon(Icons.category_outlined),
              label: const Text('Add Category'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              key: _addBatchFabKey,
              heroTag: 'addBatchFab',
              onPressed: _onAddBatch,
              icon: const Icon(Icons.settings_backup_restore_outlined),
              label: const Text('Add Stock Batch'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              key: _outingFlowFabKey,
              heroTag: 'outingFlowFab',
              onPressed: _onStartOuting,
              icon: const Icon(Icons.format_list_numbered_rtl_outlined),
              label: const Text('Start Outing Flow'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              key: _manageCategoriesFabKey,
              heroTag: 'manageCategoriesFab',
              onPressed: _onManageCategories,
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('Manage Categories'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              key: _helpFabKey,
              heroTag: 'helpFab',
              onPressed: _onHelpInActionBar,
              icon: const Icon(Icons.question_answer_rounded),
              label: const Text('Help'),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton(
            key: _mainActionsFabKey,
            heroTag: 'mainActionsFab',
            onPressed: () =>
                setState(() => _actionsFabExpanded = !_actionsFabExpanded),
            child: Icon(_actionsFabExpanded ? Icons.close : Icons.add),
          ),
        ],
      ),
    );
  }
}

class _HelpStep {
  const _HelpStep({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;
}

class _AnchoredHelpOverlay extends StatelessWidget {
  const _AnchoredHelpOverlay({
    required this.step,
    required this.targetRect,
    required this.currentStep,
    required this.totalSteps,
  });

  final _HelpStep step;
  final Rect targetRect;
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    const bubbleWidth = 300.0;
    const spacing = 14.0;
    const sideMargin = 16.0;

    final canPlaceLeft = targetRect.left - bubbleWidth - spacing > sideMargin;
    final bubbleLeft = canPlaceLeft
        ? targetRect.left - bubbleWidth - spacing
        : (targetRect.right + spacing).clamp(
            sideMargin,
            screenSize.width - bubbleWidth - sideMargin,
          );

    final bubbleTop = (targetRect.center.dy - 90).clamp(
      sideMargin,
      screenSize.height - 190,
    );

    final arrowTop = (targetRect.center.dy - bubbleTop - 10).clamp(14.0, 150.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(false),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
          Positioned.fromRect(
            rect: targetRect.inflate(6),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Positioned(
            left: bubbleLeft,
            top: bubbleTop,
            width: bubbleWidth,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 14,
                        color: Colors.black26,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(step.icon, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step.title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(step.message),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '$currentStep of $totalSteps',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Close'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: arrowTop,
                  right: canPlaceLeft ? -12 : null,
                  left: canPlaceLeft ? null : -12,
                  child: Transform.rotate(
                    angle: canPlaceLeft ? 1.5708 : -1.5708,
                    child: CustomPaint(
                      size: const Size(22, 14),
                      painter: _BubbleTailPainter(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
