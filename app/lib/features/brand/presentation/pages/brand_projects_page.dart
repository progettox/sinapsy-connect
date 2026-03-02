import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../campaigns/presentation/pages/brand_home_page.dart';

class BrandProjectsPage extends StatelessWidget {
  const BrandProjectsPage({super.key});

  Future<void> _openActive(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ActiveCampaignsPage()),
    );
  }

  Future<void> _openMatched(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MatchedCampaignsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, VoidCallback onTap})>[
      (
        icon: Icons.workspaces_rounded,
        title: 'Lavori in corso',
        onTap: () => _openActive(context),
      ),
      (
        icon: Icons.chat_bubble_rounded,
        title: 'Conversazioni',
        onTap: () => _openMatched(context),
      ),
      (
        icon: Icons.handshake_rounded,
        title: 'Match recenti',
        onTap: () => _openMatched(context),
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: LuxuryNeonBackdrop()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _ProjectStubTile(
                          icon: item.icon,
                          title: item.title,
                          onTap: item.onTap,
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
    );
  }
}

class _ProjectStubTile extends StatelessWidget {
  const _ProjectStubTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.colorBgSecondary, AppTheme.colorBgCard],
            ),
            border: Border.all(
              color: AppTheme.colorStrokeSubtle.withValues(alpha: 0.92),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.colorAccentPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.colorAccentPrimary.withValues(alpha: 0.42),
                  ),
                ),
                child: Icon(icon, size: 22, color: AppTheme.colorAccentPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.colorTextPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.colorTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
