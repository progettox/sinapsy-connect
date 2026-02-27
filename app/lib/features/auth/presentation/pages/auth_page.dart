import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../domain/models/auth_user_model.dart';
import '../controllers/auth_controller.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();

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

  Future<void> _signInWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted || !ok) return;
    context.go(AppRouter.splashPath);
  }

  Future<void> _signUpWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref
        .read(authControllerProvider.notifier)
        .signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted || !ok) return;
    _showSnack(
      'Registrazione completata. Controlla la tua email se richiesto.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen<AuthUiState>(authControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    ref.listen<AsyncValue<AuthUserModel?>>(authChangesProvider, (
      previous,
      next,
    ) {
      next.whenData((user) {
        if (user == null || !mounted) return;
        context.go(AppRouter.splashPath);
      });
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LuxuryNeonBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 1080 : 460,
                      ),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Expanded(
                                  flex: 11,
                                  child: _HeroLogoBlock(),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 9,
                                  child: _AuthCard(
                                    formKey: _formKey,
                                    emailController: _emailController,
                                    passwordController: _passwordController,
                                    emailFocusNode: _emailFocusNode,
                                    isLoading: state.isLoading,
                                    onSignIn: _signInWithEmail,
                                    onSignUp: _signUpWithEmail,
                                    validateEmail: _validateEmail,
                                    validatePassword: _validatePassword,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                const _HeroLogoBlock(compact: true),
                                const SizedBox(height: 18),
                                _AuthCard(
                                  formKey: _formKey,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  emailFocusNode: _emailFocusNode,
                                  isLoading: state.isLoading,
                                  onSignIn: _signInWithEmail,
                                  onSignUp: _signUpWithEmail,
                                  validateEmail: _validateEmail,
                                  validatePassword: _validatePassword,
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLogoBlock extends StatelessWidget {
  const _HeroLogoBlock({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textSize = compact ? 12.0 : 14.0;
    final logoSize = compact ? 108.0 : 148.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SinapsyAnimatedLogo(size: logoSize),
          SizedBox(height: compact ? 8 : 10),
          Text(
            'Benvenuti su Sinapsy Connect',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
              color: const Color(0xFFE7EFFF).withValues(alpha: 0.86),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.emailFocusNode,
    required this.isLoading,
    required this.onSignIn,
    required this.onSignUp,
    required this.validateEmail,
    required this.validatePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocusNode;
  final bool isLoading;
  final Future<void> Function() onSignIn;
  final Future<void> Function() onSignUp;
  final String? Function(String?) validateEmail;
  final String? Function(String?) validatePassword;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE0101927),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x9A02050C),
            blurRadius: 26,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Accedi con email',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                focusNode: emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: validatePassword,
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: isLoading ? null : onSignIn,
                child: isLoading
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SinapsyLogoLoader(size: 18),
                          SizedBox(width: 8),
                          Text('Accesso...'),
                        ],
                      )
                    : const Text('Login'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: isLoading ? null : onSignUp,
                child: const Text('Sign up'),
              ),
              if (isLoading) ...[
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SinapsyLogoLoader(size: 22),
                    SizedBox(width: 8),
                    Text('Sincronizzazione in corso'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
