import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../data/auth_repository.dart';
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
  final _introController = PageController();

  final bool _showWelcome = true;
  bool _showOnboarding = true;
  int _introIndex = 0;
  bool _showInlineEmailStep = false;
  bool _showInlinePasswordStep = false;

  static const List<_IntroSlide> _slides = <_IntroSlide>[
    _IntroSlide(
      title: 'Trova le opportunita perfette',
      description:
          'Swipe tra campagne esclusive di brand verificati. Match immediato con i progetti giusti per te.',
      icon: Icons.auto_awesome_outlined,
    ),
    _IntroSlide(
      title: 'Pagamenti protetti',
      description:
          'Sistema escrow integrato. I tuoi fondi sono sempre al sicuro fino alla consegna approvata.',
      icon: Icons.shield_outlined,
    ),
    _IntroSlide(
      title: 'Workflow professionale',
      description:
          'Chat, delivery, revisioni e approvazioni. Tutto in un unico spazio di lavoro.',
      icon: Icons.bolt_rounded,
    ),
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _introController.dispose();
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

  void _openEmailAuth() {
    setState(() {
      _showInlineEmailStep = true;
      _showInlinePasswordStep = false;
    });
    _passwordController.clear();
  }

  Future<void> _continueInlineEmail() async {
    final error = _validateEmail(_emailController.text);
    if (error != null) {
      _showSnack(error);
      return;
    }

    if (!_showInlinePasswordStep) {
      setState(() => _showInlinePasswordStep = true);
      return;
    }

    final passwordError = _validatePassword(_passwordController.text);
    if (passwordError != null) {
      _showSnack(passwordError);
      return;
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (ok) {
      context.go(AppRouter.splashPath);
      return;
    }

    // Fallback robusto: se il login fallisce, proviamo registrazione.
    final signedUp = await ref
        .read(authControllerProvider.notifier)
        .signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted || !signedUp) return;

    // Alcune configurazioni Supabase non ritornano subito sessione su signUp.
    // In quel caso tentiamo un login immediato per portare il nuovo utente
    // al flusso ruolo/profilo senza rimanere bloccati sulla welcome.
    var hasSession = ref.read(authRepositoryProvider).currentSession != null;
    if (!hasSession) {
      final signedInAfterSignUp = await ref
          .read(authControllerProvider.notifier)
          .signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      if (signedInAfterSignUp) {
        hasSession = ref.read(authRepositoryProvider).currentSession != null;
      }
    }

    if (!mounted) return;
    if (hasSession) {
      context.go(AppRouter.completeProfilePath);
      return;
    }

    _showSnack(
      'Account creato. Verifica la mail e poi accedi per completare il profilo.',
    );
    context.go(AppRouter.splashPath);
  }

  void _socialNotAvailable(String provider) {
    _showSnack('$provider non disponibile al momento');
  }

  void _skipIntro() {
    setState(() => _showOnboarding = false);
  }

  Future<void> _goNextIntroStep() async {
    final isLast = _introIndex == _slides.length - 1;
    if (isLast) {
      _skipIntro();
      return;
    }
    await _introController.animateToPage(
      _introIndex + 1,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
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

    if (_showOnboarding) {
      return _AuthOnboardingIntro(
        controller: _introController,
        slides: _slides,
        currentIndex: _introIndex,
        onIndexChanged: (index) => setState(() => _introIndex = index),
        onSkip: _skipIntro,
        onPrimaryTap: _goNextIntroStep,
      );
    }

    if (_showWelcome) {
      return _AuthWelcomeIntro(
        showInlineEmailStep: _showInlineEmailStep,
        showInlinePasswordStep: _showInlinePasswordStep,
        emailController: _emailController,
        passwordController: _passwordController,
        onAppleTap: () => _socialNotAvailable('Accesso Apple'),
        onGoogleTap: () => _socialNotAvailable('Accesso Google'),
        onEmailTap: _openEmailAuth,
        onContinueEmailTap: () {
          _continueInlineEmail();
        },
      );
    }

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _OnboardingTopHeader(),
                          SizedBox(height: isWide ? 24 : 18),
                          isWide
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

class _IntroSlide {
  const _IntroSlide({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class _AuthOnboardingIntro extends StatelessWidget {
  const _AuthOnboardingIntro({
    required this.controller,
    required this.slides,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.onSkip,
    required this.onPrimaryTap,
  });

  final PageController controller;
  final List<_IntroSlide> slides;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onSkip;
  final VoidCallback onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    final isLast = currentIndex == slides.length - 1;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LuxuryNeonBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.colorTextSecondary,
                        textStyle: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Salta'),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: controller,
                      itemCount: slides.length,
                      onPageChanged: onIndexChanged,
                      itemBuilder: (context, index) {
                        final slide = slides[index];
                        return _IntroSlideBody(slide: slide);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(slides.length, (index) {
                      final active = index == currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 7,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? AppTheme.colorAccentPrimary
                              : AppTheme.colorStrokeMedium.withValues(
                                  alpha: 0.9,
                                ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFF9B4EFF), Color(0xFF9E53EA)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66281A4A),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: onPrimaryTap,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'Inizia' : 'Avanti',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 22,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroSlideBody extends StatelessWidget {
  const _IntroSlideBody({required this.slide});

  final _IntroSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 92),
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(1.4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFA855F7), Color(0xFF06B6D4)],
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF080A11),
              ),
              alignment: Alignment.center,
              child: Icon(
                slide.icon,
                size: 34,
                color: AppTheme.colorAccentPrimary,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.colorTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthWelcomeIntro extends StatelessWidget {
  const _AuthWelcomeIntro({
    required this.showInlineEmailStep,
    required this.showInlinePasswordStep,
    required this.emailController,
    required this.passwordController,
    required this.onAppleTap,
    required this.onGoogleTap,
    required this.onEmailTap,
    required this.onContinueEmailTap,
  });

  final bool showInlineEmailStep;
  final bool showInlinePasswordStep;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onAppleTap;
  final VoidCallback onGoogleTap;
  final VoidCallback onEmailTap;
  final VoidCallback onContinueEmailTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LuxuryNeonBackdrop(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 7),
                      const Center(
                        // Keep header identical also when "Email" step is shown.
                        child: SinapsyAnimatedLogo(size: 108),
                      ),
                      const SizedBox(height: 8),
                      const _OnboardingTopHeader(),
                      const SizedBox(height: 30),
                      _WelcomePrimaryButton(
                        label: 'Continua con Apple',
                        icon: Icons.apple_rounded,
                        onTap: onAppleTap,
                      ),
                      const SizedBox(height: 12),
                      _WelcomeSecondaryButton(
                        label: 'Continua con Google',
                        leading: Text(
                          'G',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        onTap: onGoogleTap,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppTheme.colorStrokeSubtle.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'oppure',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.colorTextTertiary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: AppTheme.colorStrokeSubtle.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (showInlineEmailStep) ...[
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 18,
                              color: AppTheme.colorTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: AppTheme.colorBgSecondary,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppTheme.colorStrokeSubtle.withValues(
                                  alpha: 0.95,
                                ),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppTheme.colorStrokeSubtle.withValues(
                                  alpha: 0.95,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppTheme.colorAccentPrimary,
                              ),
                            ),
                          ),
                        ),
                        if (showInlinePasswordStep) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 18,
                                color: AppTheme.colorTextSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              filled: true,
                              fillColor: AppTheme.colorBgSecondary,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppTheme.colorStrokeSubtle.withValues(
                                    alpha: 0.95,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: AppTheme.colorStrokeSubtle.withValues(
                                    alpha: 0.95,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppTheme.colorAccentPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _WelcomePrimaryButton(
                          label: 'Continua',
                          icon: Icons.chevron_right_rounded,
                          onTap: onContinueEmailTap,
                          iconTrailing: true,
                        ),
                      ] else ...[
                        TextButton.icon(
                          onPressed: onEmailTap,
                          icon: const Icon(
                            Icons.mail_outline_rounded,
                            size: 20,
                            color: AppTheme.colorTextSecondary,
                          ),
                          label: Text(
                            'Continua con Email',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.colorTextSecondary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.colorTextSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.colorTextTertiary,
                                height: 1.35,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Continuando accetti i nostri ',
                                ),
                                TextSpan(
                                  text: 'Termini di Servizio',
                                  style: const TextStyle(
                                    color: AppTheme.colorAccentPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' e la '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                    color: AppTheme.colorAccentPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePrimaryButton extends StatelessWidget {
  const _WelcomePrimaryButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.iconTrailing = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool iconTrailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF9B4EFF), Color(0xFF9E53EA)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66281A4A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null && !iconTrailing) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (icon != null && iconTrailing) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _WelcomeSecondaryButton extends StatelessWidget {
  const _WelcomeSecondaryButton({
    required this.label,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(
          color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.95),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
    final logoSize = compact ? 122.0 : 164.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [SinapsyAnimatedLogo(size: logoSize)],
      ),
    );
  }
}

class _OnboardingTopHeader extends StatelessWidget {
  const _OnboardingTopHeader();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Sinapsy',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF2E7FF),
              letterSpacing: -0.15,
              height: 1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'Connect',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFCEAEFF),
              letterSpacing: 0.74,
              height: 1,
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
