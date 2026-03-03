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
import '../../../../core/widgets/sinapsy_confirm_dialog.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../brand/presentation/controllers/brand_notifications_badge_controller.dart';
import '../../../brand/presentation/pages/brand_notifications_page.dart';
import '../../../campaigns/presentation/pages/create_campaign_page.dart';
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
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      ref.read(profileControllerProvider.notifier).watchMyProfile();
      await ref.read(profileControllerProvider.notifier).loadMyProfile();
      await ref.read(brandNotificationsBadgeControllerProvider.notifier).init();
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

  Future<void> _openPrimaryAction(ProfileModel profile) async {
    if (profile.role == ProfileRole.brand) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const CreateCampaignPage()),
      );
      return;
    }
    await _openEdit(profile);
  }

  Future<void> _openNotifications(ProfileModel profile) async {
    if (profile.role != ProfileRole.brand) {
      _showSnack('Centro notifiche disponibile per il profilo Brand.');
      return;
    }

    await ref
        .read(brandNotificationsBadgeControllerProvider.notifier)
        .markAllSeen();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const BrandNotificationsPage()),
    );
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

    final userId =
        ref.read(authRepositoryProvider).currentUser?.id ?? profile.id;
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

  Future<void> _confirmAndLogout() async {
    if (_isLoggingOut) return;

    final shouldLogout = await showSinapsyConfirmDialog(
      context: context,
      title: 'Esci dall\'account?',
      message:
          'Sei sicuro di voler uscire dal tuo account su questo dispositivo?',
      cancelLabel: 'Annulla',
      confirmLabel: 'Esci',
      icon: Icons.logout_rounded,
    );
    if (!shouldLogout || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      ref.read(profileControllerProvider.notifier).reset();
      if (!mounted) return;
      context.go(AppRouter.authPath);
    } catch (error) {
      _showSnack('Errore durante il logout: $error');
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final badgeState = ref.watch(brandNotificationsBadgeControllerProvider);
    final theme = Theme.of(context);
    final pageTheme = theme.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(theme.textTheme),
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(
        theme.primaryTextTheme,
      ),
      scaffoldBackgroundColor: Colors.transparent,
    );

    ref.listen<ProfileUiState>(profileControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(profileControllerProvider.notifier).clearError();
      }
    });

    final profile = state.profile;
    final isBusy = state.isLoading || _isUploadingAvatar || _isLoggingOut;

    return Theme(
      data: pageTheme,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: LuxuryNeonBackdrop()),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
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

                      final specialization = _profileSpecialization(profile);
                      final bioText = _profileBioText(profile);
                      final displayName = _displayName(profile);
                      final location = profile.location.trim().isEmpty
                          ? 'Italia'
                          : profile.location.trim();
                      final followers = profile.followersCount ?? 15210;
                      final followersBase = profile.followersCount ?? 37;
                      final works = followersBase > 0
                          ? (followersBase % 80 + 12)
                          : 37;
                      final portfolioUrls = _portfolioUrlsForProfile(profile);

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Stack(
                              children: [
                                GestureDetector(
                                  onLongPress: isBusy
                                      ? null
                                      : () => _changeAvatar(profile),
                                  child: _ProfileHeroBackdrop(
                                    profile: profile,
                                    pendingAvatarBytes: _pendingAvatarBytes,
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Row(
                                    children: [
                                      _TopActionIconButton(
                                        icon: Icons.notifications_none_rounded,
                                        showBadge:
                                            profile.role == ProfileRole.brand &&
                                            badgeState.hasUnread,
                                        onTap: () =>
                                            _openNotifications(profile),
                                      ),
                                      const SizedBox(width: 8),
                                      _TopActionIconButton(
                                        icon: Icons.add_rounded,
                                        primary: true,
                                        onTap: () =>
                                            _openPrimaryAction(profile),
                                        onLongPress: _confirmAndLogout,
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  left: 14,
                                  right: 14,
                                  bottom: 14,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 34,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFF2EBFF),
                                                height: 1,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.verified_rounded,
                                            size: 21,
                                            color: Color(0xFF3E86FF),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      _RoleTagChip(label: specialization),
                                      const SizedBox(height: 10),
                                      _ProfileInfoCard(
                                        location: location,
                                        bioText: bioText,
                                        specialization: specialization,
                                        rating: '4.8',
                                        works: '$works',
                                        quality: '96%',
                                        followers:
                                            '${followers.toString()} follower',
                                        onMainAction: isBusy
                                            ? null
                                            : () => _openEdit(profile),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Portfolio',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEDE5FF),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _PortfolioGrid(
                              profileId: profile.id,
                              urls: portfolioUrls,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(ProfileModel profile) {
    final full = [
      (profile.firstName ?? '').trim(),
      (profile.lastName ?? '').trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    return profile.username.trim().isEmpty
        ? 'Creator'
        : profile.username.trim();
  }

  String _profileSpecialization(ProfileModel profile) {
    final bio = profile.bio.trim();
    if (bio.isEmpty) {
      return profile.role == ProfileRole.brand ? 'Brand' : 'Creator';
    }
    final direct = RegExp(
      r'(Specializzazione|Tipologia|Categoria|Category):\s*\n?([^\n]+)',
      caseSensitive: false,
    ).firstMatch(bio);
    final value = (direct?.group(2) ?? '').trim();
    if (value.isNotEmpty) return value;
    return profile.role == ProfileRole.brand ? 'Brand' : 'Creator';
  }

  String _profileBioText(ProfileModel profile) {
    final raw = profile.bio.trim();
    if (raw.isEmpty) {
      final place = profile.location.trim().isEmpty
          ? 'Italia'
          : profile.location.trim();
      return 'Professionista di $place. Specializzato in contenuti visual e collaborazioni di qualita.';
    }
    final chunks = raw
        .split(RegExp(r'\n{2,}'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .where((item) {
          final lower = item.toLowerCase();
          return !(lower.startsWith('specializzazione:') ||
              lower.startsWith('tipologia:') ||
              lower.startsWith('categoria:') ||
              lower.startsWith('category:'));
        })
        .toList(growable: false);
    return chunks.isEmpty ? raw : chunks.join('\n\n');
  }

  List<String> _portfolioUrlsForProfile(ProfileModel profile) {
    final avatar = (profile.avatarUrl ?? '').trim();
    if (avatar.isEmpty) return const <String>[];
    return List<String>.filled(6, avatar);
  }
}

class _ProfileHeroBackdrop extends StatelessWidget {
  const _ProfileHeroBackdrop({
    required this.profile,
    required this.pendingAvatarBytes,
  });

  final ProfileModel profile;
  final Uint8List? pendingAvatarBytes;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (profile.avatarUrl ?? '').trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 492,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (pendingAvatarBytes != null)
              Image.memory(
                pendingAvatarBytes!,
                key: ValueKey<String>('profile-hero-bytes-${profile.id}'),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              )
            else if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                key: ValueKey<String>('profile-hero-${profile.id}-$imageUrl'),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                gaplessPlayback: false,
                errorBuilder: (_, _, _) => const _ProfileHeroFallback(),
              )
            else
              const _ProfileHeroFallback(),
            if (pendingAvatarBytes != null || imageUrl.isNotEmpty)
              ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withValues(alpha: 0.94),
                    Colors.black.withValues(alpha: 0.38),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.68, 0.98],
                ).createShader(rect),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 9.0, sigmaY: 9.0),
                  child: pendingAvatarBytes != null
                      ? Image.memory(
                          pendingAvatarBytes!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          gaplessPlayback: false,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.12),
                    const Color(0xFF0F0A19).withValues(alpha: 0.56),
                    const Color(0xFF06050C).withValues(alpha: 0.95),
                  ],
                  stops: const [0, 0.44, 0.72, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopActionIconButton extends StatelessWidget {
  const _TopActionIconButton({
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.primary = false,
    this.showBadge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool primary;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFB16DFF), Color(0xFF7C49EF)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF201D2F), Color(0xFF121221)],
                ),
          border: Border.all(
            color: primary
                ? const Color(0xFFE7D8FF).withValues(alpha: 0.24)
                : const Color(0xFF6F648A).withValues(alpha: 0.3),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: primary ? 27 : 23, color: const Color(0xFFF3EEFF)),
            if (showBadge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF4E6E),
                    border: Border.all(
                      color: const Color(0xFF171522),
                      width: 1,
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

class _RoleTagChip extends StatelessWidget {
  const _RoleTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x5A8D4AFF), Color(0x3A4E2B8A)],
          ),
          border: Border.all(
            color: const Color(0xFFBE91FF).withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE7DCFF),
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.location,
    required this.bioText,
    required this.specialization,
    required this.rating,
    required this.works,
    required this.quality,
    required this.followers,
    this.onMainAction,
  });

  final String location;
  final String bioText;
  final String specialization;
  final String rating;
  final String works;
  final String quality;
  final String followers;
  final VoidCallback? onMainAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7A4CDD).withValues(alpha: 0.42),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xD81B1230), Color(0xCC100B22)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _HeaderStat(icon: Icons.star_rounded, text: rating),
              const SizedBox(width: 12),
              _HeaderStat(icon: Icons.work_outline_rounded, text: works),
              const SizedBox(width: 12),
              _HeaderStat(icon: Icons.bolt_rounded, text: quality),
              const Spacer(),
              _PrimaryPillButton(text: 'Modifica', onTap: onMainAction),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            followers,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFFCEBDEF),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 15,
                color: const Color(0xFFB57EFF).withValues(alpha: 0.95),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFE3D9F8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bioText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFFCCBFE9),
              height: 1.26,
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            color: const Color(0xFF8F5BE8).withValues(alpha: 0.28),
            height: 1,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Bio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF2EAFF),
                ),
              ),
              const SizedBox(width: 10),
              _RoleTagChip(label: specialization),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD1A1FF)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Color(0xFFEEE5FF),
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  const _PrimaryPillButton({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: onTap == null
                ? [
                    const Color(0xFF7C5AB4).withValues(alpha: 0.34),
                    const Color(0xFF5D4388).withValues(alpha: 0.34),
                  ]
                : const [Color(0xFF8D5BFF), Color(0xFF6E41DA)],
          ),
          border: Border.all(
            color: const Color(0xFFE6D9FF).withValues(alpha: 0.24),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(
                      0xFFF7F2FF,
                    ).withValues(alpha: onTap == null ? 0.6 : 1),
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortfolioGrid extends StatelessWidget {
  const _PortfolioGrid({required this.profileId, required this.urls});

  final String profileId;
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7040CF).withValues(alpha: 0.3),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xB1150E29), Color(0xAA0F0A1E)],
        ),
      ),
      child: GridView.builder(
        itemCount: 6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.06,
        ),
        itemBuilder: (context, index) {
          final url = index < urls.length ? urls[index] : null;
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2B1D45), Color(0xFF19132A)],
                ),
              ),
              child: (url ?? '').trim().isEmpty
                  ? Icon(
                      Icons.image_outlined,
                      size: 20,
                      color: const Color(0xFFD1C2F2).withValues(alpha: 0.8),
                    )
                  : Image.network(
                      url!,
                      key: ValueKey<String>('portfolio-$profileId-$index-$url'),
                      fit: BoxFit.cover,
                      gaplessPlayback: false,
                      filterQuality: FilterQuality.low,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.broken_image_outlined,
                        size: 20,
                        color: const Color(0xFFD1C2F2).withValues(alpha: 0.8),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeroFallback extends StatelessWidget {
  const _ProfileHeroFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A203A), Color(0xFF150F24), Color(0xFF07070C)],
        ),
      ),
    );
  }
}
