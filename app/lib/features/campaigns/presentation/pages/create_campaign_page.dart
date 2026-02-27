import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../auth/data/auth_repository.dart';
import '../controllers/create_campaign_controller.dart';

class CreateCampaignPage extends ConsumerStatefulWidget {
  const CreateCampaignPage({super.key});

  @override
  ConsumerState<CreateCampaignPage> createState() => _CreateCampaignPageState();
}

class _CreateCampaignPageState extends ConsumerState<CreateCampaignPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _cashOfferController = TextEditingController();
  final _productBenefitController = TextEditingController();
  final _minFollowersController = TextEditingController();
  final _locationRequiredController = TextEditingController();

  final _stepOneFormKey = GlobalKey<FormState>();
  final _stepTwoFormKey = GlobalKey<FormState>();
  final _stepThreeFormKey = GlobalKey<FormState>();

  int _currentStep = 0;
  DateTime? _deadline;
  Uint8List? _coverBytes;
  String? _coverFileName;
  bool _isUploadingCover = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _cashOfferController.dispose();
    _productBenefitController.dispose();
    _minFollowersController.dispose();
    _locationRequiredController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _showSnack('Impossibile leggere il file selezionato.');
      return;
    }

    setState(() {
      _coverBytes = bytes;
      _coverFileName = file.name;
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initialDate = _deadline ?? now.add(const Duration(days: 7));
    final selected = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      initialDate: initialDate,
    );
    if (selected == null) return;
    setState(() => _deadline = selected);
  }

  Future<void> _onContinue() async {
    if (_currentStep == 0 &&
        !(_stepOneFormKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_currentStep == 1 &&
        !(_stepTwoFormKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_currentStep < 2) {
      setState(() => _currentStep += 1);
      return;
    }

    if (!(_stepThreeFormKey.currentState?.validate() ?? false)) return;
    await _submit();
  }

  void _onCancel() {
    if (_currentStep == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _currentStep -= 1);
  }

  Future<void> _submit() async {
    final cashOffer = num.tryParse(_cashOfferController.text.trim());
    if (cashOffer == null || cashOffer <= 0) {
      _showSnack('Inserisci un budget valido maggiore di 0.');
      return;
    }

    final minFollowersRaw = _minFollowersController.text.trim();
    final minFollowers = minFollowersRaw.isEmpty
        ? null
        : int.tryParse(minFollowersRaw);
    if (minFollowersRaw.isNotEmpty && minFollowers == null) {
      _showSnack('minFollowers deve essere un numero intero.');
      return;
    }

    String? coverImageUrl;
    if (_coverBytes != null && _coverFileName != null) {
      final brandId = ref.read(authRepositoryProvider).currentUser?.id;
      if (brandId == null) {
        _showSnack('Sessione non valida. Effettua di nuovo il login.');
        return;
      }

      setState(() => _isUploadingCover = true);
      try {
        coverImageUrl = await ref
            .read(storageServiceProvider)
            .uploadCampaignCoverImage(
              brandId: brandId,
              bytes: _coverBytes!,
              originalFileName: _coverFileName!,
            );
      } catch (error) {
        if (mounted) {
          _showSnack('Errore upload cover: $error');
        }
        setState(() => _isUploadingCover = false);
        return;
      }
      if (mounted) {
        setState(() => _isUploadingCover = false);
      }
    }

    final id = await ref
        .read(createCampaignControllerProvider.notifier)
        .createCampaign(
          CreateCampaignInput(
            title: _titleController.text,
            description: _descriptionController.text,
            category: _categoryController.text,
            cashOffer: cashOffer,
            productBenefit: _productBenefitController.text,
            deadline: _deadline,
            minFollowers: minFollowers,
            locationRequired: _locationRequiredController.text,
            coverImageUrl: coverImageUrl,
          ),
        );

    if (!mounted || id == null) return;
    _showSnack('Campagna creata.');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createCampaignControllerProvider);

    ref.listen<CreateCampaignState>(createCampaignControllerProvider, (
      previous,
      next,
    ) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(createCampaignControllerProvider.notifier).clearError();
      }
    });

    final isBusy = state.isSubmitting || _isUploadingCover;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Campaign')),
      body: SafeArea(
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: isBusy ? null : _onContinue,
          onStepCancel: isBusy ? null : _onCancel,
          onStepTapped: isBusy
              ? null
              : (index) {
                  setState(() => _currentStep = index);
                },
          controlsBuilder: (context, details) {
            return Row(
              children: [
                ElevatedButton(
                  onPressed: isBusy ? null : details.onStepContinue,
                  child: Text(_currentStep == 2 ? 'Salva' : 'Avanti'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: isBusy ? null : details.onStepCancel,
                  child: Text(_currentStep == 0 ? 'Chiudi' : 'Indietro'),
                ),
                if (isBusy) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: SinapsyLogoLoader(size: 18),
                  ),
                ],
              ],
            );
          },
          steps: [
            Step(
              isActive: _currentStep >= 0,
              title: const Text('Step 1'),
              subtitle: const Text('Base info'),
              content: Form(
                key: _stepOneFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titolo *',
                        border: OutlineInputBorder(),
                      ),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Descrizione *',
                        border: OutlineInputBorder(),
                      ),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Categoria *',
                        border: OutlineInputBorder(),
                      ),
                      validator: _requiredValidator,
                    ),
                  ],
                ),
              ),
            ),
            Step(
              isActive: _currentStep >= 1,
              title: const Text('Step 2'),
              subtitle: const Text('Budget & deadline'),
              content: Form(
                key: _stepTwoFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _cashOfferController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cash offer *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final raw = (value ?? '').trim();
                        if (raw.isEmpty) return 'Campo obbligatorio';
                        final parsed = num.tryParse(raw);
                        if (parsed == null || parsed <= 0) {
                          return 'Inserisci un valore > 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _productBenefitController,
                      decoration: const InputDecoration(
                        labelText: 'Product benefit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Deadline'),
                      subtitle: Text(
                        _deadline == null
                            ? 'Non impostata'
                            : '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: OutlinedButton(
                        onPressed: isBusy ? null : _pickDeadline,
                        child: const Text('Seleziona'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Step(
              isActive: _currentStep >= 2,
              title: const Text('Step 3'),
              subtitle: const Text('Requirements & cover'),
              content: Form(
                key: _stepThreeFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _minFollowersController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'minFollowers',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationRequiredController,
                      decoration: const InputDecoration(
                        labelText: 'locationRequired (opzionale)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _coverFileName == null
                                ? 'Nessuna cover selezionata'
                                : 'Cover: $_coverFileName',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: isBusy ? null : _pickCoverImage,
                          child: const Text('Upload cover'),
                        ),
                      ],
                    ),
                    if (_coverBytes != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _coverBytes!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Campo obbligatorio';
    return null;
  }
}
