import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/data/auth_repository.dart';
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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _usernameController = TextEditingController();
  final _locationController = TextEditingController();
  ProfileRole? _selectedRole;
  DateTime? _selectedBirthDate;

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
        if (_firstNameController.text.isEmpty) {
          _firstNameController.text = profile.firstName ?? '';
        }
        if (_lastNameController.text.isEmpty) {
          _lastNameController.text = profile.lastName ?? '';
        }
        _selectedBirthDate = profile.birthDate;
        _birthDateController.text = _formatBirthDate(profile.birthDate);
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
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
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          birthDate: _selectedBirthDate,
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

  String? _validateBirthDate() {
    if (_selectedBirthDate == null) {
      return 'Data di nascita obbligatoria';
    }
    return null;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _selectedBirthDate ?? DateTime(now.year - 18, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _selectedBirthDate = DateTime(picked.year, picked.month, picked.day);
      _birthDateController.text = _formatBirthDate(_selectedBirthDate);
    });
  }

  String _formatBirthDate(DateTime? date) {
    if (date == null) return '';
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  Future<void> _goToLogin() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    if (!mounted) return;
    context.go(AppRouter.authPath);
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
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _validateRequired(value, 'Nome'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Cognome',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _validateRequired(value, 'Cognome'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      onTap: state.isLoading ? null : _pickBirthDate,
                      decoration: const InputDecoration(
                        labelText: 'Data di nascita',
                        hintText: 'YYYY-MM-DD',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (_) => _validateBirthDate(),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: state.isLoading ? null : _goToLogin,
                      child: const Text('Ho gia un account'),
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
