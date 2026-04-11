import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/app_user_profile.dart';
import 'package:jk_inventory_system/services/firebase_auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authService,
    this.rememberedUsername,
    this.showAppBar = true,
    this.onLoginSuccess,
  });

  final FirebaseAuthService authService;
  final String? rememberedUsername;
  final bool showAppBar;
  final Future<void> Function(AppUserProfile)? onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();

  bool _submitting = false;
  AppUserProfile? _signedInProfile;
  late bool _useRememberedAccount;

  String? get _resolvedRememberedUsername {
    final value = widget.rememberedUsername?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  bool get _isUsingRememberedAccount =>
      _useRememberedAccount && _resolvedRememberedUsername != null;

  String get _activeUsername => _isUsingRememberedAccount
      ? _resolvedRememberedUsername!
      : _usernameController.text;

  @override
  void initState() {
    super.initState();
    _useRememberedAccount = _resolvedRememberedUsername != null;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final profile = await widget.authService.signInWithUsernamePin(
        username: _activeUsername,
        pin: _pinController.text,
      );
      if (!mounted) return;
      setState(() {
        _signedInProfile = profile;
      });
      if (widget.onLoginSuccess != null) {
        await widget.onLoginSuccess!(profile);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Signed in as ${profile.username} (${profile.role.label}).',
          ),
        ),
      );
    } on AuthFlowException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String? _validatePin(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.length != 6 || int.tryParse(trimmed) == null) {
      return 'Enter exactly 6 digits.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(title: const Text('Login')) : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isUsingRememberedAccount)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Continue as $_resolvedRememberedUsername',
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _useRememberedAccount = false;
                              });
                            },
                            child: const Text('Switch'),
                          ),
                        ],
                      ),
                    )
                  else
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Username is required.';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '6-digit PIN',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: _validatePin,
                  ),
                  if (!_isUsingRememberedAccount &&
                      _resolvedRememberedUsername != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _useRememberedAccount = true;
                          });
                        },
                        child: const Text('Use remembered account instead'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Login'),
                  ),
                  const SizedBox(height: 12),
                  if (_signedInProfile != null)
                    Text(
                      'Current role: ${_signedInProfile!.role.label}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
