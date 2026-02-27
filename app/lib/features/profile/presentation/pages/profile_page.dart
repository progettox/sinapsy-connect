import 'dart:ui';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/profile_model.dart';
import '../controllers/profile_controller.dart';
import 'edit_profile_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Uint8List? _pendingAvatarBytes;
  bool _isUploadingAvatar = false;

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

  Future<void> _changeAvatar(ProfileModel profile) async {
    if (_isUploadingAvatar) return;
    if (profile.role == null) {
      _showSnack('Completa il profilo prima di cambiare la foto.');
      return;
    }
    if (profile.username.trim().isEmpty || profile.location.trim().isEmpty) {
      _showSnack('Completa username e sede prima di cambiare la foto.');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    if (file.bytes == null) {
      _showSnack('Impossibile leggere il file selezionato.');
      return;
    }

    setState(() {
      _pendingAvatarBytes = file.bytes;
      _isUploadingAvatar = true;
    });

    final userId = ref.read(authRepositoryProvider).currentUser?.id ?? profile.id;
    try {
      final avatarUrl = await ref
          .read(storageServiceProvider)
          .uploadProfileAvatar(
            userId: userId,
            bytes: file.bytes!,
            originalFileName: file.name,
          );

      if (!mounted) return;
      final updated = await ref
          .read(profileControllerProvider.notifier)
          .upsertMyProfile(
            role: profile.role!,
            username: profile.username,
            location: profile.location,
            firstName: profile.firstName,
            lastName: profile.lastName,
            birthDate: profile.birthDate,
            bio: profile.bio,
            avatarUrl: avatarUrl,
          );
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
        _pendingAvatarBytes = null;
      });
      if (updated != null) {
        _showSnack('Foto profilo aggiornata.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
        _pendingAvatarBytes = null;
      });
      _showSnack('Errore caricamento foto profilo: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final theme = Theme.of(context);
    final pageTheme = theme.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(theme.textTheme),
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(
        theme.primaryTextTheme,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFFEAF3FF),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xC0162030),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFF9FC8F8).withValues(alpha: 0.16),
          ),
        ),
      ),
    );

    ref.listen<ProfileUiState>(profileControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(profileControllerProvider.notifier).clearError();
      }
    });

    final profile = state.profile;

    return Theme(
      data: pageTheme,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  children: [
                    const _ProfileHeaderPanel(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (state.isLoading && profile == null) {
                            return const Center(child: SinapsyLogoLoader());
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
                                      onPressed: () => ref
                                          .read(profileControllerProvider.notifier)
                                          .loadMyProfile(),
                                      child: const Text('Ricarica'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            child: _GlassPanel(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _ProfileAvatarEditor(
                                      profile: profile,
                                      pendingAvatarBytes: _pendingAvatarBytes,
                                      isUploading: _isUploadingAvatar,
                                      onTap: state.isLoading || _isUploadingAvatar
                                          ? null
                                          : () => _changeAvatar(profile),
                                    ),
                                    const SizedBox(height: 20),
                                    _ProfileRow(label: 'ID', value: profile.id),
                                    _ProfileRow(
                                      label: 'Username',
                                      value: profile.username,
                                    ),
                                    _ProfileRow(
                                      label: 'Ruolo',
                                      value: profile.role?.label ?? '-',
                                    ),
                                    _ProfileRow(
                                      label: 'Bio',
                                      value: profile.bio.trim().isEmpty
                                          ? '-'
                                          : profile.bio,
                                    ),
                                    _ProfileRow(
                                      label: 'Sede',
                                      value: profile.location,
                                    ),
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
                                    SizedBox(
                                      width: double.infinity,
                                      height: 40,
                                      child: OutlinedButton(
                                        onPressed:
                                            state.isLoading || _isUploadingAvatar
                                            ? null
                                            : () => _openEdit(profile),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: theme.colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.9),
                                          disabledForegroundColor:
                                              theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.4),
                                          side: BorderSide(
                                            color: const Color(
                                              0xFF9FC8F8,
                                            ).withValues(alpha: 0.24),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          textStyle: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        child: const Text('Modifica'),
                                      ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return date.toLocal().toString();
  }
}

class _ProfileAvatarEditor extends StatelessWidget {
  const _ProfileAvatarEditor({
    required this.profile,
    required this.pendingAvatarBytes,
    required this.isUploading,
    this.onTap,
  });

  final ProfileModel profile;
  final Uint8List? pendingAvatarBytes;
  final bool isUploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = pendingAvatarBytes != null
        ? Image.memory(
            pendingAvatarBytes!,
            fit: BoxFit.cover,
            width: 88,
            height: 88,
          )
        : profile.avatarUrl != null
        ? Image.network(
            profile.avatarUrl!,
            fit: BoxFit.cover,
            width: 88,
            height: 88,
            errorBuilder: (_, _, _) => const Icon(Icons.person, size: 36),
          )
        : const Icon(Icons.person, size: 36);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x261A2E49),
                border: Border.all(
                  color: const Color(0x90A8CCF2),
                  width: 1.2,
                ),
              ),
              child: ClipOval(child: Center(child: avatar)),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                    border: Border.all(
                      color: const Color(0xFF0B1626),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: Color(0xFF07111C),
                  ),
                ),
              ),
            ),
            if (isUploading)
              Positioned.fill(
                child: ClipOval(
                  child: Container(
                    color: const Color(0x88040A14),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProfileHeaderPanel extends StatelessWidget {
  const _ProfileHeaderPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Profilo',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF9FC8F8).withValues(alpha: 0.18),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x8A1B2638), Color(0x7A111A2A), Color(0x63202A3A)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88040A14),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}
