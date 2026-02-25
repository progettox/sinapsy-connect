import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Email obbligatoria';
    if (!email.contains('@')) return 'Inserisci una email valida';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password obbligatoria';
    if (password.length < 6) return 'Minimo 6 caratteri';
    return null;
  }

  Future<void> _runAuth(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Errore: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _oauthRedirectTo() {
    if (kIsWeb) return null;

    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isMobile) {
      // TODO: Configurare deep link/app link Android+iOS per io.supabase.flutter://login-callback.
      return 'io.supabase.flutter://login-callback';
    }

    return null;
  }

  Future<void> _signInWithGoogle() async {
    await _runAuth(() async {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _oauthRedirectTo(),
      );
    });
  }

  Future<void> _signInWithApple() async {
    await _runAuth(() async {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: _oauthRedirectTo(),
      );
    });
  }

  Future<void> _signInWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _runAuth(() async {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    });
  }

  Future<void> _signUpWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _runAuth(() async {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      _showSnack('Sign up completato. Controlla la tua email se richiesta.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Authentication')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Accedi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: const Icon(Icons.g_mobiledata),
                      label: const Text('Google'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signInWithApple,
                      icon: const Icon(Icons.apple),
                      label: const Text('Apple'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _emailFocusNode.requestFocus(),
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('Email'),
                    ),
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithEmail,
                      child: const Text('Login'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _isLoading ? null : _signUpWithEmail,
                      child: const Text('Sign up'),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
