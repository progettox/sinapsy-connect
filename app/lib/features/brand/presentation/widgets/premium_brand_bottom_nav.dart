import 'dart:ui';

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
    final platform = Theme.of(context).platform;
    final useRealBlur =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    final navSurface = Container(
      height: 82,
      // Glass effect: semi-transparent surface + soft gradient + subtle border.
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xC0101018), Color(0xB00B0B0F)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              active: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.people_alt_rounded,
              active: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ),
          Expanded(
            child: _ProfileNavItem(
              active: currentIndex == 2,
              avatarUrl: profileAvatarUrl,
              profileInitial: profileInitial,
              onTap: () => onTap(2),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.near_me_outlined,
              active: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.insights_rounded,
              active: currentIndex == 4,
              onTap: () => onTap(4),
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: useRealBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: navSurface,
              )
            : navSurface,
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
    final hasAvatar = (avatarUrl ?? '').isNotEmpty;
    final initial = (profileInitial ?? 'B').substring(0, 1).toUpperCase();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Profile tab is intentionally a bit larger than standard icons.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 38 : 34,
              height: active ? 38 : 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? AppTheme.brandAccent
                      : Colors.white.withValues(alpha: 0.28),
                  width: active ? 2 : 1.4,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppTheme.brandAccent.withValues(alpha: 0.32),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: const Color(0xFF1A1A22),
                backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEDEDF8),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 9),
            // Active indicator: thin accent pill for selected tab.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: active ? 16 : 4,
              height: 2.4,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.brandAccent
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
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
    final baseColor = Theme.of(context).colorScheme.onSurface;
    final contentColor = active
        ? const Color(0xFFF3F3F9)
        : baseColor.withValues(alpha: 0.6);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: contentColor),
            const SizedBox(height: 9),
            // Active indicator: thin accent pill for selected tab.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: active ? 16 : 4,
              height: 2.4,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.brandAccent
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
