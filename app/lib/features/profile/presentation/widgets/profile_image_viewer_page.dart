import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ProfileImageViewerPage extends StatelessWidget {
  const ProfileImageViewerPage({this.imageUrl, this.imageBytes, super.key});

  final String? imageUrl;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final hasBytes = imageBytes != null;
    final hasUrl = (imageUrl ?? '').trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF140F24),
                  Color(0xFF08060F),
                  Color(0xFF000000),
                ],
                stops: [0, 0.58, 1],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Ink(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.42),
                        border: Border.all(
                          color: const Color(
                            0xFF9B74E6,
                          ).withValues(alpha: 0.72),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFFF3EEFF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = math
                    .min(constraints.maxWidth - 30, constraints.maxHeight - 140)
                    .clamp(220.0, 520.0)
                    .toDouble();

                return Container(
                  width: side,
                  height: side,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFB88CFF).withValues(alpha: 0.86),
                      width: 1.4,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2A1844), Color(0xFF170D29)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB276FF).withValues(alpha: 0.22),
                        blurRadius: 24,
                        spreadRadius: -8,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: -8,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: const Color(0xFF06050C),
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: hasBytes
                            ? Image.memory(
                                imageBytes!,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              )
                            : hasUrl
                            ? Image.network(
                                imageUrl!,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CupertinoActivityIndicator(
                                      radius: 12,
                                    ),
                                  );
                                },
                                errorBuilder: (_, _, _) => const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 40,
                                    color: Color(0xFFBFA5F5),
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 40,
                                  color: Color(0xFFBFA5F5),
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
