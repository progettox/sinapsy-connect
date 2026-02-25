import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../applications/presentation/pages/my_applications_page.dart';
import '../../../campaigns/presentation/pages/creator_feed_page.dart';
import '../controllers/home_controller.dart';

class CreatorHomePage extends ConsumerWidget {
  const CreatorHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider);

    ref.listen<HomeUiState>(homeControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
        ref.read(homeControllerProvider.notifier).clearError();
      }
    });

    final email = state.user?.email ?? 'email non disponibile';

    return Scaffold(
      appBar: AppBar(title: const Text('Creator Home')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Logged in as $email',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreatorFeedPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Open Feed'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 260,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MyApplicationsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('My Applications'),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        final ok = await ref
                            .read(homeControllerProvider.notifier)
                            .logout();
                        if (!ok || !context.mounted) return;
                        context.go(AppRouter.authPath);
                      },
                child: const Text('Logout'),
              ),
              if (state.isLoading) ...[
                const SizedBox(height: 12),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
