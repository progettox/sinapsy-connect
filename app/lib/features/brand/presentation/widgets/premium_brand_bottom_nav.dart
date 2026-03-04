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
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: SizedBox(
        height: 72,
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
              icon: Icons.send_rounded,
              active: currentIndex == 3,
              onTap: () => onTap(3),
              rotateRadians: -0.45,
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              active: currentIndex == 4,
              onTap: () => onTap(4),
            ),
          ],
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
      offset: const Offset(0, -3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: active
                    ? const [Color(0xFFA96BFF), Color(0xFF6F3ADF)]
                    : const [Color(0xFF7A58C8), Color(0xFF473284)],
              ),
              boxShadow: [
                if (active)
                  BoxShadow(
                    color: const Color(0xFF8A50FF).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.34),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
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
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.active,
    required this.onTap,
    this.rotateRadians = 0,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final double rotateRadians;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: rotateRadians,
                child: Icon(
                  icon,
                  size: 34,
                  color: active
                      ? const Color(0xFFF4EEFF)
                      : Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 22,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: active
                      ? const Color(0xFF9A5BFF)
                      : const Color(0xFF7A7693).withValues(alpha: 0.45),
                ),
              ),
            ],
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
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFFF4EEFF),
          ),
        ),
      ),
    );
  }
}
