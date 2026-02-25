import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_model.dart';
import '../controllers/profile_controller.dart';
import 'edit_profile_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      ref.read(profileControllerProvider.notifier).watchMyProfile();
      await ref.read(profileControllerProvider.notifier).loadMyProfile();
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEdit(ProfileModel profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditProfilePage(profile: profile),
      ),
    );
    if (!mounted) return;
    await ref.read(profileControllerProvider.notifier).loadMyProfile();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    ref.listen<ProfileUiState>(profileControllerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(profileControllerProvider.notifier).clearError();
      }
    });

    final profile = state.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (state.isLoading && profile == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (profile == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Profilo non trovato.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(profileControllerProvider.notifier).loadMyProfile(),
                        child: const Text('Ricarica'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundImage: profile.avatarUrl != null
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? const Icon(Icons.person, size: 36)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _ProfileRow(label: 'ID', value: profile.id),
                  _ProfileRow(label: 'Username', value: profile.username),
                  _ProfileRow(
                    label: 'Ruolo',
                    value: profile.role?.label ?? '-',
                  ),
                  _ProfileRow(
                    label: 'Bio',
                    value: profile.bio.trim().isEmpty ? '-' : profile.bio,
                  ),
                  _ProfileRow(label: 'Location', value: profile.location),
                  _ProfileRow(
                    label: 'Avatar URL',
                    value: profile.avatarUrl ?? '-',
                  ),
                  _ProfileRow(
                    label: 'Creato il',
                    value: _formatDate(profile.createdAt),
                  ),
                  _ProfileRow(
                    label: 'Aggiornato il',
                    value: _formatDate(profile.updatedAt),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: state.isLoading ? null : () => _openEdit(profile),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return date.toLocal().toString();
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}
