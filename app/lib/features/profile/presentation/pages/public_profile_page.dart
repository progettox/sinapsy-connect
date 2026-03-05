import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../applications/data/application_repository.dart';
import '../../../brand/data/brand_creator_feed_repository.dart';
import '../../../campaigns/data/campaign_model.dart';
import '../../../campaigns/data/campaign_repository.dart';
import '../../../reviews/data/review_model.dart';
import '../../../reviews/data/review_repository.dart';
import '../../data/profile_model.dart';
import '../widgets/profile_image_viewer_page.dart';

class PublicProfilePage extends ConsumerStatefulWidget {
  const PublicProfilePage({
    required this.profileId,
    this.initialRole,
    this.initialUsername,
    super.key,
  });

  final String profileId;
  final String? initialRole;
  final String? initialUsername;

  @override
  ConsumerState<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends ConsumerState<PublicProfilePage> {
  static const double _edgeSwipeActivationWidth = 26;
  static const double _edgeSwipePopDistance = 72;
  static const double _edgeSwipePopVelocity = 820;
  static const double _profileContentDrop = 130;

  bool _isLoading = true;
  bool _isUpdatingFollow = false;
  ProfileModel? _viewerProfile;
  String? _errorMessage;
  _PublicProfileData? _data;
  bool _isEdgeSwipeActive = false;
  double _edgeSwipeDistance = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<ProfileModel?> _ensureViewerProfile() async {
    if (_viewerProfile != null) return _viewerProfile;
    final currentUserId = ref
        .read(authRepositoryProvider)
        .currentUser
        ?.id
        .trim();
    if (currentUserId == null || currentUserId.isEmpty) return null;
    final row = await _fetchProfileRow(currentUserId);
    if (row == null) return null;
    final profile = ProfileModel.fromMap(row);
    if (mounted) {
      setState(() => _viewerProfile = profile);
    }
    return profile;
  }

  String? _validateCampaignApply({
    required CampaignModel campaign,
    required ProfileModel? viewerProfile,
    required bool isSelfProfile,
  }) {
    if (isSelfProfile) {
      return 'Non puoi candidarti alle tue campagne.';
    }
    if (viewerProfile == null) {
      return 'Completa il tuo profilo creator prima di candidarti.';
    }
    if (viewerProfile.role != ProfileRole.creator) {
      return 'Solo i creator possono inviare richieste.';
    }
    final requiredFollowers = campaign.minFollowers;
    final profileFollowers = viewerProfile.followersCount;
    if (requiredFollowers != null &&
        profileFollowers != null &&
        profileFollowers < requiredFollowers) {
      return 'Richiesti almeno $requiredFollowers follower.';
    }
    return null;
  }

  Future<void> _load() async {
    final targetId = widget.profileId.trim();
    if (targetId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Profilo non valido.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profileRow = await _fetchProfileRow(targetId);
      if (profileRow == null) throw StateError('Profilo non trovato.');

      final profile = ProfileModel.fromMap(profileRow);
      final role = profile.role ?? profileRoleFromString(widget.initialRole);
      final currentUserId = ref
          .read(authRepositoryProvider)
          .currentUser
          ?.id
          .trim();
      final isCurrentUser = currentUserId != null && currentUserId == targetId;
      final bioInfo = _extractBioInfo(profile.bio);
      final legacySocial = _extractLegacySocialLinksFromBio(profile.bio);
      final instagramUrl = _normalizeExternalUrl(
        profile.instagramUrl ?? legacySocial.instagram ?? '',
      );
      final tiktokUrl = _normalizeExternalUrl(
        profile.tiktokUrl ?? legacySocial.tiktok ?? '',
      );
      final websiteUrl = _normalizeExternalUrl(
        profile.websiteUrl ?? legacySocial.website ?? '',
      );

      final loaded = await Future.wait<dynamic>([
        ref.read(reviewRepositoryProvider).getReceivedSummary(userId: targetId),
        _fetchFollowSnapshot(targetId, isCurrentUser: isCurrentUser),
        role == ProfileRole.brand
            ? Future<List<String>>.value(const <String>[])
            : _fetchCreatorMediaUrls(targetId),
        role == ProfileRole.brand
            ? _fetchActiveCampaigns(targetId)
            : Future<List<CampaignModel>>.value(const <CampaignModel>[]),
      ]);

      final reviewSummary = loaded[0] as ReviewSummary;
      final followSnapshot = loaded[1] as _FollowSnapshot;
      final creatorMedia = loaded[2] as List<String>;
      final activeCampaigns = loaded[3] as List<CampaignModel>;

      final followersCount =
          followSnapshot.followersCount ??
          _asInt(
            profileRow['followers_count'] ?? profileRow['followersCount'],
          ) ??
          0;
      final followingCount =
          followSnapshot.followingCount ??
          _asInt(
            profileRow['following_count'] ?? profileRow['followingCount'],
          ) ??
          0;
      final storedCompletedWorks =
          _asInt(
            profileRow['completed_works_count'] ??
                profileRow['completedWorksCount'],
          ) ??
          _asInt(profileRow['completed_works'] ?? profileRow['completedWorks']);
      final completedWorksCount = storedCompletedWorks ?? 0;
      final heroImage = _pickHeroImage(avatarUrl: profile.avatarUrl);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _data = _PublicProfileData(
          profile: profile,
          resolvedRole: role,
          isCurrentUser: isCurrentUser,
          isFollowing: followSnapshot.isFollowing,
          displayName: _displayName(profile),
          roleLabel: _roleLabel(role: role, category: bioInfo.$1),
          bioText: bioInfo.$2,
          location: profile.location.trim().isEmpty
              ? 'Italia'
              : profile.location.trim(),
          followersCount: followersCount < 0 ? 0 : followersCount,
          followingCount: followingCount < 0 ? 0 : followingCount,
          completedWorksCount: completedWorksCount < 0
              ? 0
              : completedWorksCount,
          reviewSummary: reviewSummary,
          creatorMediaUrls: creatorMedia,
          activeCampaigns: activeCampaigns,
          heroImageUrl: heroImage,
          instagramUrl: instagramUrl,
          tiktokUrl: tiktokUrl,
          websiteUrl: websiteUrl,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _data = null;
        _errorMessage = 'Errore caricamento profilo: $error';
      });
    }
  }

  Future<void> _toggleFollow() async {
    final data = _data;
    if (data == null || data.isCurrentUser || _isUpdatingFollow) return;

    final targetId = data.profile.id.trim();
    if (targetId.isEmpty) return;
    final nextFollowing = !data.isFollowing;

    setState(() {
      _isUpdatingFollow = true;
      _data = data.copyWith(
        isFollowing: nextFollowing,
        followersCount: _nextFollowerCount(
          current: data.followersCount,
          wasFollowing: data.isFollowing,
          nextFollowing: nextFollowing,
        ),
      );
    });

    try {
      await ref
          .read(brandCreatorFeedRepositoryProvider)
          .setFollowing(creatorId: targetId, isFollowing: nextFollowing);
      final refreshed = await _fetchFollowSnapshot(
        targetId,
        isCurrentUser: false,
      );
      if (!mounted) return;
      setState(() {
        _isUpdatingFollow = false;
        _data = _data?.copyWith(
          isFollowing: refreshed.isFollowing,
          followersCount: refreshed.followersCount ?? _data!.followersCount,
          followingCount: refreshed.followingCount ?? _data!.followingCount,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isUpdatingFollow = false;
        _data = data;
      });
      _showSnack('Impossibile aggiornare il follow: $error');
    }
  }

  Future<void> _openProfileImageViewer(_PublicProfileData data) async {
    final avatarUrl = (data.profile.avatarUrl ?? '').trim();
    final heroUrl = (data.heroImageUrl ?? '').trim();
    final imageUrl = avatarUrl.isNotEmpty ? avatarUrl : heroUrl;
    if (imageUrl.isEmpty) {
      _showSnack('Nessuna foto profilo disponibile.');
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileImageViewerPage(imageUrl: imageUrl),
      ),
    );
  }

  int _nextFollowerCount({
    required int current,
    required bool wasFollowing,
    required bool nextFollowing,
  }) {
    if (!wasFollowing && nextFollowing) return current + 1;
    if (wasFollowing && !nextFollowing) return current > 0 ? current - 1 : 0;
    return current;
  }

  void _resetEdgeSwipe() {
    _isEdgeSwipeActive = false;
    _edgeSwipeDistance = 0;
  }

  void _handleEdgeSwipeBack() {
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    navigator.maybePop();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isEdgeSwipeActive = details.globalPosition.dx <= _edgeSwipeActivationWidth;
    _edgeSwipeDistance = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isEdgeSwipeActive) return;
    final delta = details.primaryDelta ?? 0;
    if (delta <= 0) {
      _edgeSwipeDistance = 0;
      return;
    }
    _edgeSwipeDistance += delta;
    if (_edgeSwipeDistance >= _edgeSwipePopDistance) {
      _resetEdgeSwipe();
      _handleEdgeSwipeBack();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldPop = _isEdgeSwipeActive && velocity > _edgeSwipePopVelocity;
    _resetEdgeSwipe();
    if (shouldPop) {
      _handleEdgeSwipeBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageTheme = theme.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(theme.textTheme),
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(
        theme.primaryTextTheme,
      ),
      scaffoldBackgroundColor: Colors.transparent,
    );

    return Theme(
      data: pageTheme,
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onHorizontalDragCancel: _resetEdgeSwipe,
          child: Stack(
            children: [
              const Positioned.fill(child: LuxuryNeonBackdrop()),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: _buildBody(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: SinapsyLogoLoader());
    }
    if (_data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'Profilo non disponibile.'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Riprova')),
            ],
          ),
        ),
      );
    }

    final data = _data!;
    final isBrand = data.resolvedRole == ProfileRole.brand;
    final ratingText = data.reviewSummary.averageRating.toStringAsFixed(1);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: _profileContentDrop),
                  child: GestureDetector(
                    onTap: () => _openProfileImageViewer(data),
                    child: _HeroBackdrop(imageUrl: data.heroImageUrl),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: _profileContentDrop + 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.22),
                            Colors.black.withValues(alpha: 0.62),
                            Colors.black.withValues(alpha: 0.9),
                            Colors.black,
                          ],
                          stops: const [0.0, 0.28, 0.66, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ActionCircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF3EEFF),
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _RoleChip(label: data.roleLabel),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: const Color(
                                    0xFF8C58F2,
                                  ).withValues(alpha: 0.45),
                                ),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xD91A1230),
                                    Color(0xCA0E0A1D),
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _TopStat(
                                          label: 'N\u00B0 FOLLOWER',
                                          value: _formatCompact(
                                            data.followersCount,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: _TopStat(
                                          label: 'N\u00B0 SEGUITI',
                                          value: _formatCompact(
                                            data.followingCount,
                                          ),
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
                                        '${data.completedWorksCount}',
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
                                        color: const Color(
                                          0xFF8B5EE8,
                                        ).withValues(alpha: 0.35),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 18,
                                        color: Color(0xFFB376FF),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        ratingText,
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
                                    height: 1,
                                    color: const Color(
                                      0xFF8B5EE8,
                                    ).withValues(alpha: 0.3),
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
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    data.location,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFE3D5FF),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    data.bioText,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFE1D7F3),
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SocialRail(
                            instagramUrl: data.instagramUrl,
                            tiktokUrl: data.tiktokUrl,
                            websiteUrl: data.websiteUrl,
                            onSocialTap: _onSocialTap,
                          ),
                        ],
                      ),
                      if (!data.isCurrentUser) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _FollowCompactButton(
                              isFollowing: data.isFollowing,
                              isSaving: _isUpdatingFollow,
                              onTap: _toggleFollow,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PillButton(
                                text: isBrand ? 'Contatta Brand' : 'Collabora',
                                onTap: () => _showSnack(
                                  'Azione collaborazione disponibile nei prossimi step.',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              isBrand ? 'Campagne Attive' : 'Portfolio',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEDE5FF),
              ),
            ),
          ),
        ),
        if (!isBrand)
          _buildCreatorMediaSliver(data)
        else
          _buildBrandCampaignsSliver(data),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
      ],
    );
  }

  Widget _buildCreatorMediaSliver(_PublicProfileData data) {
    if (data.creatorMediaUrls.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: _EmptyCard(
            text: 'Questo creator non ha ancora pubblicato contenuti.',
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final imageUrl = data.creatorMediaUrls[index];
          final heroTag = _creatorMediaHeroTag(
            profileId: data.profile.id,
            index: index,
            imageUrl: imageUrl,
          );
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () =>
                  _openCreatorMediaViewer(data: data, initialIndex: index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Hero(
                  tag: heroTag,
                  child: Image.network(
                    imageUrl,
                    key: ValueKey<String>(
                      'creator-grid-${data.profile.id}-$index-$imageUrl',
                    ),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const _MediaFallback(icon: Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          );
        }, childCount: data.creatorMediaUrls.length),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
      ),
    );
  }

  Future<void> _openCreatorMediaViewer({
    required _PublicProfileData data,
    required int initialIndex,
  }) async {
    final mediaUrls = data.creatorMediaUrls;
    if (mediaUrls.isEmpty) return;

    final safeIndex = initialIndex.clamp(0, mediaUrls.length - 1);

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _CreatorMediaViewerPage(
              profileId: data.profile.id,
              mediaUrls: mediaUrls,
              initialIndex: safeIndex,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildBrandCampaignsSliver(_PublicProfileData data) {
    if (data.activeCampaigns.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: _EmptyCard(
            text: 'Questo brand non ha campagne attive al momento.',
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList.builder(
        itemCount: data.activeCampaigns.length,
        itemBuilder: (context, index) {
          final campaign = data.activeCampaigns[index];
          final imageUrl = (campaign.coverImageUrl ?? '').trim();
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == data.activeCampaigns.length - 1 ? 0 : 10,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openBrandCampaignDetails(campaign),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF7A46E2).withValues(alpha: 0.52),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xD61A1230), Color(0xC50E0A1D)],
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(20),
                        ),
                        child: SizedBox(
                          width: 108,
                          height: 108,
                          child: imageUrl.isEmpty
                              ? const _MediaFallback(
                                  icon: Icons.campaign_outlined,
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const _MediaFallback(
                                        icon: Icons.broken_image_outlined,
                                      ),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                campaign.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF1E8FF),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Budget ${campaign.budgetLabel}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFD8C9F1),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                campaign.locationRequired?.trim().isNotEmpty ==
                                        true
                                    ? campaign.locationRequired!.trim()
                                    : 'Localita non specificata',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFC8B8E6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tocca per vedere dettagli',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFBFA6F0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openBrandCampaignDetails(CampaignModel campaign) async {
    final data = _data;
    if (data == null) return;
    final campaignId = campaign.id.trim();
    if (campaignId.isNotEmpty) {
      Future<void>.microtask(
        () => ref.read(campaignRepositoryProvider).trackCampaignViews(<String>[
          campaignId,
        ]),
      );
    }

    final viewerProfile = await _ensureViewerProfile();
    if (!mounted) return;

    final isCreatorViewer =
        viewerProfile != null &&
        viewerProfile.role == ProfileRole.creator &&
        !data.isCurrentUser;
    final applyValidation = _validateCampaignApply(
      campaign: campaign,
      viewerProfile: viewerProfile,
      isSelfProfile: data.isCurrentUser,
    );

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E091B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final description = (campaign.description ?? '').trim();
            final details = <String>[
              if (campaign.minFollowers != null)
                'Follower minimi: ${campaign.minFollowers}',
              if ((campaign.locationRequired ?? '').trim().isNotEmpty)
                'Localita: ${campaign.locationRequired!.trim()}',
              'Categoria: ${campaign.category}',
              'Stato: ${campaign.status}',
              'Visualizzazioni: ${campaign.viewsCount}',
            ];

            Future<void> onApply() async {
              if (applyValidation != null || isSubmitting) return;
              setModalState(() => isSubmitting = true);
              try {
                await ref
                    .read(applicationRepositoryProvider)
                    .applyToCampaign(campaign);
                if (!context.mounted) return;
                Navigator.of(context).maybePop();
                if (!mounted) return;
                _showSnack('Richiesta inviata con successo.');
              } catch (error) {
                if (!mounted) return;
                if (context.mounted) {
                  setModalState(() => isSubmitting = false);
                }
                _showSnack('Richiesta non inviata: $error');
              }
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E7AAF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        campaign.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF1E8FF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Budget ${campaign.budgetLabel}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD8C9F1),
                        ),
                      ),
                      if ((campaign.coverImageUrl ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            campaign.coverImageUrl!.trim(),
                            width: double.infinity,
                            height: 190,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 190,
                              color: const Color(0xFF1D1333),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFFC8B8E6),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Descrizione',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE8D9FF),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: Color(0xFFD3C3F2),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      const Text(
                        'Dettagli',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE8D9FF),
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final item in details)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '- $item',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFD3C3F2),
                            ),
                          ),
                        ),
                      if (isCreatorViewer) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting || applyValidation != null
                                ? null
                                : onApply,
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: SinapsyLogoLoader(size: 18),
                                  )
                                : const Text('Invia richiesta'),
                          ),
                        ),
                        if (applyValidation != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            applyValidation,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFE3B4B4),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Chiudi'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchProfileRow(String profileId) async {
    final client = ref.read(supabaseClientProvider);
    dynamic row;
    try {
      row = await client
          .from('profiles')
          .select()
          .eq('id', profileId)
          .maybeSingle();
      if (row != null) return _toMap(row);
    } on PostgrestException catch (error) {
      if (!_isColumnError(error)) rethrow;
    }
    try {
      row = await client
          .from('profiles')
          .select()
          .eq('user_id', profileId)
          .maybeSingle();
      if (row != null) return _toMap(row);
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return null;
      if (!_isColumnError(error)) rethrow;
    }
    return null;
  }

  Future<List<String>> _fetchCreatorMediaUrls(String profileId) async {
    final client = ref.read(supabaseClientProvider);
    dynamic raw;
    try {
      raw = await client
          .from('creator_media')
          .select()
          .eq('creator_id', profileId)
          .limit(200);
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return const <String>[];
      if (!_isColumnError(error)) rethrow;
      raw = await client
          .from('creator_media')
          .select()
          .eq('creatorId', profileId)
          .limit(200);
    }

    final rows = _toMaps(raw);
    rows.sort((a, b) {
      final af = _asBool(a['is_featured'] ?? a['isFeatured']);
      final bf = _asBool(b['is_featured'] ?? b['isFeatured']);
      if (af != bf) return bf ? 1 : -1;
      final ao = _asInt(a['sort_order'] ?? a['sortOrder']) ?? 9999;
      final bo = _asInt(b['sort_order'] ?? b['sortOrder']) ?? 9999;
      if (ao != bo) return ao.compareTo(bo);
      final ad = _asDate(a['created_at'] ?? a['createdAt']);
      final bd = _asDate(b['created_at'] ?? b['createdAt']);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    final urls = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      final url = _asString(row['image_url'] ?? row['imageUrl']) ?? '';
      if (url.isEmpty || !seen.add(url)) continue;
      urls.add(url);
    }
    return urls;
  }

  Future<List<CampaignModel>> _fetchActiveCampaigns(String profileId) async {
    final client = ref.read(supabaseClientProvider);
    dynamic raw;
    try {
      raw = await client
          .from('campaigns')
          .select()
          .eq('brand_id', profileId)
          .eq('status', 'active')
          .limit(120);
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return const <CampaignModel>[];
      if (!_isColumnError(error)) rethrow;
      raw = await client
          .from('campaigns')
          .select()
          .eq('brandId', profileId)
          .eq('status', 'active')
          .limit(120);
    }
    final campaigns = _toMaps(raw)
        .map(CampaignModel.fromMap)
        .where((it) => it.id.trim().isNotEmpty)
        .toList(growable: false);
    final sorted = campaigns.toList(growable: false)
      ..sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

    return sorted;
  }

  Future<_FollowSnapshot> _fetchFollowSnapshot(
    String profileId, {
    required bool isCurrentUser,
  }) async {
    if (isCurrentUser) return const _FollowSnapshot(isFollowing: false);
    try {
      final counters = await ref
          .read(brandCreatorFeedRepositoryProvider)
          .getFollowCounters(creatorId: profileId);
      return _FollowSnapshot(
        isFollowing: counters.isFollowing,
        followersCount: counters.followersCount,
        followingCount: counters.followingCount,
      );
    } catch (_) {
      return const _FollowSnapshot(isFollowing: false);
    }
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

  (String?, String) _extractBioInfo(String bio) {
    final text = bio.trim();
    if (text.isEmpty) return (null, 'Nessuna bio disponibile.');
    final category = RegExp(
      r'(specializzazione|tipologia|categoria|category)\s*:\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(text)?.group(2);
    final roleOnlyLine = RegExp(
      r'^(brand|creator|creatore|service|servizio|azienda)$',
      caseSensitive: false,
    );
    final filteredChunks = text
        .split('\n\n')
        .map((chunk) => chunk.trim())
        .where((chunk) => chunk.isNotEmpty)
        .where((chunk) {
          final lower = chunk.toLowerCase();
          return !(lower.startsWith('specializzazione:\n') ||
              lower.startsWith('tipologia:\n') ||
              lower.startsWith('categoria:\n') ||
              lower.startsWith('category:\n') ||
              lower.startsWith('links:\n') ||
              lower.startsWith('instagram:\n') ||
              lower.startsWith('tiktok:\n') ||
              lower.startsWith('sito web:\n') ||
              lower.startsWith('website:\n') ||
              lower.startsWith('ruolo:\n') ||
              lower.startsWith('role:\n'));
        })
        .toList(growable: false);
    final clean = filteredChunks
        .join('\n\n')
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((e) {
          final l = e.toLowerCase();
          return !(l.startsWith('specializzazione:') ||
              l.startsWith('tipologia:') ||
              l.startsWith('categoria:') ||
              l.startsWith('category:') ||
              l.startsWith('links:') ||
              l.startsWith('instagram:') ||
              l.startsWith('tiktok:') ||
              l.startsWith('sito web:') ||
              l.startsWith('website:') ||
              l.startsWith('ruolo:') ||
              l.startsWith('role:') ||
              roleOnlyLine.hasMatch(l));
        })
        .join('\n');
    return (category?.trim().isEmpty ?? true ? null : category!.trim(), clean);
  }

  _LegacySocialLinks _extractLegacySocialLinksFromBio(String rawBio) {
    final text = rawBio.trim();
    if (text.isEmpty) {
      return const _LegacySocialLinks();
    }

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
        if (normalized != null) {
          instagram = normalized;
        }
        continue;
      }

      if (lowerChunk.startsWith('tiktok:\n')) {
        final candidate = chunk.substring('TikTok:\n'.length).trim();
        final normalized = _normalizeExternalUrl(candidate);
        if (normalized != null) {
          tiktok = normalized;
        }
        continue;
      }

      if (lowerChunk.startsWith('sito web:\n') ||
          lowerChunk.startsWith('website:\n')) {
        final candidate = chunk.split('\n').skip(1).join('\n').trim();
        final normalized = _normalizeExternalUrl(candidate);
        if (normalized != null) {
          website = normalized;
        }
      }
    }

    return _LegacySocialLinks(
      instagram: instagram,
      tiktok: tiktok,
      website: website,
    );
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

  String _displayName(ProfileModel profile) {
    final full = [
      (profile.firstName ?? '').trim(),
      (profile.lastName ?? '').trim(),
    ].where((e) => e.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    final username = profile.username.trim();
    if (username.isNotEmpty) return username;
    final initial = (widget.initialUsername ?? '').trim();
    return initial.isEmpty ? 'Utente' : initial;
  }

  String _roleLabel({required ProfileRole? role, required String? category}) {
    if ((category ?? '').trim().isNotEmpty) {
      return category!.trim().toUpperCase();
    }
    if (role == ProfileRole.brand) return 'BRAND';
    if (role == ProfileRole.creator) return 'CREATOR';
    final fallback = (widget.initialRole ?? '').trim();
    return fallback.isEmpty ? 'PROFILO' : fallback.toUpperCase();
  }

  String? _pickHeroImage({required String? avatarUrl}) {
    final avatar = (avatarUrl ?? '').trim();
    return avatar.isEmpty ? null : avatar;
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

  List<Map<String, dynamic>> _toMaps(dynamic raw) {
    final list = raw is List ? raw : const <dynamic>[];
    return list.whereType<Object>().map(_toMap).toList(growable: false);
  }

  Map<String, dynamic> _toMap(Object raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', value));
    }
    throw StateError('Formato dati non valido.');
  }

  String? _asString(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? null : value;
  }

  int? _asInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  bool _asBool(dynamic raw) {
    if (raw is bool) return raw;
    final value = (raw ?? '').toString().trim().toLowerCase();
    return value == 'true' || value == '1' || value == 't';
  }

  DateTime? _asDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
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

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = (imageUrl ?? '').trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 0.84,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) =>
                    const _MediaFallback(icon: Icons.person_outline_rounded),
              )
            else
              const _MediaFallback(icon: Icons.person_outline_rounded),
            if (hasImage)
              ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withValues(alpha: 0.98),
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.20, 0.50, 0.78, 1.0],
                ).createShader(rect),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 11, sigmaY: 11),
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
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
                    Colors.black.withValues(alpha: 0.3),
                    const Color(0xFF090611).withValues(alpha: 0.9),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.3, 0.54, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCircleButton extends StatelessWidget {
  const _ActionCircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        splashColor: const Color(0x26FFFFFF),
        highlightColor: const Color(0x14FFFFFF),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFFF3EEFF),
            shadows: const [
              Shadow(
                color: Color(0x6622183A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialDot extends StatelessWidget {
  const _SocialDot({
    required this.child,
    required this.onTap,
    required this.isAvailable,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool isAvailable;

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

class _SocialRail extends StatefulWidget {
  const _SocialRail({
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
  State<_SocialRail> createState() => _SocialRailState();
}

class _SocialRailState extends State<_SocialRail> {
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
                  _SocialDot(
                    isAvailable: (widget.instagramUrl ?? '').trim().isNotEmpty,
                    onTap: () =>
                        widget.onSocialTap('Instagram', widget.instagramUrl),
                    child: const _InstagramGlyph(),
                  ),
                  const SizedBox(height: 6),
                  _SocialDot(
                    isAvailable: (widget.tiktokUrl ?? '').trim().isNotEmpty,
                    onTap: () => widget.onSocialTap('TikTok', widget.tiktokUrl),
                    child: const _TikTokGlyph(),
                  ),
                  const SizedBox(height: 6),
                  _SocialDot(
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

class _InstagramGlyph extends StatelessWidget {
  const _InstagramGlyph();

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

class _TikTokGlyph extends StatelessWidget {
  const _TikTokGlyph();

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

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x5A8D4AFF), Color(0x3A4E2B8A)],
          ),
          border: Border.all(
            color: const Color(0xFFBE91FF).withValues(alpha: 0.52),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE8DDFF),
          ),
        ),
      ),
    );
  }
}

class _TopStat extends StatelessWidget {
  const _TopStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFFD8C9F0),
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
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
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
                : const [Color(0xFF9963FF), Color(0xFF7647E6)],
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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(
                      0xFFF7F2FF,
                    ).withValues(alpha: onTap == null ? 0.6 : 1),
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

class _FollowCompactButton extends StatelessWidget {
  const _FollowCompactButton({
    required this.isFollowing,
    required this.isSaving,
    required this.onTap,
  });

  final bool isFollowing;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isFollowing ? 'Non seguire più' : 'Segui creator',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isSaving ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF6F648A).withValues(alpha: 0.45),
              ),
            ),
            child: isSaving
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(child: SinapsyLogoLoader(size: 14)),
                  )
                : Icon(
                    isFollowing
                        ? Icons.person_remove_alt_1_rounded
                        : Icons.person_add_alt_1_rounded,
                    size: 21,
                    color: isFollowing
                        ? const Color(0xFFB98CFF)
                        : const Color(0xFFF3EEFF),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1A43), Color(0xFF140E24)],
        ),
      ),
      child: Center(
        child: Icon(icon, color: const Color(0xFFCCAFFF), size: 26),
      ),
    );
  }
}

class _CreatorMediaViewerPage extends StatefulWidget {
  const _CreatorMediaViewerPage({
    required this.profileId,
    required this.mediaUrls,
    required this.initialIndex,
  });

  final String profileId;
  final List<String> mediaUrls;
  final int initialIndex;

  @override
  State<_CreatorMediaViewerPage> createState() =>
      _CreatorMediaViewerPageState();
}

class _CreatorMediaViewerPageState extends State<_CreatorMediaViewerPage> {
  static const double _dismissSwipeDistance = 120;
  static const double _dismissSwipeMinDistanceForVelocity = 36;
  static const double _dismissSwipeVelocity = 980;
  static const double _dismissDirectionRatio = 1.15;

  late final PageController _pageController;
  late int _currentIndex;
  int _pointerCount = 0;
  bool _multiTouchDetected = false;
  int? _activePointer;
  Offset? _dragStart;
  DateTime? _dragStartedAt;
  double _maxDownDistance = 0;
  double _maxHorizontalDistance = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.mediaUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (_currentIndex == index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _resetDismissTracking() {
    _activePointer = null;
    _dragStart = null;
    _dragStartedAt = null;
    _maxDownDistance = 0;
    _maxHorizontalDistance = 0;
    _multiTouchDetected = false;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount += 1;
    if (_pointerCount > 1) {
      _multiTouchDetected = true;
      return;
    }

    _activePointer = event.pointer;
    _dragStart = event.position;
    _dragStartedAt = DateTime.now();
    _maxDownDistance = 0;
    _maxHorizontalDistance = 0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) return;
    final start = _dragStart;
    if (start == null) return;

    final verticalDistance = event.position.dy - start.dy;
    final horizontalDistance = (event.position.dx - start.dx).abs();
    if (horizontalDistance > _maxHorizontalDistance) {
      _maxHorizontalDistance = horizontalDistance;
    }
    if (verticalDistance > _maxDownDistance) {
      _maxDownDistance = verticalDistance;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointerCount > 0) _pointerCount -= 1;
    if (_activePointer != event.pointer) {
      if (_pointerCount == 0) _resetDismissTracking();
      return;
    }

    final startedAt = _dragStartedAt;
    final elapsedMs = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt).inMilliseconds;
    final elapsedSeconds = elapsedMs <= 0 ? 0.0 : elapsedMs / 1000.0;
    final verticalVelocity = elapsedSeconds <= 0
        ? 0.0
        : _maxDownDistance / elapsedSeconds;

    final hasVerticalIntent =
        _maxDownDistance > _maxHorizontalDistance * _dismissDirectionRatio;
    final reachedDistance = _maxDownDistance >= _dismissSwipeDistance;
    final reachedVelocity =
        _maxDownDistance >= _dismissSwipeMinDistanceForVelocity &&
        verticalVelocity >= _dismissSwipeVelocity;
    final shouldDismiss =
        !_multiTouchDetected &&
        hasVerticalIntent &&
        (reachedDistance || reachedVelocity);

    if (shouldDismiss) {
      Navigator.of(context).maybePop();
    }

    _resetDismissTracking();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_pointerCount > 0) _pointerCount -= 1;
    if (_pointerCount == 0 || _activePointer == event.pointer) {
      _resetDismissTracking();
    }
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.42),
            border: Border.all(
              color: const Color(0xFF8462C8).withValues(alpha: 0.62),
            ),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFF3EEFF)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF160F28),
                    Color(0xFF05040A),
                    Color(0xFF000000),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
            PageView.builder(
              controller: _pageController,
              itemCount: widget.mediaUrls.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final imageUrl = widget.mediaUrls[index];
                final heroTag = _creatorMediaHeroTag(
                  profileId: widget.profileId,
                  index: index,
                  imageUrl: imageUrl,
                );
                return Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Hero(
                      tag: heroTag,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            width: 34,
                            height: 34,
                            child: Center(
                              child: CupertinoActivityIndicator(radius: 11),
                            ),
                          );
                        },
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 180,
                          height: 220,
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(22)),
                            child: _MediaFallback(
                              icon: Icons.broken_image_outlined,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, right: 12),
                  child: _buildTopIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 102),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF8462C8).withValues(alpha: 0.58),
                      ),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${widget.mediaUrls.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEADFFF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 82,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF7B55C2).withValues(alpha: 0.48),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xB2171128), Color(0xA40C0918)],
                    ),
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.mediaUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final thumbUrl = widget.mediaUrls[index];
                      final selected = index == _currentIndex;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _goToPage(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: selected ? 60 : 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFB98CFF)
                                    : const Color(
                                        0xFF7D62A8,
                                      ).withValues(alpha: 0.45),
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.network(
                                thumbUrl,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                                errorBuilder: (_, _, _) => const _MediaFallback(
                                  icon: Icons.image_outlined,
                                ),
                              ),
                            ),
                          ),
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
}

String _creatorMediaHeroTag({
  required String profileId,
  required int index,
  required String imageUrl,
}) {
  return 'creator-media-$profileId-$index-$imageUrl';
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF7040CF).withValues(alpha: 0.3),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xB1150E29), Color(0xAA0F0A1E)],
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFFD0C1F1),
        ),
      ),
    );
  }
}

class _PublicProfileData {
  const _PublicProfileData({
    required this.profile,
    required this.resolvedRole,
    required this.isCurrentUser,
    required this.isFollowing,
    required this.displayName,
    required this.roleLabel,
    required this.bioText,
    required this.location,
    required this.followersCount,
    required this.followingCount,
    required this.completedWorksCount,
    required this.reviewSummary,
    required this.creatorMediaUrls,
    required this.activeCampaigns,
    required this.heroImageUrl,
    required this.instagramUrl,
    required this.tiktokUrl,
    required this.websiteUrl,
  });

  final ProfileModel profile;
  final ProfileRole? resolvedRole;
  final bool isCurrentUser;
  final bool isFollowing;
  final String displayName;
  final String roleLabel;
  final String bioText;
  final String location;
  final int followersCount;
  final int followingCount;
  final int completedWorksCount;
  final ReviewSummary reviewSummary;
  final List<String> creatorMediaUrls;
  final List<CampaignModel> activeCampaigns;
  final String? heroImageUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? websiteUrl;

  _PublicProfileData copyWith({
    bool? isFollowing,
    int? followersCount,
    int? followingCount,
  }) {
    return _PublicProfileData(
      profile: profile,
      resolvedRole: resolvedRole,
      isCurrentUser: isCurrentUser,
      isFollowing: isFollowing ?? this.isFollowing,
      displayName: displayName,
      roleLabel: roleLabel,
      bioText: bioText,
      location: location,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      completedWorksCount: completedWorksCount,
      reviewSummary: reviewSummary,
      creatorMediaUrls: creatorMediaUrls,
      activeCampaigns: activeCampaigns,
      heroImageUrl: heroImageUrl,
      instagramUrl: instagramUrl,
      tiktokUrl: tiktokUrl,
      websiteUrl: websiteUrl,
    );
  }
}

class _LegacySocialLinks {
  const _LegacySocialLinks({this.instagram, this.tiktok, this.website});

  final String? instagram;
  final String? tiktok;
  final String? website;
}

class _FollowSnapshot {
  const _FollowSnapshot({
    required this.isFollowing,
    this.followersCount,
    this.followingCount,
  });

  final bool isFollowing;
  final int? followersCount;
  final int? followingCount;
}
