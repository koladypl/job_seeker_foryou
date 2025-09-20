import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_service.dart';
import '../validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _loading = false;
  bool _hidePass = true;

  @override
  void dispose() {
    _userCtl.dispose();
    _passCtl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<ApiService>().login(
            _userCtl.text.trim(),
            _passCtl.text,
          );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/jobs');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _asGuest() {
    Navigator.pushReplacementNamed(context, '/jobs');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.work_outline, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Zaloguj się',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _userCtl,
                      focusNode: _userFocus,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Login',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: validateUsername,
                      onFieldSubmitted: (_) => _passFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtl,
                      focusNode: _passFocus,
                      obscureText: _hidePass,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Hasło',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_hidePass ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _hidePass = !_hidePass),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: validatePassword,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        label: _loading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Zaloguj'),
                        onPressed: _loading ? null : _submit,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading ? null : () => Navigator.pushReplacementNamed(context, '/register'),
                      child: const Text('Rejestracja'),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _asGuest,
                      child: const Text('Kontynuuj jako gość'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
