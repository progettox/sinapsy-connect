import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_model.dart';
import '../controllers/profile_controller.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({
    required this.profile,
    super.key,
  });

  final ProfileModel profile;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _avatarUrlController;
  late ProfileRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.profile.username);
    _bioController = TextEditingController(text: widget.profile.bio);
    _locationController = TextEditingController(text: widget.profile.location);
    _avatarUrlController = TextEditingController(
      text: widget.profile.avatarUrl ?? '',
    );
    _selectedRole = widget.profile.role ?? ProfileRole.creator;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final profile = await ref.read(profileControllerProvider.notifier).upsertMyProfile(
          role: _selectedRole,
          username: _usernameController.text,
          location: _locationController.text,
          bio: _bioController.text,
          avatarUrl: _avatarUrlController.text,
        );
    if (!mounted || profile == null) return;

    Navigator.of(context).pop();
  }

  String? _validateRequired(String? value, String fieldName) {
    if ((value ?? '').trim().isEmpty) return '$fieldName obbligatorio';
    return null;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Modifica profilo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<ProfileRole>(
                  key: ValueKey<ProfileRole>(_selectedRole),
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Ruolo',
                    border: OutlineInputBorder(),
                  ),
                  items: ProfileRole.values
                      .map(
                        (role) => DropdownMenuItem<ProfileRole>(
                          value: role,
                          child: Text(role.label),
                        ),
                      )
                      .toList(),
                  onChanged: state.isLoading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _selectedRole = value);
                        },
                  validator: (value) => value == null ? 'Ruolo obbligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => _validateRequired(value, 'Username'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => _validateRequired(value, 'Location'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _avatarUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Avatar URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: state.isLoading ? null : _save,
                  child: const Text('Salva modifiche'),
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
    );
  }
}
