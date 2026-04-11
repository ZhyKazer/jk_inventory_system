import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:jk_inventory_system/firebase_options.dart';
import 'package:jk_inventory_system/models/app_user_profile.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/stock_batch_provider.dart';
import 'package:jk_inventory_system/services/auth_session_service.dart';
import 'package:jk_inventory_system/services/apk_update_service.dart';
import 'package:jk_inventory_system/services/firebase_auth_service.dart';
import 'package:jk_inventory_system/services/firebase_sync_service.dart';
import 'package:jk_inventory_system/services/inventory_storage.dart';
import 'package:jk_inventory_system/services/startup_policy_service.dart';
import 'package:jk_inventory_system/ui/pages/home_shell.dart';
import 'package:jk_inventory_system/ui/pages/login_page.dart';
import 'package:jk_inventory_system/ui/theme/app_theme_option.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _configureFirebaseTargets();
  await InventoryStorage.initialize();
  runApp(const InventoryApp());
}

const bool _useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);
const bool _disableLoginGate = bool.fromEnvironment(
  'DISABLE_LOGIN_GATE',
  defaultValue: false,
);
const String _firebaseEmulatorHostOverride = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '',
);

void _configureFirebaseTargets() {
  if (!_useFirebaseEmulators) {
    return;
  }

  final emulatorHost = _firebaseEmulatorHostOverride.trim().isNotEmpty
      ? _firebaseEmulatorHostOverride.trim()
      : (Platform.isAndroid ? '10.0.2.2' : '127.0.0.1');

  FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8085);
  FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
}

class InventoryApp extends StatefulWidget {
  const InventoryApp({super.key});

  @override
  State<InventoryApp> createState() => _InventoryAppState();
}

class _InventoryAppState extends State<InventoryApp> {
  late final ActivityLogProvider _activityLogProvider;
  late final CategoryProvider _categoryProvider;
  late final ProductProvider _productProvider;
  late final StockBatchProvider _stockBatchProvider;
  late final OutingProvider _outingProvider;
  AppThemeOption _selectedTheme = AppThemeOption.dark;
  Color _customThemeColor = Colors.deepPurple;
  final FirebaseAuthService _firebaseAuthService = FirebaseAuthService();
  final AuthSessionService _authSessionService = AuthSessionService();
  final FirebaseSyncService _firebaseSyncService = FirebaseSyncService();
  final StartupPolicyService _startupPolicyService = StartupPolicyService();
  final ApkUpdateService _apkUpdateService = ApkUpdateService();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  String? _rememberedUsername;
  AppRole? _currentRole;
  bool _authReady = false;
  bool _dataReady = false;
  bool _isLoggedIn = false;
  String? _startupError;
  StartupPolicyResult? _startupPolicyResult;
  bool _isUpdatingApk = false;
  String? _updateStatusMessage;

  void _showSnackMessage(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();

    final repo = InventoryStorage.localRepo();

    _activityLogProvider = ActivityLogProvider(repo.activityLogs);
    _categoryProvider = CategoryProvider(repo.categories, _activityLogProvider);
    _productProvider = ProductProvider(repo.products, _activityLogProvider);
    _stockBatchProvider = StockBatchProvider(
      repo.stockBatches,
      _activityLogProvider,
    );
    _outingProvider = OutingProvider(
      repo.outings,
      () => _stockBatchProvider.items,
      () => _productProvider.items,
      _activityLogProvider,
    );

    _bootstrapAppState();
  }

  Future<void> _bootstrapAppState() async {
    if (!mounted) return;
    setState(() {
      _startupError = null;
      _startupPolicyResult = null;
      _dataReady = false;
      _authReady = false;
    });

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final startupPolicy = await _startupPolicyService.check(
        currentVersion: packageInfo.version,
      );

      if (startupPolicy.blockType != StartupBlockType.none) {
        if (!mounted) return;
        setState(() {
          _startupPolicyResult = startupPolicy;
        });
        return;
      }

      await _firebaseSyncService.replaceLocalWithFirestore();
      await _loadInitialData();
      await _initializeAuthGate();

      if (!mounted) return;
      setState(() {
        _dataReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _startupError =
            'Unable to load online data from Firebase. Please check your internet or Firebase setup and retry.';
      });
    }
  }

  Future<void> _openUpdateLink(String? url) async {
    final normalized = (url ?? '').trim();
    if (normalized.isEmpty || !mounted) {
      return;
    }

    if (Platform.isAndroid) {
      setState(() {
        _isUpdatingApk = true;
        _updateStatusMessage = 'Preparing update...';
      });

      try {
        await _apkUpdateService.downloadAndInstallApk(
          downloadUrl: normalized,
          onProgress: (message) {
            if (!mounted) return;
            setState(() {
              _updateStatusMessage = message;
            });
          },
        );
      } on ApkUpdateException catch (error) {
        if (!mounted) return;
        _showSnackMessage(error.message);
      } catch (_) {
        if (!mounted) return;
        _showSnackMessage('Unable to install update in-app.');
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingApk = false;
            _updateStatusMessage = null;
          });
        }
      }
      return;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      _showSnackMessage('Update link is invalid.');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showSnackMessage('Unable to open update link.');
      }
    } catch (_) {
      if (!mounted) return;
      _showSnackMessage('Unable to open update link.');
    }
  }

  String _policyTitle(StartupBlockType blockType) {
    return switch (blockType) {
      StartupBlockType.maintenance => 'System Maintenance',
      StartupBlockType.offline => 'System Offline',
      StartupBlockType.forceUpdate => 'Update Required',
      StartupBlockType.none => 'Startup',
    };
  }

  String _policyMessage(StartupPolicyResult policy) {
    return switch (policy.blockType) {
      StartupBlockType.maintenance =>
        'The system is currently under maintenance. Please try again later.',
      StartupBlockType.offline =>
        'The system is currently offline. Please wait until it is online again.',
      StartupBlockType.forceUpdate =>
        'A new version is required to continue. Current: ${policy.currentVersion} • Required: ${policy.remoteVersion}.',
      StartupBlockType.none => '',
    };
  }

  Future<void> _initializeAuthGate() async {
    if (_disableLoginGate) {
      if (!mounted) return;
      setState(() {
        _rememberedUsername = 'dev-admin';
        _authReady = true;
        _isLoggedIn = true;
        _currentRole = AppRole.admin;
      });
      return;
    }

    _rememberedUsername = _authSessionService.getRememberedUsername();
    await _firebaseAuthService.signOut();
    if (!mounted) return;
    setState(() {
      _authReady = true;
      _isLoggedIn = false;
      _currentRole = null;
    });
  }

  Future<void> _onLoginSuccess() async {
    final username = _rememberedUsername;
    if (username != null && username.trim().isNotEmpty) {
      await _authSessionService.saveRememberedUsername(username);
    }
    if (!mounted) return;
    setState(() {
      _isLoggedIn = true;
    });
  }

  Future<void> _onLogout() async {
    await _firebaseAuthService.signOut();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
      _currentRole = null;
    });
  }

  Future<void> _loadInitialData() async {
    await _activityLogProvider.load();
    await _categoryProvider.load();
    await _productProvider.load();
    await _stockBatchProvider.load();
    await _productProvider.restorePricesFromBatches(_stockBatchProvider.items);
    await _outingProvider.load();
  }

  void _setTheme(AppThemeOption theme) {
    setState(() {
      _selectedTheme = theme;
    });
  }

  void _setCustomThemeColor(Color color) {
    setState(() {
      _customThemeColor = color;
      _selectedTheme = AppThemeOption.custom;
    });
  }

  ThemeData _buildThemeData({
    required Color seedColor,
    required Brightness brightness,
  }) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 220),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 220),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 220),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 220),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  ThemeData _themeFromSelection() {
    return switch (_selectedTheme) {
      AppThemeOption.light => _buildThemeData(
        seedColor: Colors.indigo,
        brightness: Brightness.light,
      ),
      AppThemeOption.dark => _buildThemeData(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      AppThemeOption.blue => _buildThemeData(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      AppThemeOption.green => _buildThemeData(
        seedColor: Colors.green,
        brightness: Brightness.light,
      ),
      AppThemeOption.custom => _buildThemeData(
        seedColor: _customThemeColor,
        brightness: Brightness.light,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final startupPolicy = _startupPolicyResult;
    if (startupPolicy != null &&
        startupPolicy.blockType != StartupBlockType.none) {
      final hasUpdateAction =
          startupPolicy.blockType == StartupBlockType.forceUpdate;
      final colorScheme = _themeFromSelection().colorScheme;
      final iconColor = hasUpdateAction
          ? colorScheme.primary
          : colorScheme.error;
      return MaterialApp(
        title: 'bnm',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        theme: _themeFromSelection(),
        home: Scaffold(
          backgroundColor: colorScheme.surface,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasUpdateAction
                            ? Icons.system_update_alt_outlined
                            : Icons.pause_circle_outline,
                        size: 56,
                        color: iconColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _policyTitle(startupPolicy.blockType),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _policyMessage(startupPolicy),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (hasUpdateAction)
                        FilledButton.icon(
                          onPressed: _isUpdatingApk
                              ? null
                              : () => _openUpdateLink(startupPolicy.updateUrl),
                          icon: _isUpdatingApk
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_outlined),
                          label: Text(
                            _isUpdatingApk ? 'Downloading...' : 'Update Now',
                          ),
                        ),
                      if (hasUpdateAction) const SizedBox(height: 10),
                      if (hasUpdateAction &&
                          (_updateStatusMessage ?? '').trim().isNotEmpty)
                        Text(
                          _updateStatusMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      if (hasUpdateAction &&
                          (_updateStatusMessage ?? '').trim().isNotEmpty)
                        const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _bootstrapAppState,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Check Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_startupError != null) {
      final colorScheme = _themeFromSelection().colorScheme;
      return MaterialApp(
        title: 'bnm',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        theme: _themeFromSelection(),
        home: Scaffold(
          backgroundColor: colorScheme.surface,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 56,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Online Sync Required',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _startupError!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _bootstrapAppState,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!_dataReady || !_authReady) {
      return MaterialApp(
        title: 'bnm',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        theme: _themeFromSelection(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (!_isLoggedIn) {
      return MaterialApp(
        title: 'bnm',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        theme: _themeFromSelection(),
        home: LoginPage(
          authService: _firebaseAuthService,
          rememberedUsername: _rememberedUsername,
          showAppBar: false,
          onLoginSuccess: (profile) async {
            _rememberedUsername = profile.username;
            _currentRole = profile.role;
            await _onLoginSuccess();
          },
        ),
      );
    }

    return MaterialApp(
      title: 'bnm',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: _themeFromSelection(),
      home: HomeShell(
        categoryProvider: _categoryProvider,
        productProvider: _productProvider,
        stockBatchProvider: _stockBatchProvider,
        outingProvider: _outingProvider,
        activityLogProvider: _activityLogProvider,
        selectedTheme: _selectedTheme,
        onThemeSelected: _setTheme,
        selectedCustomThemeColor: _customThemeColor,
        onCustomThemeColorSelected: _setCustomThemeColor,
        rememberedUsername: _rememberedUsername,
        currentRole: _currentRole ?? AppRole.view,
        onLoggedOut: _onLogout,
      ),
    );
  }
}
