import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/widgets/luxury_neon_backdrop.dart';

class BrandProjectsPage extends StatelessWidget {
  const BrandProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: LuxuryNeonBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Projects',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Progetti, match e conversazioni brand',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.66,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: const [
                        _ProjectStubTile(
                          icon: Icons.workspaces_rounded,
                          title: 'Lavori in corso',
                          subtitle: 'Nessun progetto attivo al momento.',
                        ),
                        SizedBox(height: 10),
                        _ProjectStubTile(
                          icon: Icons.chat_bubble_rounded,
                          title: 'Conversazioni',
                          subtitle: 'Le chat attive appariranno qui.',
                        ),
                        SizedBox(height: 10),
                        _ProjectStubTile(
                          icon: Icons.handshake_rounded,
                          title: 'Match recenti',
                          subtitle:
                              'I match creator-brand saranno visibili qui.',
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
    );
  }
}

class _ProjectStubTile extends StatelessWidget {
  const _ProjectStubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xB0101018),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            leading: Icon(icon, color: theme.colorScheme.primary),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(subtitle),
          ),
        ),
      ),
    );
  }
}
