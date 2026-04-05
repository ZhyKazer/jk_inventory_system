import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/stock_batch_provider.dart';
import 'package:jk_inventory_system/services/backup_service.dart';
import 'package:jk_inventory_system/ui/pages/activity_log_page.dart';
import 'package:jk_inventory_system/ui/pages/analytics_page.dart';
import 'package:jk_inventory_system/ui/pages/batches_page.dart';
import 'package:jk_inventory_system/ui/pages/categories_page.dart';
import 'package:jk_inventory_system/ui/pages/create_batch_page.dart';
import 'package:jk_inventory_system/ui/pages/outing_stepper_page.dart';
import 'package:jk_inventory_system/ui/pages/products_page.dart';
import 'package:jk_inventory_system/ui/theme/app_theme_option.dart';
import 'package:jk_inventory_system/ui/widgets/app_loading.dart';
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
    required this.selectedTheme,
    required this.onThemeSelected,
    required this.selectedCustomThemeColor,
    required this.onCustomThemeColorSelected,
  });

  final ActivityLogProvider activityLogProvider;
  final CategoryProvider categoryProvider;
  final ProductProvider productProvider;
  final StockBatchProvider stockBatchProvider;
  final OutingProvider outingProvider;
  final AppThemeOption selectedTheme;
  final ValueChanged<AppThemeOption> onThemeSelected;
  final Color selectedCustomThemeColor;
  final ValueChanged<Color> onCustomThemeColorSelected;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  bool _actionsFabExpanded = false;
  final BackupService _backupService = BackupService();

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
          categoryProvider: widget.categoryProvider,
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
        pageBuilder: (dialogContext, animation, secondaryAnimation) =>
            _AnchoredHelpOverlay(
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

  Future<void> _showLoadingWhile(
    Future<void> Function() action, {
    required String message,
    ValueListenable<String>? messageListenable,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
  }) async {
    await AppLoading.run<void>(
      context,
      action: action,
      message: message,
      messageListenable: messageListenable,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryAction: onSecondaryAction,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reloadAllProviders() async {
    await widget.activityLogProvider.load();
    await widget.categoryProvider.load();
    await widget.productProvider.load();
    await widget.stockBatchProvider.load();
    await widget.outingProvider.load();
  }

  Future<bool> _confirmRestore({required String sourceLabel}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Text(
          'This will overwrite current data with "$sourceLabel". Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _showBackupConfirmation(
    BackupCreateResult result,
    String retentionMessage,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Backup Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${result.fileName}'),
            Text('Size: ${_formatFileSize(result.fileSizeBytes)}'),
            Text('Products: ${result.productCount}'),
            Text('Images: ${result.imageCount}'),
            Text(
              'Created: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(result.createdAt)}',
            ),
            if (retentionMessage.isNotEmpty) Text(retentionMessage),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _onBackupData() async {
    final progressMessage = ValueNotifier<String>('saving json information');
    final cancelValidation = ValueNotifier<bool>(false);
    try {
      late BackupCreateResult result;
      await _showLoadingWhile(
        () async {
          result = await _backupService.createBackup(
            validateAfterSave: true,
            shouldContinueValidation: () => !cancelValidation.value,
            onProgress: (statusMessage) {
              if (!mounted) return;
              progressMessage.value = statusMessage;
            },
          );
        },
        message: 'Creating backup...',
        messageListenable: progressMessage,
        secondaryActionLabel: 'Cancel validation',
        onSecondaryAction: () {
          cancelValidation.value = true;
        },
      );

      final removed = result.deletedFiles.length;
      final retentionMessage = removed > 0
          ? ' Removed $removed old backup(s).'
          : '';
      await _showBackupConfirmation(result, retentionMessage);
    } catch (_) {
      _showMessage('Failed to create backup. Please try again.');
    } finally {
      progressMessage.dispose();
      cancelValidation.dispose();
    }
  }

  Future<void> _onRestoreData() async {
    try {
      final backups = await _backupService.listRecentBackups(limit: 5);

      if (!mounted) return;

      if (backups.isEmpty) {
        _showMessage(
          'No recent backups found. Use Backup Data or Import Backup.',
        );
        return;
      }

      final selected = await showDialog<BackupFileInfo>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Restore Data'),
          content: SizedBox(
            width: 460,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: backups.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final backup = backups[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(backup.fileName),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy HH:mm:ss').format(backup.createdAt),
                  ),
                  onTap: () => Navigator.of(context).pop(backup),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selected == null) {
        return;
      }

      final confirmed = await _confirmRestore(sourceLabel: selected.fileName);
      if (!confirmed) {
        return;
      }

      await _showLoadingWhile(() async {
        await _backupService.restoreFromQuickBackup(selected.path);
        await _reloadAllProviders();
      }, message: 'Restoring backup...');

      _showMessage('Restore completed from ${selected.fileName}.');
    } on BackupException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Failed to restore backup. Please try again.');
    }
  }

  Future<void> _onImportBackup() async {
    try {
      final selectedPath = await _backupService.pickBackupFileForImport();
      if (selectedPath == null) {
        return;
      }

      final fileName = selectedPath.split(RegExp(r'[\\/]')).last;
      final confirmed = await _confirmRestore(sourceLabel: fileName);
      if (!confirmed) {
        return;
      }

      await _showLoadingWhile(() async {
        await _backupService.restoreFromAnyFilePath(selectedPath);
        await _reloadAllProviders();
      }, message: 'Importing and restoring backup...');

      _showMessage('Imported and restored from $fileName.');
    } on BackupException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Failed to import backup. Please try again.');
    }
  }

  Future<void> _onChangeBackupDirectory() async {
    try {
      final selectedPath = await _backupService.pickAndSaveBackupDirectory();
      if (selectedPath == null) {
        _showMessage('Backup folder change cancelled.');
        return;
      }

      _showMessage('Backup folder updated successfully.');
    } on BackupException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Failed to change backup folder. Please try again.');
    }
  }

  Widget _buildAnimatedActionButton({
    required int index,
    required Widget child,
  }) {
    final duration = Duration(milliseconds: 300 + (index * 35));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedSlide(
        duration: duration,
        curve: Curves.easeOutCubic,
        offset: _actionsFabExpanded ? Offset.zero : const Offset(0, 0.2),
        child: AnimatedOpacity(
          duration: duration,
          curve: Curves.easeOutCubic,
          opacity: _actionsFabExpanded ? 1 : 0,
          child: child,
        ),
      ),
    );
  }

  Widget _buildExpandableActionButtons() {
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: _actionsFabExpanded
              ? const BoxConstraints()
              : const BoxConstraints(maxHeight: 0),
          child: IgnorePointer(
            ignoring: !_actionsFabExpanded,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildAnimatedActionButton(
                  index: 0,
                  child: FloatingActionButton.extended(
                    key: _addProductFabKey,
                    heroTag: 'addProductFab',
                    onPressed: _onAddProduct,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Add Product'),
                  ),
                ),
                _buildAnimatedActionButton(
                  index: 1,
                  child: FloatingActionButton.extended(
                    key: _addCategoryFabKey,
                    heroTag: 'addCategoryFab',
                    onPressed: _onAddCategory,
                    icon: const Icon(Icons.category_outlined),
                    label: const Text('Add Category'),
                  ),
                ),
                _buildAnimatedActionButton(
                  index: 2,
                  child: FloatingActionButton.extended(
                    key: _addBatchFabKey,
                    heroTag: 'addBatchFab',
                    onPressed: _onAddBatch,
                    icon: const Icon(Icons.settings_backup_restore_outlined),
                    label: const Text('Add Stock Batch'),
                  ),
                ),
                _buildAnimatedActionButton(
                  index: 3,
                  child: FloatingActionButton.extended(
                    key: _outingFlowFabKey,
                    heroTag: 'outingFlowFab',
                    onPressed: _onStartOuting,
                    icon: const Icon(Icons.format_list_numbered_rtl_outlined),
                    label: const Text('Start Outing Flow'),
                  ),
                ),
                _buildAnimatedActionButton(
                  index: 4,
                  child: FloatingActionButton.extended(
                    key: _manageCategoriesFabKey,
                    heroTag: 'manageCategoriesFab',
                    onPressed: _onManageCategories,
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Manage Categories'),
                  ),
                ),
                _buildAnimatedActionButton(
                  index: 5,
                  child: FloatingActionButton.extended(
                    key: _helpFabKey,
                    heroTag: 'helpFab',
                    onPressed: _onHelpInActionBar,
                    icon: const Icon(Icons.question_answer_rounded),
                    label: const Text('Help'),
                  ),
                ),
              ],
            ),
          ),
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

    final titles = [
      'Product List',
      'Batch List & History',
      'Activity Log',
      'Analytics',
    ];

    String themeLabel(AppThemeOption option) {
      return switch (option) {
        AppThemeOption.dark => 'Dark',
        AppThemeOption.light => 'Light',
        AppThemeOption.blue => 'Blue',
        AppThemeOption.green => 'Green',
        AppThemeOption.custom => 'Custom',
      };
    }

    const customThemePalette = <Color>[
      Colors.deepPurple,
      Colors.pink,
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.teal,
      Colors.cyan,
      Colors.indigo,
      Colors.brown,
      Colors.grey,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: _onManageCategories,
            tooltip: 'Categories',
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: 'Settings',
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ListTile(
                title: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<AppThemeOption>(
                  value: widget.selectedTheme,
                  decoration: const InputDecoration(
                    labelText: 'Theme',
                    border: OutlineInputBorder(),
                  ),
                  items: AppThemeOption.values
                      .map(
                        (option) => DropdownMenuItem<AppThemeOption>(
                          value: option,
                          child: Text(themeLabel(option)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    widget.onThemeSelected(value);
                  },
                ),
              ),
              if (widget.selectedTheme == AppThemeOption.custom)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Color',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: customThemePalette.map((color) {
                          final isSelected =
                              widget.selectedCustomThemeColor.value ==
                              color.value;
                          return InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () =>
                                widget.onCustomThemeColorSelected(color),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 16,
                                      color:
                                          ThemeData.estimateBrightnessForColor(
                                                color,
                                              ) ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Backup Data'),
                subtitle: const Text(
                  'Create a JSON backup in your selected folder.',
                ),
                onTap: _onBackupData,
              ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Change Backup Folder'),
                subtitle: const Text(
                  'Pick a different folder for backup files.',
                ),
                onTap: _onChangeBackupDirectory,
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore_outlined),
                title: const Text('Restore Data'),
                subtitle: const Text('Restore from the 5 most recent backups.'),
                onTap: _onRestoreData,
              ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Import Backup'),
                subtitle: const Text(
                  'Import and restore from any JSON backup file.',
                ),
                onTap: _onImportBackup,
              ),
            ],
          ),
        ),
      ),
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
          _buildExpandableActionButtons(),
          FloatingActionButton(
            key: _mainActionsFabKey,
            heroTag: 'mainActionsFab',
            onPressed: () =>
                setState(() => _actionsFabExpanded = !_actionsFabExpanded),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: _actionsFabExpanded ? 1.08 : 1.0,
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                turns: _actionsFabExpanded ? 0.125 : 0,
                child: const Icon(Icons.add),
              ),
            ),
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
