import 'package:flutter/material.dart';

class LuxuryNeonBackdrop extends StatelessWidget {
  const LuxuryNeonBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0E0E12),
            Color(0xFF0B0B0F),
            Color(0xFF09090D),
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
