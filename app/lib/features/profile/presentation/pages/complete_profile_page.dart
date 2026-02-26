import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../data/profile_model.dart';
import '../controllers/profile_controller.dart';

class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _locationController = TextEditingController();
  ProfileRole? _selectedRole;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      ref.read(profileControllerProvider.notifier).watchMyProfile();
      final profile = await ref
          .read(profileControllerProvider.notifier)
          .loadMyProfile();
      if (!mounted || profile == null) return;
      setState(() {
        _selectedRole = profile.role;
        if (_usernameController.text.isEmpty) {
          _usernameController.text = profile.username;
        }
        if (_locationController.text.isEmpty) {
          _locationController.text = profile.location;
        }
      });
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_selectedRole == null) {
      _showSnack('Seleziona un ruolo.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final profile = await ref
        .read(profileControllerProvider.notifier)
        .upsertMyProfile(
          role: _selectedRole!,
          username: _usernameController.text,
          location: _locationController.text,
        );
    if (!mounted || profile == null || profile.role == null) return;

    context.go(AppRouter.homePathForRole(profile.role!));
  }

  String? _validateRequired(String? value, String fieldName) {
    if ((value ?? '').trim().isEmpty) {
      return '$fieldName obbligatorio';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    ref.listen<ProfileUiState>(profileControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(profileControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Completa profilo')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Scegli il tuo ruolo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: ProfileRole.values
                          .map(
                            (role) => _RoleCard(
                              role: role,
                              isSelected: _selectedRole == role,
                              onTap: state.isLoading
                                  ? null
                                  : () => setState(() => _selectedRole = role),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          _validateRequired(value, 'Username'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          _validateRequired(value, 'Location'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: state.isLoading ? null : _save,
                      child: const Text('Salva profilo'),
                    ),
                    if (state.isLoading) ...[
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  final ProfileRole role;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 160,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.08)
                : colorScheme.surface,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconForRole(role)),
              const SizedBox(height: 12),
              Text(
                role.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForRole(ProfileRole role) {
    switch (role) {
      case ProfileRole.brand:
        return Icons.storefront_outlined;
      case ProfileRole.creator:
        return Icons.camera_alt_outlined;
    }
  }
}
