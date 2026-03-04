import 'package:flutter/material.dart';

class ReviewComposerResult {
  const ReviewComposerResult({required this.rating, this.text});

  final int rating;
  final String? text;
}

Future<ReviewComposerResult?> showReviewComposerDialog({
  required BuildContext context,
  required String title,
  required String message,
  bool mandatory = false,
}) async {
  final noteController = TextEditingController();
  var selectedRating = 0;
  try {
    return await showDialog<ReviewComposerResult>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (context) {
        return PopScope(
          canPop: !mandatory,
          child: StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(title),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(message),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(5, (index) {
                          final value = index + 1;
                          final isSelected = value <= selectedRating;
                          return IconButton(
                            onPressed: () =>
                                setState(() => selectedRating = value),
                            icon: Icon(
                              isSelected
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: isSelected
                                  ? const Color(0xFFFFC857)
                                  : Colors.grey.shade500,
                              size: 32,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedRating == 0
                            ? 'Seleziona un voto da 1 a 5'
                            : 'Voto selezionato: $selectedRating/5',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        minLines: 2,
                        maxLines: 4,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Commento (opzionale)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (!mandatory)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annulla'),
                    ),
                  FilledButton(
                    onPressed: selectedRating == 0
                        ? null
                        : () {
                            final note = noteController.text.trim();
                            Navigator.of(context).pop(
                              ReviewComposerResult(
                                rating: selectedRating,
                                text: note.isEmpty ? null : note,
                              ),
                            );
                          },
                    child: const Text('Invia review'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  } finally {
    noteController.dispose();
  }
}
