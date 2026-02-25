import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/home/presentation/pages/brand_home_page.dart';
import '../../features/home/presentation/pages/creator_home_page.dart';
import '../../features/profile/data/profile_model.dart';
import '../../features/profile/presentation/pages/complete_profile_page.dart';
import '../auth/auth_gate.dart';

class AppRouter {
  static const String splashPath = '/';
  static const String authPath = '/auth';
  static const String completeProfilePath = '/complete-profile';
  static const String brandHomePath = '/home/brand';
  static const String creatorHomePath = '/home/creator';

  static String homePathForRole(ProfileRole role) {
    switch (role) {
      case ProfileRole.brand:
        return brandHomePath;
      case ProfileRole.creator:
      case ProfileRole.service:
        return creatorHomePath;
    }
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRouter.splashPath,
    routes: [
      GoRoute(
        path: AppRouter.splashPath,
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: AppRouter.authPath,
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: AppRouter.completeProfilePath,
        builder: (context, state) => const CompleteProfilePage(),
      ),
      GoRoute(
        path: AppRouter.brandHomePath,
        builder: (context, state) => const BrandHomePage(),
      ),
      GoRoute(
        path: AppRouter.creatorHomePath,
        builder: (context, state) => const CreatorHomePage(),
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Route non trovata: ${state.uri.path}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    },
  );
});
