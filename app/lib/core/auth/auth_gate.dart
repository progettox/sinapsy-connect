import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/profile/data/profile_model.dart';
import '../../features/profile/data/profile_repository.dart';
import '../router/app_router.dart';
import '../widgets/luxury_neon_backdrop.dart';
import '../widgets/sinapsy_logo_loader.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_resolveBootstrapFlow);
  }

  Future<void> _resolveBootstrapFlow() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future<void>.delayed(const Duration(seconds: 1));

      final authRepository = ref.read(authRepositoryProvider);
      final profileRepository = ref.read(profileRepositoryProvider);
      final session = authRepository.currentSession;

      if (session == null) {
        _go(AppRouter.authPath);
        return;
      }

      final profile = await profileRepository.getCurrentProfile();
      if (!_isProfileComplete(profile)) {
        _go(AppRouter.completeProfilePath);
        return;
      }

      final role = profile!.role!;
      _go(AppRouter.homePathForRole(role));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Errore bootstrap: $error';
      });
    }
  }

  bool _isProfileComplete(ProfileModel? profile) {
    if (profile == null) return false;
    return profile.isComplete;
  }

  void _go(String path) {
    if (!mounted || _hasRedirected) return;
    _hasRedirected = true;
    context.go(path);
  }

  void _retry() {
    _hasRedirected = false;
    _resolveBootstrapFlow();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            LuxuryNeonBackdrop(),
            Center(child: SinapsyLogoLoader(size: 46)),
          ],
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage ?? 'Errore inatteso',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _retry, child: const Text('Riprova')),
            ],
          ),
        ),
      ),
    );
  }
}
