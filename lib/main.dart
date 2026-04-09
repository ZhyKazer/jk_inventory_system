import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:jk_inventory_system/firebase_options.dart';
import 'package:jk_inventory_system/models/app_user_profile.dart';
import 'package:jk_inventory_system/providers/activity_log_provider.dart';
import 'package:jk_inventory_system/providers/category_provider.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';
import 'package:jk_inventory_system/providers/stock_batch_provider.dart';
import 'package:jk_inventory_system/services/auth_session_service.dart';
import 'package:jk_inventory_system/services/firebase_auth_service.dart';
import 'package:jk_inventory_system/services/firebase_sync_service.dart';
import 'package:jk_inventory_system/services/inventory_storage.dart';
import 'package:jk_inventory_system/ui/pages/home_shell.dart';
import 'package:jk_inventory_system/ui/pages/login_page.dart';
import 'package:jk_inventory_system/ui/theme/app_theme_option.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await InventoryStorage.initialize();
  runApp(const InventoryApp());
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
  String? _rememberedUsername;
  AppRole? _currentRole;
  bool _authReady = false;
  bool _dataReady = false;
  bool _isLoggedIn = false;
  String? _startupError;

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
      _dataReady = false;
      _authReady = false;
    });

    try {
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

  Future<void> _initializeAuthGate() async {
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
    if (_startupError != null) {
      return MaterialApp(
        title: 'bnm',
        debugShowCheckedModeBanner: false,
        theme: _themeFromSelection(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Online Sync Required',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(_startupError!, textAlign: TextAlign.center),
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
      );
    }

    if (!_dataReady || !_authReady) {
      return MaterialApp(
        title: 'bnm',
        debugShowCheckedModeBanner: false,
        theme: _themeFromSelection(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (!_isLoggedIn) {
      return MaterialApp(
        title: 'bnm',
        debugShowCheckedModeBanner: false,
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
