import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class PremiumBrandBottomNav extends StatelessWidget {
  const PremiumBrandBottomNav({
    super.key,
    required this.currentIndex,
    this.profileAvatarUrl,
    this.profileInitial,
    required this.onTap,
  });

  final int currentIndex;
  final String? profileAvatarUrl;
  final String? profileInitial;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 2),
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.home_outlined,
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.search_rounded,
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
            ),
            _ProfileNavItem(
              active: currentIndex == 2,
              avatarUrl: profileAvatarUrl,
              profileInitial: profileInitial,
              onTap: () => onTap(2),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.send_outlined,
                active: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.query_stats_rounded,
                active: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  const _ProfileNavItem({
    required this.active,
    required this.avatarUrl,
    required this.profileInitial,
    required this.onTap,
  });

  final bool active;
  final String? avatarUrl;
  final String? profileInitial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = ClipOval(
      clipBehavior: Clip.antiAlias,
      child: _ProfileAvatar(
        avatarUrl: avatarUrl,
        profileInitial: profileInitial,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: active ? 48 : 42,
          height: active ? 48 : 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFAF6BFF), Color(0xFF6C3FE7)],
                  )
                : null,
          ),
          child: active
              ? Padding(
                  padding: const EdgeInsets.all(2),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF07080F),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: avatar,
                    ),
                  ),
                )
              : avatar,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFFF0E2FF);
    final inactiveColor = AppTheme.colorTextSecondary.withValues(alpha: 0.86);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: active ? 27 : 24,
              color: active ? activeColor : inactiveColor,
              shadows: active
                  ? [
                      Shadow(
                        color: const Color(0xFF9B4EFF).withValues(alpha: 0.34),
                        blurRadius: 5,
                      ),
                    ]
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.avatarUrl, required this.profileInitial});

  final String? avatarUrl;
  final String? profileInitial;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            _AvatarFallback(initial: profileInitial),
      );
    }

    return _AvatarFallback(initial: profileInitial);
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initial});

  final String? initial;

  @override
  Widget build(BuildContext context) {
    final seed = initial?.trim();
    final letter = (seed != null && seed.isNotEmpty)
        ? seed.substring(0, 1).toUpperCase()
        : 'B';

    return Container(
      color: const Color(0xFF1C1630),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Color(0xFFF0E2FF),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
