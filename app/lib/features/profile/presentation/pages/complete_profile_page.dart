import 'dart:ui';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
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
  static const List<ProfileRole> _roleOrder = <ProfileRole>[
    ProfileRole.brand,
    ProfileRole.creator,
  ];
  static const List<String> _brandTypeOptions = <String>[
    'Brand',
    'Impresa',
    'E-commerce',
    'Startup',
    'Agenzia',
  ];
  static const List<String> _creatorTypeOptions = <String>[
    'Creator',
    'Fotografo',
    'Videomaker',
  ];

  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final _brandLinksController = TextEditingController();
  final _usernameController = TextEditingController();
  final _locationController = TextEditingController();
  ProfileRole? _selectedRole;
  String? _selectedBrandType;
  String? _selectedCreatorType;
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  bool _isRoleSelectionStep = true;

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
        _isRoleSelectionStep = profile.role == null;
        final parsedProfileMeta = _parseProfileMetadata(profile.bio);
        if (_bioController.text.isEmpty) {
          _bioController.text = parsedProfileMeta['bio'] ?? '';
        }
        final savedBrandType = parsedProfileMeta['brandType'] ?? '';
        if ((_selectedBrandType ?? '').isEmpty && savedBrandType.isNotEmpty) {
          _selectedBrandType = _brandTypeOptions.contains(savedBrandType)
              ? savedBrandType
              : null;
        }
        final savedCreatorType = parsedProfileMeta['creatorType'] ?? '';
        if ((_selectedCreatorType ?? '').isEmpty &&
            savedCreatorType.isNotEmpty) {
          _selectedCreatorType = _creatorTypeOptions.contains(savedCreatorType)
              ? savedCreatorType
              : null;
        }
        if (_brandLinksController.text.isEmpty) {
          _brandLinksController.text = parsedProfileMeta['links'] ?? '';
        }
        _avatarUrl = profile.avatarUrl;
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
    _bioController.dispose();
    _brandLinksController.dispose();
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

    final isBrand = _selectedRole == ProfileRole.brand;
    final isCreator = _selectedRole == ProfileRole.creator;
    if (isBrand && (_selectedBrandType ?? '').trim().isEmpty) {
      _showSnack('Seleziona la tipologia della tua attivita.');
      return;
    }
    if (isCreator && (_selectedCreatorType ?? '').trim().isEmpty) {
      _showSnack('Seleziona la tua specializzazione.');
      return;
    }
    var avatarUrl = _avatarUrl;
    final profileBio = _composeProfileBio(
      _bioController.text,
      _brandLinksController.text,
      brandType: isBrand ? _selectedBrandType : null,
      creatorType: isCreator ? _selectedCreatorType : null,
    );

    if (_avatarBytes != null && _avatarFileName != null) {
      final userId = ref.read(authRepositoryProvider).currentUser?.id;
      if (userId == null) {
        _showSnack('Sessione non valida. Effettua di nuovo il login.');
        return;
      }

      setState(() => _isUploadingAvatar = true);
      try {
        avatarUrl = await ref
            .read(storageServiceProvider)
            .uploadProfileAvatar(
              userId: userId,
              bytes: _avatarBytes!,
              originalFileName: _avatarFileName!,
            );
      } catch (error) {
        if (mounted) {
          _showSnack('Errore caricamento foto profilo: $error');
        }
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _avatarUrl = avatarUrl;
          _avatarBytes = null;
          _avatarFileName = null;
          _isUploadingAvatar = false;
        });
      }
    }

    final profile = await ref
        .read(profileControllerProvider.notifier)
        .upsertMyProfile(
          role: _selectedRole!,
          firstName: null,
          lastName: null,
          birthDate: null,
          bio: profileBio,
          avatarUrl: avatarUrl,
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

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _showSnack('Impossibile leggere il file selezionato.');
      return;
    }

    setState(() {
      _avatarBytes = file.bytes;
      _avatarFileName = file.name;
    });
  }

  Widget _buildAvatarPicker({required bool isBusy, required ProfileRole role}) {
    final placeholderIcon = role == ProfileRole.brand
        ? Icons.storefront_rounded
        : Icons.auto_awesome_rounded;
    final label = role == ProfileRole.brand
        ? 'Foto profilo brand'
        : 'Foto profilo creator';

    Widget avatar;
    if (_avatarBytes != null) {
      avatar = ClipOval(
        child: Image.memory(
          _avatarBytes!,
          fit: BoxFit.cover,
          width: 108,
          height: 108,
        ),
      );
    } else if ((_avatarUrl ?? '').trim().isNotEmpty) {
      avatar = ClipOval(
        child: Image.network(
          _avatarUrl!,
          fit: BoxFit.cover,
          width: 108,
          height: 108,
          errorBuilder: (_, _, _) => Icon(placeholderIcon, size: 38),
        ),
      );
    } else {
      avatar = Icon(placeholderIcon, size: 38);
    }

    return Column(
      children: [
        GestureDetector(
          onTap: isBusy ? null : _pickAvatar,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x261A2E49),
                  border: Border.all(
                    color: const Color(0x90A8CCF2),
                    width: 1.2,
                  ),
                ),
                child: Center(child: avatar),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF8EC8FF),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    size: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xDDEAF3FF),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector({
    required bool isBusy,
    required String title,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xDDEAF3FF),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option),
                selected: selectedValue == option,
                onSelected: isBusy
                    ? null
                    : (selected) => onChanged(selected ? option : null),
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selectedValue == option
                      ? const Color(0xFF0D1826)
                      : const Color(0xE8E8F3FF),
                ),
                backgroundColor: const Color(0x301A2B42),
                selectedColor: const Color(0xFF8EC8FF),
                side: BorderSide(
                  color: selectedValue == option
                      ? const Color(0xFFB8DCFF)
                      : const Color(0x7A88A9CC),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrandTypeSelector(bool isBusy) {
    return _buildTypeSelector(
      isBusy: isBusy,
      title: 'Tipologia attivita',
      options: _brandTypeOptions,
      selectedValue: _selectedBrandType,
      onChanged: (value) => setState(() => _selectedBrandType = value),
    );
  }

  Widget _buildCreatorTypeSelector(bool isBusy) {
    return _buildTypeSelector(
      isBusy: isBusy,
      title: 'Specializzazione',
      options: _creatorTypeOptions,
      selectedValue: _selectedCreatorType,
      onChanged: (value) => setState(() => _selectedCreatorType = value),
    );
  }

  String _composeProfileBio(
    String bio,
    String links, {
    String? brandType,
    String? creatorType,
  }) {
    final cleanBio = bio.trim();
    final cleanLinks = links.trim();
    final cleanBrandType = (brandType ?? '').trim();
    final cleanCreatorType = (creatorType ?? '').trim();
    final sections = <String>[
      if (cleanBio.isNotEmpty) cleanBio,
      if (cleanBrandType.isNotEmpty) 'Tipologia:\n$cleanBrandType',
      if (cleanCreatorType.isNotEmpty) 'Specializzazione:\n$cleanCreatorType',
      if (cleanLinks.isNotEmpty) 'Links:\n$cleanLinks',
    ];
    return sections.join('\n\n');
  }

  Map<String, String> _parseProfileMetadata(String rawBio) {
    final trimmed = rawBio.trim();
    if (trimmed.isEmpty) {
      return <String, String>{
        'bio': '',
        'brandType': '',
        'creatorType': '',
        'links': '',
      };
    }

    var brandType = '';
    var creatorType = '';
    var links = '';
    final bioChunks = <String>[];
    for (final chunk in trimmed.split('\n\n')) {
      if (chunk.startsWith('Tipologia:\n')) {
        brandType = chunk.substring('Tipologia:\n'.length).trim();
        continue;
      }
      if (chunk.startsWith('Specializzazione:\n')) {
        creatorType = chunk.substring('Specializzazione:\n'.length).trim();
        continue;
      }
      if (chunk.startsWith('Links:\n')) {
        links = chunk.substring('Links:\n'.length).trim();
        continue;
      }
      bioChunks.add(chunk.trimRight());
    }

    return <String, String>{
      'bio': bioChunks.join('\n\n').trim(),
      'brandType': brandType,
      'creatorType': creatorType,
      'links': links,
    };
  }

  Future<void> _goToLogin() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    if (!mounted) return;
    context.go(AppRouter.authPath);
  }

  String _roleDescription(ProfileRole role) {
    switch (role) {
      case ProfileRole.brand:
        return 'Pubblica campagne e collabora con creator selezionati.';
      case ProfileRole.creator:
        return 'Scopri opportunita, candidati e consegna progetti ai brand.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final theme = Theme.of(context);
    final pageTextTheme = GoogleFonts.plusJakartaSansTextTheme(theme.textTheme);
    final isBusy = state.isLoading || _isUploadingAvatar;
    final isBrandRole = _selectedRole == ProfileRole.brand;
    final locationLabel = isBrandRole ? 'Sede' : 'Localita';

    ref.listen<ProfileUiState>(profileControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(profileControllerProvider.notifier).clearError();
      }
    });

    return Theme(
      data: theme.copyWith(
        textTheme: pageTextTheme,
        primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(
          theme.primaryTextTheme,
        ),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isRoleSelectionStep) ...[
                            Align(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x44101722),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0x8C87B0E5),
                                  ),
                                ),
                                child: Text(
                                  'STEP 1 / 2',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: const Color(0xFFDDEBFF),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Scegli il tuo ruolo',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                height: 1,
                                color: const Color(0xFFEAF3FF),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Seleziona Brand o Creator per continuare.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xB7D6E8FF),
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 26),
                            Column(
                              children: [
                                for (final entry in _roleOrder.asMap().entries)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: entry.key == _roleOrder.length - 1
                                          ? 0
                                          : 18,
                                    ),
                                    child: _RoleCard(
                                      role: entry.value,
                                      description: _roleDescription(
                                        entry.value,
                                      ),
                                      isSelected: _selectedRole == entry.value,
                                      onTap: isBusy
                                          ? null
                                          : () => setState(() {
                                              _selectedRole = entry.value;
                                              _isRoleSelectionStep = false;
                                            }),
                                    ),
                                  ),
                              ],
                            ),
                          ] else ...[
                            SizedBox(
                              height: 44,
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: IconButton(
                                      onPressed: isBusy
                                          ? null
                                          : () => setState(() {
                                              _isRoleSelectionStep = true;
                                            }),
                                      icon: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                      ),
                                      color: const Color(0xFF8EC8FF),
                                      tooltip: 'Torna alla scelta ruolo',
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      'Crea il tuo profilo',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (isBrandRole) ...[
                              Center(
                                child: _buildAvatarPicker(
                                  isBusy: isBusy,
                                  role: ProfileRole.brand,
                                ),
                              ),
                              const SizedBox(height: 14),
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
                              _buildBrandTypeSelector(isBusy),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _bioController,
                                minLines: 3,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  labelText: 'Bio del brand',
                                  hintText:
                                      'Racconta in breve il tuo brand, tono e valori.',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _brandLinksController,
                                minLines: 2,
                                maxLines: 4,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  labelText: 'Link social o sito web',
                                  hintText:
                                      'https://instagram.com/tuobrand\nhttps://tuobrand.com',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ] else ...[
                              Center(
                                child: _buildAvatarPicker(
                                  isBusy: isBusy,
                                  role: ProfileRole.creator,
                                ),
                              ),
                              const SizedBox(height: 14),
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
                              _buildCreatorTypeSelector(isBusy),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _bioController,
                                minLines: 3,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  labelText: 'Bio del creator',
                                  hintText:
                                      'Presentati: stile contenuti, nicchia e formato principale.',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _brandLinksController,
                                minLines: 2,
                                maxLines: 4,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  labelText: 'Link social o portfolio',
                                  hintText:
                                      'https://instagram.com/tuonome\nhttps://youtube.com/@tuonome',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _locationController,
                              decoration: InputDecoration(
                                labelText: locationLabel,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  _validateRequired(value, locationLabel),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: isBusy ? null : _save,
                              child: const Text('Salva profilo'),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: isBusy ? null : _goToLogin,
                            child: const Text('Ho gia un account'),
                          ),
                          if (isBusy) ...[
                            const SizedBox(height: 16),
                            const Center(child: SinapsyLogoLoader()),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  final ProfileRole role;
  final String description;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8EC8FF);
    final border = isSelected
        ? const Color(0xAAAFD8FF)
        : const Color(0x6186A3C5);
    final surface = isSelected
        ? const Color(0x40293E62)
        : const Color(0x30152036);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 148),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: border,
                  width: isSelected ? 1.8 : 1.2,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    surface,
                    const Color(0x1A1B2C46),
                    const Color(0x12111A2A),
                  ],
                  stops: const [0, 0.56, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF78B8FF,
                    ).withValues(alpha: isSelected ? 0.34 : 0.14),
                    blurRadius: isSelected ? 30 : 18,
                    spreadRadius: isSelected ? 1 : 0,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isSelected ? 0.42 : 0.28,
                    ),
                    blurRadius: isSelected ? 28 : 18,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.all(1.8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: isSelected ? 0.18 : 0.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: -26,
                    child: IgnorePointer(
                      child: Container(
                        height: 78,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(60),
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(
                                alpha: isSelected ? 0.3 : 0.18,
                              ),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -16,
                    top: -22,
                    child: IgnorePointer(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(
                                alpha: isSelected ? 0.26 : 0.12,
                              ),
                              accent.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 22,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.16),
                                const Color(0x1A87B8F2),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(
                                  alpha: isSelected ? 0.24 : 0.12,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            _iconForRole(role),
                            color: isSelected
                                ? accent
                                : const Color(0xFFDDEBFF),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role.label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.35,
                                  color: const Color(0xFFF2F7FF),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  height: 1.3,
                                  color: const Color(0xD7D8E9FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.arrow_forward_rounded
                              : Icons.chevron_right_rounded,
                          color: isSelected ? accent : const Color(0xFFC9D7E8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForRole(ProfileRole role) {
    switch (role) {
      case ProfileRole.brand:
        return Icons.storefront_rounded;
      case ProfileRole.creator:
        return Icons.auto_awesome_rounded;
    }
  }
}
