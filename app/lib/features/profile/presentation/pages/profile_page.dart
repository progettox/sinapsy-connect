import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_confirm_dialog.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../brand/data/brand_creator_feed_repository.dart';
import '../../../brand/presentation/controllers/brand_notifications_badge_controller.dart';
import '../../../brand/presentation/pages/brand_notifications_page.dart';
import '../../../campaigns/presentation/pages/create_campaign_page.dart';
import '../../../reviews/data/review_model.dart';
import '../../../reviews/data/review_repository.dart';
import '../../data/profile_model.dart';
import '../controllers/profile_controller.dart';
import 'edit_profile_page.dart';
import '../widgets/follow_accounts_sheet.dart';
import '../widgets/profile_image_viewer_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with AutomaticKeepAliveClientMixin<ProfilePage> {
  static const double _profileContentDrop = 272;
  static final Map<String, _FollowCountersSnapshot>
  _followCountersCacheByProfileId = <String, _FollowCountersSnapshot>{};

  Uint8List? _pendingAvatarBytes;
  bool _isUploadingAvatar = false;
  bool _isAddingPortfolioMedia = false;
  bool _isLoggingOut = false;
  bool _isLoadingPortfolio = false;
  String? _portfolioError;
  String? _loadedPortfolioProfileId;
  List<_PortfolioTileData> _portfolioTiles = const <_PortfolioTileData>[];
  bool _isLoadingReviewSummary = false;
  String? _loadedReviewSummaryProfileId;
  ReviewSummary _reviewSummary = const ReviewSummary(
    averageRating: 0,
    totalReviews: 0,
  );
  String? _loadedFollowCountersProfileId;
  bool _isLoadingFollowCounters = false;
  int? _liveFollowersCount;
  int? _liveFollowingCount;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      if (!mounted) return;
      final profileController = ref.read(profileControllerProvider.notifier);
      final badgeController = ref.read(
        brandNotificationsBadgeControllerProvider.notifier,
      );
      profileController.watchMyProfile();
      await profileController.loadMyProfile();
      if (!mounted) return;
      await badgeController.init();
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
    await _addCreatorPortfolioMedia(profile);
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

  Future<void> _openFollowAccounts({
    required ProfileModel profile,
    required FollowAccountsMode mode,
  }) async {
    final profileId = profile.id.trim();
    if (profileId.isEmpty) return;
    await showFollowAccountsSheet(
      context: context,
      client: ref.read(supabaseClientProvider),
      profileId: profileId,
      mode: mode,
      ownerLabel: _displayName(profile),
    );
  }

  Future<void> _loadLiveFollowCountersForProfile(
    String profileId, {
    bool force = false,
  }) async {
    final cleanProfileId = profileId.trim();
    if (cleanProfileId.isEmpty) return;

    if (!force &&
        _loadedFollowCountersProfileId == cleanProfileId &&
        !_isLoadingFollowCounters) {
      return;
    }

    if (mounted) {
      setState(() {
        _loadedFollowCountersProfileId = cleanProfileId;
        _isLoadingFollowCounters = true;
      });
    }

    try {
      final counters = await ref
          .read(brandCreatorFeedRepositoryProvider)
          .getFollowCounters(creatorId: cleanProfileId);
      if (!mounted) return;
      final activeProfileId = ref
          .read(profileControllerProvider)
          .profile
          ?.id
          .trim();
      if (activeProfileId == null || activeProfileId != cleanProfileId) return;

      setState(() {
        _liveFollowersCount = counters.followersCount;
        _liveFollowingCount = counters.followingCount;
        _isLoadingFollowCounters = false;
      });
      _followCountersCacheByProfileId[cleanProfileId] = _FollowCountersSnapshot(
        followersCount: counters.followersCount,
        followingCount: counters.followingCount,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingFollowCounters = false);
    }
  }

  Future<void> _openProfileImageViewer(ProfileModel profile) async {
    final imageUrl = (profile.avatarUrl ?? '').trim();
    if (_pendingAvatarBytes == null && imageUrl.isEmpty) {
      _showSnack('Nessuna foto profilo disponibile.');
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileImageViewerPage(
          imageBytes: _pendingAvatarBytes,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
        ),
      ),
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
            instagramUrl: profile.instagramUrl,
            tiktokUrl: profile.tiktokUrl,
            websiteUrl: profile.websiteUrl,
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

  Future<void> _addCreatorPortfolioMedia(ProfileModel profile) async {
    if (_isAddingPortfolioMedia) return;
    if (profile.role != ProfileRole.creator) {
      _showSnack('Portfolio immagini disponibile per il profilo Creator.');
      return;
    }
    if (profile.role == null ||
        profile.username.trim().isEmpty ||
        profile.location.trim().isEmpty) {
      _showSnack('Completa il profilo prima di aggiungere contenuti.');
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

    final creatorId =
        ref.read(authRepositoryProvider).currentUser?.id ?? profile.id;
    setState(() => _isAddingPortfolioMedia = true);

    try {
      final imageUrl = await ref
          .read(storageServiceProvider)
          .uploadCreatorPortfolioImage(
            creatorId: creatorId,
            bytes: file.bytes!,
            originalFileName: file.name,
          );

      await _insertCreatorPortfolioRow(
        creatorId: creatorId,
        imageUrl: imageUrl,
      );

      if (!mounted) return;
      await _loadPortfolioForProfile(profile, force: true);
      _showSnack('Foto aggiunta al portfolio.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Errore aggiunta foto portfolio: $error');
    } finally {
      if (mounted) {
        setState(() => _isAddingPortfolioMedia = false);
      }
    }
  }

  Future<void> _insertCreatorPortfolioRow({
    required String creatorId,
    required String imageUrl,
  }) async {
    final client = ref.read(supabaseClientProvider);
    final sortOrder = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    try {
      await client.from('creator_media').insert({
        'creator_id': creatorId,
        'image_url': imageUrl,
        'sort_order': sortOrder,
        'is_featured': false,
      });
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) {
        throw StateError('Tabella creator_media non disponibile.');
      }
      if (!_isColumnError(error)) rethrow;

      await client.from('creator_media').insert({
        'creatorId': creatorId,
        'imageUrl': imageUrl,
        'sortOrder': sortOrder,
        'isFeatured': false,
      });
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
    super.build(context);
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

      final nextProfile = next.profile;
      final previousProfile = previous?.profile;
      final previousProfileId = previous?.profile?.id;
      if (nextProfile == null) {
        if (_loadedPortfolioProfileId != null ||
            _portfolioTiles.isNotEmpty ||
            _portfolioError != null ||
            _isLoadingPortfolio ||
            _loadedReviewSummaryProfileId != null ||
            _reviewSummary.totalReviews != 0 ||
            _reviewSummary.averageRating != 0 ||
            _isLoadingReviewSummary) {
          setState(() {
            _loadedPortfolioProfileId = null;
            _portfolioTiles = const <_PortfolioTileData>[];
            _portfolioError = null;
            _isLoadingPortfolio = false;
            _loadedReviewSummaryProfileId = null;
            _reviewSummary = const ReviewSummary(
              averageRating: 0,
              totalReviews: 0,
            );
            _isLoadingReviewSummary = false;
          });
        }
        return;
      }

      if (previousProfile != null && previousProfile.id == nextProfile.id) {
        final nextFollowers = nextProfile.followersCount;
        final nextFollowing = nextProfile.followingCount;
        final shouldSyncLiveCounters =
            (nextFollowers != null && nextFollowers != _liveFollowersCount) ||
            (nextFollowing != null && nextFollowing != _liveFollowingCount);
        if (shouldSyncLiveCounters) {
          setState(() {
            if (nextFollowers != null) _liveFollowersCount = nextFollowers;
            if (nextFollowing != null) _liveFollowingCount = nextFollowing;
          });
          _followCountersCacheByProfileId[nextProfile.id
              .trim()] = _FollowCountersSnapshot(
            followersCount: nextFollowers ?? _liveFollowersCount ?? 0,
            followingCount: nextFollowing ?? _liveFollowingCount ?? 0,
          );
        }
      }

      if (previousProfileId != nextProfile.id) {
        final cleanNextProfileId = nextProfile.id.trim();
        final cached = _followCountersCacheByProfileId[cleanNextProfileId];
        setState(() {
          _loadedFollowCountersProfileId = null;
          _isLoadingFollowCounters = false;
          _liveFollowersCount = cached?.followersCount;
          _liveFollowingCount = cached?.followingCount;
        });
        unawaited(_loadPortfolioForProfile(nextProfile, force: true));
        unawaited(_loadReviewSummaryForProfile(nextProfile.id, force: true));
      }
    });

    final profile = state.profile;
    final isBusy =
        state.isLoading ||
        _isUploadingAvatar ||
        _isAddingPortfolioMedia ||
        _isLoggingOut;

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
                      final socialLinks = _extractLegacySocialLinksFromBio(
                        profile.bio,
                      );
                      final instagramUrl = _normalizeExternalUrl(
                        profile.instagramUrl ?? socialLinks.instagram ?? '',
                      );
                      final tiktokUrl = _normalizeExternalUrl(
                        profile.tiktokUrl ?? socialLinks.tiktok ?? '',
                      );
                      final websiteUrl = _normalizeExternalUrl(
                        profile.websiteUrl ?? socialLinks.website ?? '',
                      );
                      final cleanProfileId = profile.id.trim();
                      final cachedFollowCounters =
                          _followCountersCacheByProfileId[cleanProfileId];
                      if (_loadedFollowCountersProfileId != profile.id &&
                          !_isLoadingFollowCounters) {
                        Future<void>.microtask(() {
                          if (!mounted) return;
                          final latestProfile = ref
                              .read(profileControllerProvider)
                              .profile;
                          if (latestProfile == null) return;
                          unawaited(
                            _loadLiveFollowCountersForProfile(
                              latestProfile.id,
                              force: true,
                            ),
                          );
                        });
                      }

                      final followersCount =
                          _liveFollowersCount ??
                          cachedFollowCounters?.followersCount ??
                          profile.followersCount ??
                          0;
                      final followingCount =
                          _liveFollowingCount ??
                          cachedFollowCounters?.followingCount ??
                          profile.followingCount ??
                          0;
                      final worksCount = profile.completedWorksCount ?? 0;
                      final ratingLabel = _isLoadingReviewSummary
                          ? '...'
                          : _reviewSummary.averageRating.toStringAsFixed(1);

                      if (_loadedPortfolioProfileId != profile.id &&
                          !_isLoadingPortfolio) {
                        Future<void>.microtask(() {
                          if (!mounted) return;
                          final latestProfile = ref
                              .read(profileControllerProvider)
                              .profile;
                          if (latestProfile == null) return;
                          unawaited(
                            _loadPortfolioForProfile(
                              latestProfile,
                              force: true,
                            ),
                          );
                        });
                      }

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: _profileContentDrop,
                                  ),
                                  child: GestureDetector(
                                    onTap: () =>
                                        _openProfileImageViewer(profile),
                                    onLongPress: isBusy
                                        ? null
                                        : () => _changeAvatar(profile),
                                    child: _ProfileHeroBackdrop(
                                      profile: profile,
                                      pendingAvatarBytes: _pendingAvatarBytes,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      height: _profileContentDrop + 48,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(
                                              alpha: 0.26,
                                            ),
                                            Colors.black.withValues(
                                              alpha: 0.76,
                                            ),
                                            Colors.black,
                                          ],
                                          stops: const [0.0, 0.52, 0.8, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: _RoleTagChip(label: specialization),
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
                                        icon: Icons.logout_rounded,
                                        onTap: isBusy
                                            ? null
                                            : _confirmAndLogout,
                                      ),
                                      const SizedBox(width: 8),
                                      _TopActionIconButton(
                                        icon: Icons.add_rounded,
                                        primary: true,
                                        onTap: () =>
                                            _openPrimaryAction(profile),
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
                                      const SizedBox(height: 6),
                                      Text(
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
                                      const SizedBox(height: 10),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _ProfileInfoCard(
                                              location: location,
                                              bioText: bioText,
                                              rating: ratingLabel,
                                              works: '$worksCount',
                                              followersValue: _formatCompact(
                                                followersCount,
                                              ),
                                              followingValue: _formatCompact(
                                                followingCount,
                                              ),
                                              onFollowersTap: () =>
                                                  _openFollowAccounts(
                                                    profile: profile,
                                                    mode: FollowAccountsMode
                                                        .followers,
                                                  ),
                                              onFollowingTap: () =>
                                                  _openFollowAccounts(
                                                    profile: profile,
                                                    mode: FollowAccountsMode
                                                        .following,
                                                  ),
                                              onMainAction: isBusy
                                                  ? null
                                                  : () => _openEdit(profile),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _ProfileSocialRail(
                                            instagramUrl: instagramUrl,
                                            tiktokUrl: tiktokUrl,
                                            websiteUrl: websiteUrl,
                                            onSocialTap: _onSocialTap,
                                          ),
                                        ],
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
                              tiles: _portfolioTiles,
                              isLoading: _isLoadingPortfolio,
                              errorText: _portfolioError,
                              isBrandProfile: profile.role == ProfileRole.brand,
                              isAddingCreatorMedia: _isAddingPortfolioMedia,
                              onAddTap: profile.role == ProfileRole.creator
                                  ? (isBusy
                                        ? null
                                        : () => _addCreatorPortfolioMedia(
                                            profile,
                                          ))
                                  : null,
                              onCampaignTap: _openCampaignDetails,
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
              lower.startsWith('category:') ||
              lower.startsWith('links:') ||
              lower.startsWith('instagram:') ||
              lower.startsWith('tiktok:') ||
              lower.startsWith('sito web:') ||
              lower.startsWith('website:') ||
              lower.startsWith('ruolo:') ||
              lower.startsWith('role:'));
        })
        .toList(growable: false);
    return chunks.isEmpty ? raw : chunks.join('\n\n');
  }

  Future<void> _onSocialTap(String platformLabel, String? rawUrl) async {
    final clean = (rawUrl ?? '').trim();
    if (clean.isEmpty) {
      _showSnack('Link $platformLabel non disponibile.');
      return;
    }

    final normalized = _normalizeExternalUrl(clean);
    if (normalized == null) {
      _showSnack('Link $platformLabel non valido.');
      return;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      _showSnack('Link $platformLabel non valido.');
      return;
    }

    final openedExternally = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (openedExternally) return;

    final openedDefault = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
    );
    if (!openedDefault) {
      _showSnack('Impossibile aprire il link $platformLabel.');
    }
  }

  String? _normalizeExternalUrl(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return null;
    final lower = clean.toLowerCase();
    final candidate =
        lower.startsWith('http://') || lower.startsWith('https://')
        ? clean
        : 'https://$clean';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.trim().isEmpty) return null;
    return uri.replace(fragment: '').toString();
  }

  _LegacySocialLinks _extractLegacySocialLinksFromBio(String rawBio) {
    final text = rawBio.trim();
    if (text.isEmpty) return const _LegacySocialLinks();

    String? instagram;
    String? tiktok;
    String? website;

    final chunks = text.split('\n\n').map((chunk) => chunk.trim());
    for (final chunk in chunks) {
      if (chunk.isEmpty) continue;
      final lowerChunk = chunk.toLowerCase();
      if (lowerChunk.startsWith('links:\n')) {
        final rows = chunk
            .substring('Links:\n'.length)
            .split(RegExp(r'[\r\n]+'))
            .map((row) => row.trim())
            .where((row) => row.isNotEmpty);
        for (final row in rows) {
          final normalized = _normalizeExternalUrl(row);
          if (normalized == null) continue;
          final host = (Uri.tryParse(normalized)?.host ?? '').toLowerCase();
          if (instagram == null && host.contains('instagram.')) {
            instagram = normalized;
            continue;
          }
          if (tiktok == null && host.contains('tiktok.')) {
            tiktok = normalized;
            continue;
          }
          website ??= normalized;
        }
        continue;
      }

      if (lowerChunk.startsWith('instagram:\n')) {
        final candidate = chunk.substring('Instagram:\n'.length).trim();
        final normalized = _normalizeExternalUrl(candidate);
        if (normalized != null) instagram = normalized;
        continue;
      }

      if (lowerChunk.startsWith('tiktok:\n')) {
        final candidate = chunk.substring('TikTok:\n'.length).trim();
        final normalized = _normalizeExternalUrl(candidate);
        if (normalized != null) tiktok = normalized;
        continue;
      }

      if (lowerChunk.startsWith('sito web:\n') ||
          lowerChunk.startsWith('website:\n')) {
        final candidate = chunk.split('\n').skip(1).join('\n').trim();
        final normalized = _normalizeExternalUrl(candidate);
        if (normalized != null) website = normalized;
      }
    }

    return _LegacySocialLinks(
      instagram: instagram,
      tiktok: tiktok,
      website: website,
    );
  }

  String _formatCompact(int value) {
    if (value <= 0) return '0';
    if (value >= 1000000) {
      final millions = value / 1000000;
      return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}M'.replaceAll(
        '.0M',
        'M',
      );
    }
    if (value >= 1000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}K'
          .replaceAll('.0K', 'K');
    }
    return '$value';
  }

  Future<void> _loadReviewSummaryForProfile(
    String profileId, {
    bool force = false,
  }) async {
    final cleanProfileId = profileId.trim();
    if (cleanProfileId.isEmpty) return;

    if (!force &&
        _loadedReviewSummaryProfileId == cleanProfileId &&
        !_isLoadingReviewSummary) {
      return;
    }

    if (mounted) {
      setState(() {
        _loadedReviewSummaryProfileId = cleanProfileId;
        _isLoadingReviewSummary = true;
      });
    }

    try {
      final summary = await ref
          .read(reviewRepositoryProvider)
          .getReceivedSummary(userId: cleanProfileId);
      if (!mounted) return;
      final activeProfileId = ref
          .read(profileControllerProvider)
          .profile
          ?.id
          .trim();
      if (activeProfileId == null || activeProfileId != cleanProfileId) return;

      setState(() {
        _reviewSummary = summary;
        _isLoadingReviewSummary = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviewSummary = const ReviewSummary(averageRating: 0, totalReviews: 0);
        _isLoadingReviewSummary = false;
      });
    }
  }

  Future<void> _loadPortfolioForProfile(
    ProfileModel profile, {
    bool force = false,
  }) async {
    final profileId = profile.id.trim();
    if (profileId.isEmpty) return;

    if (!force &&
        _loadedPortfolioProfileId == profileId &&
        !_isLoadingPortfolio) {
      return;
    }
    if (_isLoadingPortfolio && _loadedPortfolioProfileId == profileId) {
      return;
    }

    setState(() {
      _loadedPortfolioProfileId = profileId;
      _portfolioError = null;
      _portfolioTiles = const <_PortfolioTileData>[];
      _isLoadingPortfolio = true;
    });

    try {
      final tiles = profile.role == ProfileRole.brand
          ? await _fetchBrandCampaignPortfolioTiles(profileId)
          : await _fetchCreatorPortfolioTiles(profileId);
      if (!mounted) return;
      final activeProfileId = ref
          .read(profileControllerProvider)
          .profile
          ?.id
          .trim();
      if (activeProfileId == null || activeProfileId != profileId) {
        return;
      }
      setState(() {
        _portfolioTiles = tiles;
        _portfolioError = null;
        _isLoadingPortfolio = false;
      });
    } catch (_) {
      if (!mounted) return;
      final activeProfileId = ref
          .read(profileControllerProvider)
          .profile
          ?.id
          .trim();
      if (activeProfileId == null || activeProfileId != profileId) {
        return;
      }
      setState(() {
        _portfolioTiles = const <_PortfolioTileData>[];
        _portfolioError = 'Portfolio non disponibile al momento.';
        _isLoadingPortfolio = false;
      });
    }
  }

  Future<List<_PortfolioTileData>> _fetchCreatorPortfolioTiles(
    String profileId,
  ) async {
    final client = ref.read(supabaseClientProvider);
    dynamic raw;

    try {
      raw = await client
          .from('creator_media')
          .select('creator_id, image_url, is_featured, sort_order, created_at')
          .eq('creator_id', profileId)
          .order('is_featured', ascending: false)
          .order('sort_order')
          .order('created_at', ascending: false)
          .limit(12);
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return const <_PortfolioTileData>[];
      if (!_isColumnError(error)) rethrow;

      raw = await client
          .from('creator_media')
          .select('creatorId, imageUrl, sortOrder, createdAt')
          .eq('creatorId', profileId)
          .order('sortOrder')
          .order('createdAt', ascending: false)
          .limit(12);
    }

    final rows = List<Map<String, dynamic>>.from(raw as List);
    return _extractImageTiles(
      rows,
      keys: const ['image_url', 'imageUrl'],
      max: 6,
    );
  }

  Future<List<_PortfolioTileData>> _fetchBrandCampaignPortfolioTiles(
    String profileId,
  ) async {
    final client = ref.read(supabaseClientProvider);
    final rows = await _fetchBrandCampaignRows(client, profileId);
    return _extractCampaignTiles(rows, max: 6);
  }

  Future<List<Map<String, dynamic>>> _fetchBrandCampaignRows(
    SupabaseClient client,
    String profileId,
  ) async {
    const snakeSelectVariants = <String>[
      'id, title, description, category, cash_offer, product_benefit, deadline, min_followers, location_required, cover_image_url, status, applicants_count, views_count, brand_id, created_at, updated_at',
      'id, title, description, category, cash_offer, product_benefit, deadline, min_followers, location_required, cover_image_url, status, applicants_count, brand_id, created_at, updated_at',
      'id, title, description, category, cash_offer, deadline, min_followers, location_required, cover_image_url, status, applicants_count, brand_id, created_at',
      'id, title, description, category, cash_offer, cover_image_url, status, applicants_count, brand_id, created_at',
      'id, title, category, cash_offer, cover_image_url, status, brand_id, created_at',
      'id, title, cover_image_url, status, brand_id, created_at',
    ];
    const camelSelectVariants = <String>[
      'id, title, description, category, cashOffer, productBenefit, deadline, minFollowers, locationRequiredCity, coverImageUrl, status, applicantsCount, viewsCount, brandId, createdAt, updatedAt',
      'id, title, description, category, cashOffer, productBenefit, deadline, minFollowers, locationRequiredCity, coverImageUrl, status, applicantsCount, brandId, createdAt, updatedAt',
      'id, title, description, category, cashOffer, deadline, minFollowers, locationRequiredCity, coverImageUrl, status, applicantsCount, brandId, createdAt',
      'id, title, description, category, cashOffer, coverImageUrl, status, applicantsCount, brandId, createdAt',
      'id, title, category, cashOffer, coverImageUrl, status, brandId, createdAt',
      'id, title, coverImageUrl, status, brandId, createdAt',
    ];

    PostgrestException? lastColumnError;

    for (final fields in snakeSelectVariants) {
      try {
        final raw = await client
            .from('campaigns')
            .select(fields)
            .eq('brand_id', profileId)
            .inFilter('status', const ['active', 'matched', 'completed'])
            .order('created_at', ascending: false)
            .limit(24);
        return List<Map<String, dynamic>>.from(raw as List);
      } on PostgrestException catch (error) {
        if (_isMissingTable(error)) return const <Map<String, dynamic>>[];
        if (!_isColumnError(error)) rethrow;
        lastColumnError = error;
      }
    }

    for (final fields in camelSelectVariants) {
      try {
        final raw = await client
            .from('campaigns')
            .select(fields)
            .eq('brandId', profileId)
            .inFilter('status', const ['active', 'matched', 'completed'])
            .order('createdAt', ascending: false)
            .limit(24);
        return List<Map<String, dynamic>>.from(raw as List);
      } on PostgrestException catch (error) {
        if (_isMissingTable(error)) return const <Map<String, dynamic>>[];
        if (!_isColumnError(error)) rethrow;
        lastColumnError = error;
      }
    }

    if (lastColumnError != null) throw lastColumnError;
    return const <Map<String, dynamic>>[];
  }

  List<_PortfolioTileData> _extractImageTiles(
    List<Map<String, dynamic>> rows, {
    required List<String> keys,
    required int max,
  }) {
    final tiles = <_PortfolioTileData>[];
    final seen = <String>{};
    for (final row in rows) {
      String imageUrl = '';
      for (final key in keys) {
        final value = (row[key] ?? '').toString().trim();
        if (value.isNotEmpty) {
          imageUrl = value;
          break;
        }
      }
      if (imageUrl.isEmpty || !seen.add(imageUrl)) continue;
      tiles.add(_PortfolioTileData(imageUrl: imageUrl));
      if (tiles.length == max) break;
    }
    return tiles;
  }

  List<_PortfolioTileData> _extractCampaignTiles(
    List<Map<String, dynamic>> rows, {
    required int max,
  }) {
    final tiles = <_PortfolioTileData>[];
    for (final row in rows) {
      if (tiles.length == max) break;
      final title = (row['title'] ?? 'Campagna').toString().trim();
      final imageUrl = (row['cover_image_url'] ?? row['coverImageUrl'] ?? '')
          .toString();
      final detail = _CampaignPortfolioDetail.fromMap(row);
      tiles.add(
        _PortfolioTileData(
          imageUrl: imageUrl.trim().isEmpty ? null : imageUrl.trim(),
          title: title.isEmpty ? 'Campagna' : title,
          campaign: detail.id.trim().isEmpty ? null : detail,
        ),
      );
    }
    return tiles;
  }

  void _openCampaignDetails(_CampaignPortfolioDetail campaign) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _CampaignDetailsPage(campaign: campaign),
      ),
    );
  }

  bool _isColumnError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        (message.contains('column') && message.contains('does not exist'));
  }

  bool _isMissingTable(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42P01' ||
        error.code == 'PGRST205' ||
        (message.contains('relation') && message.contains('does not exist'));
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
      clipBehavior: Clip.hardEdge,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: AspectRatio(
        aspectRatio: 1.34,
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
                    Colors.black.withValues(alpha: 0.92),
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.18, 0.4, 0.62, 0.82, 1.0],
                ).createShader(rect),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 11.0, sigmaY: 11.0),
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
                    Colors.black.withValues(alpha: 0.36),
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.56),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.09, 0.22, 0.52, 0.78, 1.0],
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 2,
                child: ColoredBox(color: Colors.black),
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
    this.primary = false,
    this.showBadge = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: primary
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xE02A184C), Color(0xD019102F)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xD61B1230), Color(0xC0120C25)],
                ),
          border: Border.all(
            color: primary
                ? const Color(0xFFF3ECFF).withValues(alpha: 0.82)
                : const Color(0xFFF3ECFF).withValues(alpha: 0.58),
            width: primary ? 1.0 : 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: primary ? 0.42 : 0.34),
              blurRadius: primary ? 10 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              size: primary ? 22 : 20,
              color: const Color(
                0xFFF8F3FF,
              ).withValues(alpha: isEnabled ? 1 : 0.45),
            ),
            if (showBadge)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 6,
                  height: 6,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xD61B1230), Color(0xC0120C25)],
        ),
        border: Border.all(
          color: const Color(0xFFF3ECFF).withValues(alpha: 0.78),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFFF8F3FF),
          height: 1,
          shadows: [
            Shadow(
              color: Color(0xA6000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.location,
    required this.bioText,
    required this.rating,
    required this.works,
    required this.followersValue,
    required this.followingValue,
    this.onFollowersTap,
    this.onFollowingTap,
    this.onMainAction,
  });

  final String location;
  final String bioText;
  final String rating;
  final String works;
  final String followersValue;
  final String followingValue;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onMainAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF8C58F2).withValues(alpha: 0.45),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xD91A1230), Color(0xCA0E0A1D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _TopStat(
                  label: 'Follower',
                  value: followersValue,
                  onTap: onFollowersTap,
                ),
              ),
              Expanded(
                child: _TopStat(
                  label: 'Seguiti',
                  value: followingValue,
                  onTap: onFollowingTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.work_outline_rounded,
                size: 18,
                color: Color(0xFFB376FF),
              ),
              const SizedBox(width: 6),
              Text(
                works,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF4ECFF),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 14,
                color: const Color(0xFF8B5EE8).withValues(alpha: 0.35),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.star_rounded,
                size: 18,
                color: Color(0xFFB376FF),
              ),
              const SizedBox(width: 6),
              Text(
                rating,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF4ECFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            color: const Color(0xFF8B5EE8).withValues(alpha: 0.3),
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
              const Spacer(),
              _PrimaryPillButton(text: 'Modifica', onTap: onMainAction),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE3D5FF),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            bioText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFE1D7F3),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopStat extends StatelessWidget {
  const _TopStat({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.24,
                  color: Color(0xFFE1D5F8),
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF1EAFF),
                  height: 0.95,
                ),
              ),
            ],
          ),
        ),
      ),
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

class _ProfileSocialRail extends StatefulWidget {
  const _ProfileSocialRail({
    required this.instagramUrl,
    required this.tiktokUrl,
    required this.websiteUrl,
    required this.onSocialTap,
  });

  final String? instagramUrl;
  final String? tiktokUrl;
  final String? websiteUrl;
  final Future<void> Function(String platformLabel, String? rawUrl) onSocialTap;

  @override
  State<_ProfileSocialRail> createState() => _ProfileSocialRailState();
}

class _ProfileSocialRailState extends State<_ProfileSocialRail> {
  bool _isExpanded = false;

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  children: [
                    const Text(
                      'SOCIAL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFAA7CFF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: Color(0xFFAA7CFF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            height: _isExpanded ? 136 : 0,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _ProfileSocialDot(
                    isAvailable: (widget.instagramUrl ?? '').trim().isNotEmpty,
                    onTap: () =>
                        widget.onSocialTap('Instagram', widget.instagramUrl),
                    child: const _ProfileInstagramGlyph(),
                  ),
                  const SizedBox(height: 6),
                  _ProfileSocialDot(
                    isAvailable: (widget.tiktokUrl ?? '').trim().isNotEmpty,
                    onTap: () => widget.onSocialTap('TikTok', widget.tiktokUrl),
                    child: const _ProfileTikTokGlyph(),
                  ),
                  const SizedBox(height: 6),
                  _ProfileSocialDot(
                    isAvailable: (widget.websiteUrl ?? '').trim().isNotEmpty,
                    onTap: () =>
                        widget.onSocialTap('Sito web', widget.websiteUrl),
                    child: const Icon(
                      Icons.language_rounded,
                      color: Color(0xFFB98CFF),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSocialDot extends StatelessWidget {
  const _ProfileSocialDot({
    required this.child,
    required this.isAvailable,
    required this.onTap,
  });

  final Widget child;
  final bool isAvailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isAvailable ? 1 : 0.62,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF8E58F3).withValues(alpha: 0.78),
              ),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _ProfileInstagramGlyph extends StatelessWidget {
  const _ProfileInstagramGlyph();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFB98CFF);
    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: color, width: 1.6),
              ),
            ),
          ),
          Align(
            child: Container(
              width: 7.2,
              height: 7.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
            ),
          ),
          Positioned(
            right: 2.4,
            top: 2.4,
            child: Container(
              width: 2.8,
              height: 2.8,
              decoration: const BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTikTokGlyph extends StatelessWidget {
  const _ProfileTikTokGlyph();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFB98CFF);
    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        children: [
          Positioned(
            left: 8.0,
            top: 2.0,
            child: Container(
              width: 2.4,
              height: 8.5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1.2),
              ),
            ),
          ),
          Positioned(
            left: 8.0,
            top: 1.8,
            child: Transform.rotate(
              angle: -0.26,
              alignment: Alignment.centerLeft,
              child: Container(
                width: 6.0,
                height: 2.2,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1.1),
                ),
              ),
            ),
          ),
          Positioned(
            left: 3.0,
            bottom: 2.0,
            child: Container(
              width: 6.8,
              height: 6.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacySocialLinks {
  const _LegacySocialLinks({this.instagram, this.tiktok, this.website});

  final String? instagram;
  final String? tiktok;
  final String? website;
}

class _PortfolioGrid extends StatelessWidget {
  const _PortfolioGrid({
    required this.profileId,
    required this.tiles,
    required this.isLoading,
    required this.isBrandProfile,
    required this.isAddingCreatorMedia,
    this.onCampaignTap,
    this.onAddTap,
    this.errorText,
  });

  final String profileId;
  final List<_PortfolioTileData> tiles;
  final bool isLoading;
  final bool isBrandProfile;
  final bool isAddingCreatorMedia;
  final ValueChanged<_CampaignPortfolioDetail>? onCampaignTap;
  final VoidCallback? onAddTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final showAddTile = !isBrandProfile && onAddTap != null;
    final maxTiles = showAddTile ? 5 : 6;
    final visibleTiles = tiles.take(maxTiles).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF2A2A32).withValues(alpha: 0.72),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE0101016), Color(0xC80A0A0F)],
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 148,
              child: Center(child: SinapsyLogoLoader()),
            )
          : visibleTiles.isEmpty && !showAddTile
          ? SizedBox(
              height: 128,
              child: Center(
                child: Text(
                  errorText?.trim().isNotEmpty == true
                      ? errorText!
                      : isBrandProfile
                      ? 'Nessuna campagna pubblicata nel portfolio.'
                      : 'Nessun contenuto pubblicato nel portfolio.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFC9BCDF),
                  ),
                ),
              ),
            )
          : GridView.builder(
              itemCount: visibleTiles.length + (showAddTile ? 1 : 0),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.06,
              ),
              itemBuilder: (context, index) {
                if (showAddTile && index == 0) {
                  return _PortfolioAddTile(
                    onTap: onAddTap!,
                    isLoading: isAddingCreatorMedia,
                  );
                }
                final dataIndex = showAddTile ? index - 1 : index;
                final tile = visibleTiles[dataIndex];
                final url = (tile.imageUrl ?? '').trim();
                final title = (tile.title ?? 'Campagna').trim();
                final campaign = tile.campaign;
                final canOpenCampaign =
                    campaign != null && onCampaignTap != null;
                final content = ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF16161D), Color(0xFF0E0E14)],
                      ),
                    ),
                    child: url.isNotEmpty
                        ? Image.network(
                            url,
                            key: ValueKey<String>(
                              'portfolio-$profileId-$index-$url',
                            ),
                            fit: BoxFit.cover,
                            gaplessPlayback: false,
                            filterQuality: FilterQuality.low,
                            errorBuilder: (_, _, _) => _PortfolioTileFallback(
                              isBrandProfile: isBrandProfile,
                              title: title,
                            ),
                          )
                        : _PortfolioTileFallback(
                            isBrandProfile: isBrandProfile,
                            title: title,
                          ),
                  ),
                );
                if (!canOpenCampaign) return content;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onCampaignTap?.call(campaign),
                    child: content,
                  ),
                );
              },
            ),
    );
  }
}

class _PortfolioAddTile extends StatelessWidget {
  const _PortfolioAddTile({required this.onTap, required this.isLoading});

  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF16161D), Color(0xFF0E0E14)],
              ),
              border: Border.all(
                color: const Color(0xFF30303A).withValues(alpha: 0.82),
              ),
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: Center(
                        child: CupertinoActivityIndicator(radius: 10),
                      ),
                    )
                  : const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 26,
                      color: Color(0xFFD8C6FF),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortfolioTileData {
  const _PortfolioTileData({this.imageUrl, this.title, this.campaign});

  final String? imageUrl;
  final String? title;
  final _CampaignPortfolioDetail? campaign;
}

class _PortfolioTileFallback extends StatelessWidget {
  const _PortfolioTileFallback({
    required this.isBrandProfile,
    required this.title,
  });

  final bool isBrandProfile;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBrandProfile ? Icons.campaign_outlined : Icons.image_outlined,
              size: 18,
              color: const Color(0xFFD1C2F2).withValues(alpha: 0.85),
            ),
            if (isBrandProfile) ...[
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD7C9F4),
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CampaignPortfolioDetail {
  const _CampaignPortfolioDetail({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.budget,
    this.description,
    this.productBenefit,
    this.deadline,
    this.minFollowers,
    this.locationRequired,
    this.coverImageUrl,
    this.applicantsCount,
    this.viewsCount = 0,
    this.brandId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String category;
  final String status;
  final num budget;
  final String? description;
  final String? productBenefit;
  final DateTime? deadline;
  final int? minFollowers;
  final String? locationRequired;
  final String? coverImageUrl;
  final int? applicantsCount;
  final int viewsCount;
  final String? brandId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory _CampaignPortfolioDetail.fromMap(Map<String, dynamic> map) {
    final title = _string(map['title']) ?? 'Campagna';
    return _CampaignPortfolioDetail(
      id: _string(map['id']) ?? '',
      title: title,
      description: _string(map['description']),
      category: _string(map['category']) ?? 'general',
      budget: _num(map['cash_offer'] ?? map['cashOffer']) ?? 0,
      productBenefit: _string(map['product_benefit'] ?? map['productBenefit']),
      deadline: _dateTime(map['deadline']),
      minFollowers: _int(map['min_followers'] ?? map['minFollowers']),
      locationRequired: _string(
        map['location_required'] ??
            map['locationRequired'] ??
            map['location_required_city'] ??
            map['locationRequiredCity'],
      ),
      coverImageUrl: _string(map['cover_image_url'] ?? map['coverImageUrl']),
      status: _string(map['status']) ?? 'active',
      applicantsCount: _int(map['applicants_count'] ?? map['applicantsCount']),
      viewsCount: _int(map['views_count'] ?? map['viewsCount']) ?? 0,
      brandId: _string(map['brand_id'] ?? map['brandId']),
      createdAt: _dateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: _dateTime(map['updated_at'] ?? map['updatedAt']),
    );
  }

  String get budgetLabel {
    if (budget == budget.roundToDouble()) return 'EUR ${budget.toInt()}';
    return 'EUR ${budget.toStringAsFixed(2)}';
  }

  static String? _string(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    return value;
  }

  static int? _int(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  static num? _num(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw;
    return num.tryParse(raw.toString());
  }

  static DateTime? _dateTime(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }
}

class _CampaignDetailsPage extends StatelessWidget {
  const _CampaignDetailsPage({required this.campaign});

  final _CampaignPortfolioDetail campaign;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LuxuryNeonBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Dettagli campagna',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF3ECFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            height: 180,
                            child: _CampaignCover(campaign: campaign),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFF7A4CDD,
                              ).withValues(alpha: 0.42),
                            ),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xD81B1230), Color(0xCC100B22)],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      campaign.title,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFF2EBFF),
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _CampaignStatusChip(status: campaign.status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _CampaignDetailPill(
                                    icon: Icons.payments_outlined,
                                    text: 'Budget ${campaign.budgetLabel}',
                                  ),
                                  _CampaignDetailPill(
                                    icon: Icons.category_outlined,
                                    text: 'Categoria ${campaign.category}',
                                  ),
                                  if (campaign.applicantsCount != null)
                                    _CampaignDetailPill(
                                      icon: Icons.groups_outlined,
                                      text:
                                          'Candidature ${campaign.applicantsCount}',
                                    ),
                                  _CampaignDetailPill(
                                    icon: Icons.visibility_outlined,
                                    text:
                                        'Visualizzazioni ${campaign.viewsCount}',
                                  ),
                                  if (campaign.minFollowers != null)
                                    _CampaignDetailPill(
                                      icon: Icons.trending_up_rounded,
                                      text:
                                          'Min follower ${campaign.minFollowers}',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if ((campaign.locationRequired ?? '').isNotEmpty)
                                _CampaignInfoLine(
                                  icon: Icons.location_on_outlined,
                                  value: campaign.locationRequired!,
                                ),
                              if (campaign.deadline != null)
                                _CampaignInfoLine(
                                  icon: Icons.event_outlined,
                                  value:
                                      'Deadline ${_formatDate(campaign.deadline!)}',
                                ),
                              if (campaign.createdAt != null)
                                _CampaignInfoLine(
                                  icon: Icons.calendar_today_outlined,
                                  value:
                                      'Creata ${_formatDate(campaign.createdAt!)}',
                                ),
                              if (campaign.updatedAt != null)
                                _CampaignInfoLine(
                                  icon: Icons.update_rounded,
                                  value:
                                      'Aggiornata ${_formatDate(campaign.updatedAt!)}',
                                ),
                              if ((campaign.brandId ?? '').isNotEmpty)
                                _CampaignInfoLine(
                                  icon: Icons.business_outlined,
                                  value: 'Brand ${campaign.brandId}',
                                ),
                              if (campaign.id.trim().isNotEmpty)
                                _CampaignInfoLine(
                                  icon: Icons.fingerprint_rounded,
                                  value: 'ID ${campaign.id}',
                                ),
                              if ((campaign.description ?? '')
                                  .trim()
                                  .isNotEmpty)
                                _CampaignTextSection(
                                  title: 'Descrizione',
                                  text: campaign.description!,
                                ),
                              if ((campaign.productBenefit ?? '')
                                  .trim()
                                  .isNotEmpty)
                                _CampaignTextSection(
                                  title: 'Benefit prodotto',
                                  text: campaign.productBenefit!,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year}';
  }
}

class _CampaignCover extends StatelessWidget {
  const _CampaignCover({required this.campaign});

  final _CampaignPortfolioDetail campaign;

  @override
  Widget build(BuildContext context) {
    final url = (campaign.coverImageUrl ?? '').trim();
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _CampaignCoverFallback(),
      );
    }
    return const _CampaignCoverFallback();
  }
}

class _CampaignCoverFallback extends StatelessWidget {
  const _CampaignCoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF261B3D), Color(0xFF140F25)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.campaign_outlined,
          size: 30,
          color: Color(0xFFDCCBF9),
        ),
      ),
    );
  }
}

class _CampaignStatusChip extends StatelessWidget {
  const _CampaignStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final clean = status.trim().isEmpty
        ? 'active'
        : status.trim().toLowerCase();
    final color = switch (clean) {
      'matched' => const Color(0xFFF6B04A),
      'completed' => const Color(0xFF50D093),
      'cancelled' => const Color(0xFFE56A80),
      _ => const Color(0xFFB66BFF),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        clean,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

class _CampaignDetailPill extends StatelessWidget {
  const _CampaignDetailPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF171427).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF8B5BE6).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFD1A1FF)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFECE2FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignInfoLine extends StatelessWidget {
  const _CampaignInfoLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: const Color(0xFFC99CFF)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFFDFD4F4),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignTextSection extends StatelessWidget {
  const _CampaignTextSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF1E8FF),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFDBD0F2),
              height: 1.35,
            ),
          ),
        ],
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

class _FollowCountersSnapshot {
  const _FollowCountersSnapshot({
    required this.followersCount,
    required this.followingCount,
  });

  final int followersCount;
  final int followingCount;
}
