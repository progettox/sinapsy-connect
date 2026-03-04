import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../brand/data/brand_creator_feed_repository.dart';
import '../../../campaigns/data/campaign_model.dart';
import '../../../reviews/data/review_model.dart';
import '../../../reviews/data/review_repository.dart';
import '../../data/profile_model.dart';

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
  bool _isLoading = true;
  bool _isUpdatingFollow = false;
  String? _errorMessage;
  _PublicProfileData? _data;

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

      final loaded = await Future.wait<dynamic>([
        ref.read(reviewRepositoryProvider).getReceivedSummary(userId: targetId),
        _fetchFollowSnapshot(targetId, isCurrentUser: isCurrentUser),
        role == ProfileRole.brand
            ? Future<List<String>>.value(const <String>[])
            : _fetchCreatorMediaUrls(targetId),
        role == ProfileRole.brand
            ? _fetchActiveCampaigns(targetId)
            : Future<List<CampaignModel>>.value(const <CampaignModel>[]),
        _fetchCompletedWorksCount(profileId: targetId, role: role),
      ]);

      final reviewSummary = loaded[0] as ReviewSummary;
      final followSnapshot = loaded[1] as _FollowSnapshot;
      final creatorMedia = loaded[2] as List<String>;
      final activeCampaigns = loaded[3] as List<CampaignModel>;
      final fallbackWorksCount = loaded[4] as int;

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
      final completedWorksCount = storedCompletedWorks ?? fallbackWorksCount;
      final heroImage = _pickHeroImage(
        creatorMedia: creatorMedia,
        activeCampaigns: activeCampaigns,
        avatarUrl: profile.avatarUrl,
      );

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

  int _nextFollowerCount({
    required int current,
    required bool wasFollowing,
    required bool nextFollowing,
  }) {
    if (!wasFollowing && nextFollowing) return current + 1;
    if (wasFollowing && !nextFollowing) return current > 0 ? current - 1 : 0;
    return current;
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
        body: Stack(
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
                _HeroBackdrop(imageUrl: data.heroImageUrl),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Row(
                    children: [
                      _ActionCircleButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      const _ActionCircleButton(icon: Icons.more_horiz_rounded),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 112,
                  child: Column(
                    children: const [
                      Text(
                        'SOCIAL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFAA7CFF),
                        ),
                      ),
                      Icon(Icons.expand_more_rounded, color: Color(0xFFAA7CFF)),
                      _SocialDot(icon: Icons.camera_alt_outlined),
                      SizedBox(height: 8),
                      _SocialDot(icon: Icons.music_note_rounded),
                      SizedBox(height: 8),
                      _SocialDot(icon: Icons.language_rounded),
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
                      Text(
                        data.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF3EEFF),
                          height: 0.95,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RoleChip(label: data.roleLabel),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
                                    label: 'N° FOLLOWER',
                                    value: _formatCompact(data.followersCount),
                                  ),
                                ),
                                Expanded(
                                  child: _TopStat(
                                    label: 'N° SEGUITI',
                                    value: _formatCompact(data.followingCount),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _InlineStat(
                              icon: Icons.work_outline_rounded,
                              label: 'LAVORI COMPLETATI',
                              value: '${data.completedWorksCount}',
                            ),
                            const SizedBox(height: 8),
                            _InlineStat(
                              icon: Icons.star_rounded,
                              label: 'STELLE',
                              value:
                                  '$ratingText (${data.reviewSummary.totalReviews} recensioni)',
                            ),
                            const SizedBox(height: 10),
                            Divider(
                              height: 1,
                              color: const Color(
                                0xFF8B5EE8,
                              ).withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Text(
                                  'Bio',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFF2EAFF),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _RoleChip(label: isBrand ? 'Brand' : 'Creator'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data.location,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFCDBDEB),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data.bioText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFE1D7F3),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!data.isCurrentUser) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _PillButton(
                                text: data.isFollowing ? 'SEGUI GIÀ' : 'SEGUI',
                                onTap: _isUpdatingFollow ? null : _toggleFollow,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _PillButton(
                                text: isBrand
                                    ? 'Contatta Brand'
                                    : 'Richiedi Collaborazione',
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Text(
              isBrand ? 'Campagne Attive' : 'Portfolio',
              style: const TextStyle(
                fontSize: 30,
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
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
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
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              key: ValueKey<String>(
                'creator-grid-${data.profile.id}-$index-$imageUrl',
              ),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const _MediaFallback(icon: Icons.broken_image_outlined),
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
            child: Container(
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
                          ? const _MediaFallback(icon: Icons.campaign_outlined)
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const _MediaFallback(
                                icon: Icons.broken_image_outlined,
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            campaign.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF1E8FF),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Budget ${campaign.budgetLabel}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFD8C9F1),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            campaign.locationRequired?.trim().isNotEmpty == true
                                ? campaign.locationRequired!.trim()
                                : 'Localita non specificata',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFC8B8E6),
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
        },
      ),
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

  Future<int> _fetchCompletedWorksCount({
    required String profileId,
    required ProfileRole? role,
  }) async {
    final client = ref.read(supabaseClientProvider);
    dynamic raw;
    if (role == ProfileRole.brand) {
      try {
        raw = await client
            .from('campaigns')
            .select('id')
            .eq('brand_id', profileId)
            .eq('status', 'completed');
        return _toMaps(raw).length;
      } on PostgrestException catch (error) {
        if (_isMissingTable(error)) return 0;
        if (!_isColumnError(error)) rethrow;
      }
      try {
        raw = await client
            .from('campaigns')
            .select('id')
            .eq('brandId', profileId)
            .eq('status', 'completed');
        return _toMaps(raw).length;
      } on PostgrestException catch (_) {
        return 0;
      }
    }

    try {
      raw = await client
          .from('applications')
          .select('id')
          .eq('applicant_id', profileId)
          .eq('status', 'completed');
      return _toMaps(raw).length;
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return 0;
      if (!_isColumnError(error)) rethrow;
    }
    try {
      raw = await client
          .from('applications')
          .select('id')
          .eq('creator_id', profileId)
          .eq('status', 'completed');
      return _toMaps(raw).length;
    } on PostgrestException catch (_) {
      return 0;
    }
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

  (String?, String) _extractBioInfo(String bio) {
    final text = bio.trim();
    if (text.isEmpty) return (null, 'Nessuna bio disponibile.');
    final category = RegExp(
      r'(specializzazione|tipologia|categoria|category)\s*:\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(text)?.group(2);
    final clean = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where((e) {
          final l = e.toLowerCase();
          return !(l.startsWith('specializzazione:') ||
              l.startsWith('tipologia:') ||
              l.startsWith('categoria:') ||
              l.startsWith('category:'));
        })
        .join('\n');
    return (category?.trim().isEmpty ?? true ? null : category!.trim(), clean);
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

  String? _pickHeroImage({
    required List<String> creatorMedia,
    required List<CampaignModel> activeCampaigns,
    required String? avatarUrl,
  }) {
    final avatar = (avatarUrl ?? '').trim();
    if (avatar.isNotEmpty) return avatar;

    for (final media in creatorMedia) {
      final clean = media.trim();
      if (clean.isNotEmpty) return clean;
    }
    for (final campaign in activeCampaigns) {
      final clean = (campaign.coverImageUrl ?? '').trim();
      if (clean.isNotEmpty) return clean;
    }
    return null;
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
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 712,
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
                    Colors.black.withValues(alpha: 0.95),
                    Colors.black.withValues(alpha: 0.42),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.35, 0.74, 1],
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
                    const Color(0xFF1A1230).withValues(alpha: 0.38),
                    const Color(0xFF120B22).withValues(alpha: 0.62),
                    const Color(0xFF080711).withValues(alpha: 0.84),
                    const Color(0xFF030208),
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

class _ActionCircleButton extends StatelessWidget {
  const _ActionCircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF201D2F), Color(0xFF121221)],
          ),
          border: Border.all(
            color: const Color(0xFF6F648A).withValues(alpha: 0.3),
          ),
        ),
        child: Icon(icon, size: 24, color: const Color(0xFFF3EEFF)),
      ),
    );
  }
}

class _SocialDot extends StatelessWidget {
  const _SocialDot({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF8E58F3).withValues(alpha: 0.78),
        ),
      ),
      child: Icon(icon, color: const Color(0xFFB98CFF), size: 22),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            fontSize: 14,
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
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFD8C9F0),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF1EAFF),
            height: 0.95,
          ),
        ),
      ],
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFB376FF)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE8DDFF),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF4ECFF),
            ),
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
      height: 54,
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
                    fontSize: 16,
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
    );
  }
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
