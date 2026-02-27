import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
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
          const _LuxuryDarkBackdrop(),
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

class _LuxuryDarkBackdrop extends StatelessWidget {
  const _LuxuryDarkBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF05080E), Color(0xFF0A111B), Color(0xFF0E1724)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: const [
          Positioned.fill(child: _ShadowBands()),
          Positioned(
            top: -70,
            right: -150,
            child: _ShadowPanel(
              width: 560,
              height: 160,
              angle: -0.38,
              color: Color(0xAA254264),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -180,
            child: _ShadowPanel(
              width: 620,
              height: 170,
              angle: 0.34,
              color: Color(0xAA1B3553),
            ),
          ),
          Positioned(
            top: 160,
            left: -220,
            child: _ShadowPanel(
              width: 500,
              height: 120,
              angle: 0.18,
              color: Color(0x99264366),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShadowBands extends StatelessWidget {
  const _ShadowBands();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _ShadowBandsPainter()));
  }
}

class _ShadowBandsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final band = Paint()
      ..color = const Color(0xFF6C87A7).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const gap = 38.0;
    for (double x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), band);
    }

    final softVignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.92,
        colors: [
          const Color(0x00000000),
          const Color(0xFF000000).withValues(alpha: 0.28),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, softVignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShadowPanel extends StatelessWidget {
  const _ShadowPanel({
    required this.width,
    required this.height,
    required this.angle,
    required this.color,
  });

  final double width;
  final double height;
  final double angle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(120),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [color.withValues(alpha: 0.18), Colors.transparent],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 80,
              spreadRadius: 8,
            ),
          ],
        ),
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
          _AnimatedAtomLogo(size: logoSize),
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
                          _MiniLogoSpinner(size: 18),
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
                    _MiniLogoSpinner(size: 22),
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

class _AnimatedAtomLogo extends StatefulWidget {
  const _AnimatedAtomLogo({required this.size});

  final double size;

  @override
  State<_AnimatedAtomLogo> createState() => _AnimatedAtomLogoState();
}

class _AnimatedAtomLogoState extends State<_AnimatedAtomLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _AtomLogoPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _MiniLogoSpinner extends StatelessWidget {
  const _MiniLogoSpinner({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: _AnimatedAtomLogo(size: size),
    );
  }
}

class _AtomLogoPainter extends CustomPainter {
  const _AtomLogoPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final spin = progress * math.pi * 2;
    final minSide = size.shortestSide;
    final orbitA = minSide * 0.34;
    final orbitB = minSide * 0.13;
    final nucleusRadius = minSide * 0.09;
    final orbitStroke = math.max(0.95, minSide * 0.012);
    final electronRadius = math.max(1.0, minSide * 0.017);
    final orbitAngles = <double>[0, math.pi / 3, -math.pi / 3];
    final globalRotation = spin;
    final pulse = 0.9 + 0.1 * math.sin(spin * 2);

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF76A9FF).withValues(alpha: 0.2 * pulse),
          const Color(0xFF76A9FF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: minSide * 0.48));
    canvas.drawCircle(center, minSide * 0.48, haloPaint);

    final orbitGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = orbitStroke * 1.9
      ..color = const Color(0xFF7DAFFF).withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = orbitStroke
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5FAFF), Color(0xFFD3E7FF), Color(0xFF74A8FF)],
      ).createShader(Rect.fromCircle(center: center, radius: orbitA));

    for (int i = 0; i < orbitAngles.length; i++) {
      final rotation = orbitAngles[i] + globalRotation;
      _drawOrbit(
        canvas: canvas,
        center: center,
        a: orbitA,
        b: orbitB,
        rotation: rotation,
        paint: orbitGlowPaint,
      );
      _drawOrbit(
        canvas: canvas,
        center: center,
        a: orbitA,
        b: orbitB,
        rotation: rotation,
        paint: orbitPaint,
      );

      final electronAngle = spin * 2 + (i * (math.pi * 2 / orbitAngles.length));
      final electron = _ellipsePoint(
        center: center,
        a: orbitA,
        b: orbitB,
        angle: electronAngle,
        rotation: rotation,
      );
      final electronGlow = Paint()
        ..color = const Color(0xFFDCEAFF).withValues(alpha: 0.88)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(electron, electronRadius * 1.6, electronGlow);
      canvas.drawCircle(
        electron,
        electronRadius,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }

    final coreDotGlow = Paint()
      ..color = const Color(0xFFDCEAFF).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final coreDot = Paint()
      ..color = const Color(0xFFF8FBFF).withValues(alpha: 0.95);
    canvas.drawCircle(center, nucleusRadius * 0.52, coreDotGlow);
    canvas.drawCircle(center, nucleusRadius * 0.3, coreDot);
  }

  void _drawOrbit({
    required Canvas canvas,
    required Offset center,
    required double a,
    required double b,
    required double rotation,
    required Paint paint,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: a * 2, height: b * 2),
      paint,
    );
    canvas.restore();
  }

  Offset _ellipsePoint({
    required Offset center,
    required double a,
    required double b,
    required double angle,
    required double rotation,
  }) {
    final x = a * math.cos(angle);
    final y = b * math.sin(angle);
    final xr = x * math.cos(rotation) - y * math.sin(rotation);
    final yr = x * math.sin(rotation) + y * math.cos(rotation);
    return Offset(center.dx + xr, center.dy + yr);
  }

  @override
  bool shouldRepaint(covariant _AtomLogoPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
