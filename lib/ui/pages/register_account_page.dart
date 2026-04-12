import 'package:flutter/material.dart';
import 'package:jk_inventory_system/models/app_user_profile.dart';
import 'package:jk_inventory_system/services/firebase_auth_service.dart';
import 'package:jk_inventory_system/ui/widgets/app_loading.dart';

class RegisterAccountPage extends StatefulWidget {
  const RegisterAccountPage({super.key, required this.authService});

  final FirebaseAuthService authService;

  @override
  State<RegisterAccountPage> createState() => _RegisterAccountPageState();
}

class _RegisterAccountPageState extends State<RegisterAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  AppRole _selectedRole = AppRole.view;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
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
      final profile = await AppLoading.run<AppUserProfile>(
        context,
        action: () => widget.authService.registerAccount(
          username: _usernameController.text,
          pin: _pinController.text,
          role: _selectedRole,
        ),
        message: 'Creating account...',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${profile.username} as ${profile.role.label}.',
          ),
        ),
      );
      _usernameController.clear();
      _pinController.clear();
      _confirmPinController.clear();
      setState(() {
        _selectedRole = AppRole.view;
      });
    } on AuthFlowException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create account.')),
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
      appBar: AppBar(title: const Text('Register Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Admin-only enforcement will be added later.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
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
                      if ((value ?? '').trim().length < 3) {
                        return 'Use at least 3 characters.';
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (_validatePin(value) != null) {
                        return 'Enter exactly 6 digits.';
                      }
                      if ((value ?? '').trim() != _pinController.text.trim()) {
                        return 'PIN does not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AppRole>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: AppRole.values
                        .map(
                          (role) => DropdownMenuItem<AppRole>(
                            value: role,
                            child: Text(role.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedRole = value;
                      });
                    },
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
                        : const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Create Account'),
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
