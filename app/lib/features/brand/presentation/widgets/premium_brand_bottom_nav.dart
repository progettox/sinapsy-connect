import 'package:flutter/material.dart';

class PremiumBrandBottomNav extends StatelessWidget {
  const PremiumBrandBottomNav({
    super.key,
    required this.currentIndex,
    this.profileUserId,
    this.profileAvatarUrl,
    this.profileInitial,
    this.onProfileLongPress,
    required this.onTap,
  });

  final int currentIndex;
  final String? profileUserId;
  final String? profileAvatarUrl;
  final String? profileInitial;
  final VoidCallback? onProfileLongPress;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 26),
      child: SizedBox(
        height: 78,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.search_rounded,
                active: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _CenterProfileNavItem(
                active: currentIndex == 2,
                profileUserId: profileUserId,
                avatarUrl: profileAvatarUrl,
                profileInitial: profileInitial,
                onTap: () => onTap(2),
                onLongPress: onProfileLongPress,
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                active: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                active: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterProfileNavItem extends StatelessWidget {
  const _CenterProfileNavItem({
    required this.active,
    required this.profileUserId,
    required this.avatarUrl,
    required this.profileInitial,
    required this.onTap,
    required this.onLongPress,
  });

  final bool active;
  final String? profileUserId;
  final String? avatarUrl;
  final String? profileInitial;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(2.6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFD5B5FF), Color(0xFF9164EA), Color(0xFF6640BB)],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF766693), Color(0xFF3C3158), Color(0xFF292138)],
                    ),
              border: Border.all(
                color: active
                    ? const Color(0xFFF0DDFF).withValues(alpha: 0.96)
                    : const Color(0xFFBCA7E7).withValues(alpha: 0.32),
                width: active ? 1.9 : 1.2,
              ),
              boxShadow: [
                if (active) ...[
                  BoxShadow(
                    color: const Color(0xFFAD77FF).withValues(alpha: 0.46),
                    blurRadius: 18,
                    spreadRadius: 0.8,
                    offset: const Offset(0, 0),
                  ),
                  BoxShadow(
                    color: const Color(0xFF6F45C5).withValues(alpha: 0.36),
                    blurRadius: 10,
                    spreadRadius: 0.2,
                    offset: const Offset(0, 2),
                  ),
                ],
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xAA1C132F),
                  width: 1.1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.8),
                child: ClipOval(
                  child: _ProfileAvatar(
                    profileUserId: profileUserId,
                    avatarUrl: avatarUrl,
                    profileInitial: profileInitial,
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
    return SizedBox(
      width: 46,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: Icon(
              icon,
              size: 31,
              color: active
                  ? const Color(0xFFEDE2FF)
                  : const Color(0xFFD3C3F1).withValues(alpha: 0.92),
              shadows: active
                  ? [
                      Shadow(
                        color: const Color(0xFF8A5BE0).withValues(alpha: 0.32),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profileUserId,
    required this.avatarUrl,
    required this.profileInitial,
  });

  final String? profileUserId;
  final String? avatarUrl;
  final String? profileInitial;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final userId = profileUserId?.trim() ?? 'unknown';
    if (url != null && url.isNotEmpty) {
      return Image.network(
        key: ValueKey<String>('nav-avatar::$userId::$url'),
        url,
        fit: BoxFit.cover,
        gaplessPlayback: false,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _AvatarFallback(initial: profileInitial),
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
        : 'D';

    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1D4B), Color(0xFF161124)],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFFF4EEFF),
          ),
        ),
      ),
    );
  }
}
