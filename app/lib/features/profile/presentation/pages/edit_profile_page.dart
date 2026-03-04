import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/storage/storage_service.dart';
import '../../../../core/widgets/sinapsy_confirm_dialog.dart';
import '../../../../core/widgets/luxury_neon_backdrop.dart';
import '../../../../core/widgets/sinapsy_logo_loader.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/profile_model.dart';
import '../controllers/profile_controller.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({required this.profile, super.key});

  final ProfileModel profile;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  static const double _edgeSwipeActivationWidth = 26;
  static const double _edgeSwipePopDistance = 72;
  static const double _edgeSwipePopVelocity = 820;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _instagramController;
  late final TextEditingController _tiktokController;
  late final TextEditingController _websiteController;
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  bool _isEdgeSwipeActive = false;
  double _edgeSwipeDistance = 0;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.profile.username);
    _bioController = TextEditingController(text: widget.profile.bio);
    _locationController = TextEditingController(text: widget.profile.location);
    _instagramController = TextEditingController(
      text: widget.profile.instagramUrl ?? '',
    );
    _tiktokController = TextEditingController(
      text: widget.profile.tiktokUrl ?? '',
    );
    _websiteController = TextEditingController(
      text: widget.profile.websiteUrl ?? '',
    );
    _avatarUrl = widget.profile.avatarUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final fixedRole = widget.profile.role ?? ProfileRole.creator;
    var avatarUrl = (_avatarUrl ?? '').trim();
    final instagramRaw = _instagramController.text.trim();
    final instagramUrl = instagramRaw.isEmpty
        ? null
        : _normalizeInstagramUrl(instagramRaw);
    if (instagramRaw.isNotEmpty && instagramUrl == null) {
      _showSnack('Link Instagram non valido.');
      return;
    }
    final tiktokRaw = _tiktokController.text.trim();
    final tiktokUrl = tiktokRaw.isEmpty ? null : _normalizeTiktokUrl(tiktokRaw);
    if (tiktokRaw.isNotEmpty && tiktokUrl == null) {
      _showSnack('Link TikTok non valido.');
      return;
    }
    final websiteRaw = _websiteController.text.trim();
    final websiteUrl = _normalizeWebsiteUrl(websiteRaw);
    if (websiteRaw.isNotEmpty && websiteUrl == null) {
      _showSnack('Il link sito web non e valido.');
      return;
    }

    if (_avatarBytes != null && _avatarFileName != null) {
      final userId =
          ref.read(authRepositoryProvider).currentUser?.id ?? widget.profile.id;

      setState(() => _isUploadingAvatar = true);
      try {
        avatarUrl = await ref
            .read(storageServiceProvider)
            .uploadProfileAvatar(
              userId: userId,
              bytes: _avatarBytes!,
              originalFileName: _avatarFileName!,
            );
      } catch (error) {
        if (!mounted) return;
        setState(() => _isUploadingAvatar = false);
        _showSnack('Errore caricamento foto profilo: $error');
        return;
      }

      if (!mounted) return;
      setState(() {
        _avatarUrl = avatarUrl;
        _avatarBytes = null;
        _avatarFileName = null;
        _isUploadingAvatar = false;
      });
    }

    final profile = await ref
        .read(profileControllerProvider.notifier)
        .upsertMyProfile(
          role: fixedRole,
          username: _usernameController.text,
          location: _locationController.text,
          bio: _bioController.text,
          avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
          instagramUrl: instagramUrl,
          tiktokUrl: tiktokUrl,
          websiteUrl: websiteUrl,
        );
    if (!mounted || profile == null) return;

    Navigator.of(context).pop();
  }

  String? _validateRequired(String? value, String fieldName) {
    if ((value ?? '').trim().isEmpty) return '$fieldName obbligatorio';
    return null;
  }

  String? _normalizeInstagramUrl(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;

    var candidate = input;
    final lower = input.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      if (!(lower.contains('instagram.com') || lower.contains('instagr.am'))) {
        return null;
      }
      candidate = 'https://$input';
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.trim().isEmpty) return null;
    final host = uri.host.toLowerCase();
    final isInstagramHost =
        host == 'instagram.com' ||
        host == 'www.instagram.com' ||
        host.endsWith('.instagram.com') ||
        host == 'instagr.am' ||
        host == 'www.instagr.am';
    if (!isInstagramHost) return null;
    final path = uri.path.trim().isEmpty ? '/' : uri.path;
    return uri.replace(path: path, fragment: '').toString();
  }

  String? _normalizeTiktokUrl(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;

    var candidate = input;
    final lower = input.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      if (!lower.contains('tiktok.com')) return null;
      candidate = 'https://$input';
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.trim().isEmpty) return null;
    final host = uri.host.toLowerCase();
    final isTikTokHost =
        host == 'tiktok.com' ||
        host == 'www.tiktok.com' ||
        host.endsWith('.tiktok.com');
    if (!isTikTokHost) return null;
    final path = uri.path.trim().isEmpty ? '/' : uri.path;
    return uri.replace(path: path, fragment: '').toString();
  }

  String? _normalizeWebsiteUrl(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;
    final candidate =
        input.toLowerCase().startsWith('http://') ||
            input.toLowerCase().startsWith('https://')
        ? input
        : 'https://$input';
    final uri = Uri.tryParse(candidate);
    if (uri == null || uri.host.trim().isEmpty) return null;
    return uri.replace(fragment: '').toString();
  }

  String? _validateInstagramInput(String? value) {
    final clean = (value ?? '').trim();
    if (clean.isEmpty) return null;
    if (_normalizeInstagramUrl(clean) == null) {
      return 'Inserisci il link completo Instagram (es. https://instagram.com/...)';
    }
    return null;
  }

  String? _validateTiktokInput(String? value) {
    final clean = (value ?? '').trim();
    if (clean.isEmpty) return null;
    if (_normalizeTiktokUrl(clean) == null) {
      return 'Inserisci il link completo TikTok (es. https://www.tiktok.com/@...)';
    }
    return null;
  }

  String? _validateWebsiteInput(String? value) {
    final clean = (value ?? '').trim();
    if (clean.isEmpty) return null;
    if (_normalizeWebsiteUrl(clean) == null) {
      return 'Inserisci un link sito valido';
    }
    return null;
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _showSnack('Impossibile leggere il file selezionato.');
      return;
    }

    setState(() {
      _avatarBytes = file.bytes;
      _avatarFileName = file.name;
    });
  }

  void _resetEdgeSwipe() {
    _isEdgeSwipeActive = false;
    _edgeSwipeDistance = 0;
  }

  void _handleEdgeSwipeBack() {
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    navigator.maybePop();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isEdgeSwipeActive = details.globalPosition.dx <= _edgeSwipeActivationWidth;
    _edgeSwipeDistance = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isEdgeSwipeActive) return;
    final delta = details.primaryDelta ?? 0;
    if (delta <= 0) {
      _edgeSwipeDistance = 0;
      return;
    }
    _edgeSwipeDistance += delta;
    if (_edgeSwipeDistance >= _edgeSwipePopDistance) {
      _resetEdgeSwipe();
      _handleEdgeSwipeBack();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldPop = _isEdgeSwipeActive && velocity > _edgeSwipePopVelocity;
    _resetEdgeSwipe();
    if (shouldPop) {
      _handleEdgeSwipeBack();
    }
  }

  Future<void> _removeAvatar() async {
    final hasAvatar =
        _avatarBytes != null || (_avatarUrl ?? '').trim().isNotEmpty;
    if (!hasAvatar) return;

    final shouldRemove = await showSinapsyConfirmDialog(
      context: context,
      title: 'Rimuovere la foto profilo?',
      message: 'La foto verrà rimossa quando salvi le modifiche.',
      cancelLabel: 'Annulla',
      confirmLabel: 'Rimuovi',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!shouldRemove || !mounted) return;

    setState(() {
      _avatarBytes = null;
      _avatarFileName = null;
      _avatarUrl = null;
    });
    _showSnack('Foto rimossa. Premi "Salva modifiche" per confermare.');
  }

  Widget _buildAvatarPicker({required bool isBusy, required ProfileRole role}) {
    final placeholderIcon = role == ProfileRole.brand
        ? Icons.storefront_rounded
        : Icons.auto_awesome_rounded;
    final cleanAvatarUrl = (_avatarUrl ?? '').trim();
    final hasAvatar = _avatarBytes != null || cleanAvatarUrl.isNotEmpty;

    Widget avatar;
    if (_avatarBytes != null) {
      avatar = ClipOval(
        child: Image.memory(
          _avatarBytes!,
          fit: BoxFit.cover,
          width: 108,
          height: 108,
        ),
      );
    } else if (cleanAvatarUrl.isNotEmpty) {
      avatar = ClipOval(
        child: Image.network(
          cleanAvatarUrl,
          fit: BoxFit.cover,
          width: 108,
          height: 108,
          errorBuilder: (_, _, _) => Icon(placeholderIcon, size: 34),
        ),
      );
    } else {
      avatar = Icon(placeholderIcon, size: 34);
    }

    return Column(
      children: [
        GestureDetector(
          onTap: isBusy ? null : _pickAvatar,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x2817102F),
                  border: Border.all(
                    color: const Color(0xA58C5FF0),
                    width: 1.2,
                  ),
                ),
                child: Center(child: avatar),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF8D5BFF),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    size: 18,
                    color: Color(0xFFF7F1FF),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: OutlinedButton.icon(
            onPressed: isBusy || !hasAvatar ? null : _removeAvatar,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE7B6C8),
              side: BorderSide(
                color: const Color(
                  0xFFE7B6C8,
                ).withValues(alpha: hasAvatar ? 0.55 : 0.24),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: Text(
              hasAvatar ? 'Rimuovi foto' : 'Nessuna foto da rimuovere',
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final theme = Theme.of(context);
    final fixedRole = widget.profile.role ?? ProfileRole.creator;
    final isBusy = state.isLoading || _isUploadingAvatar;
    final pageTheme = theme.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(theme.textTheme),
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(
        theme.primaryTextTheme,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x2A140E2A),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFD8C8F3),
        ),
        floatingLabelStyle: theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFFAE82FF),
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFF8C58F2).withValues(alpha: 0.32),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFF8C58F2).withValues(alpha: 0.32),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFFAA7BFF).withValues(alpha: 0.88),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE28888)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE28888)),
        ),
      ),
    );

    ref.listen<ProfileUiState>(profileControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        _showSnack(next.errorMessage!);
        ref.read(profileControllerProvider.notifier).clearError();
      }
    });

    return Theme(
      data: pageTheme,
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onHorizontalDragCancel: _resetEdgeSwipe,
          child: Stack(
            children: [
              const Positioned.fill(child: LuxuryNeonBackdrop()),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _ActionCircleButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _GlassPanel(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        TextFormField(
                                          initialValue: fixedRole.label,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                            labelText: 'Ruolo',
                                            suffixIcon: Icon(
                                              Icons.lock_outline_rounded,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Align(
                                          alignment: Alignment.center,
                                          child: _buildAvatarPicker(
                                            isBusy: isBusy,
                                            role: fixedRole,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        TextFormField(
                                          controller: _usernameController,
                                          decoration: const InputDecoration(
                                            labelText: 'Username',
                                          ),
                                          validator: (value) =>
                                              _validateRequired(
                                                value,
                                                'Username',
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _bioController,
                                          minLines: 3,
                                          maxLines: 5,
                                          decoration: const InputDecoration(
                                            labelText: 'Bio',
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _locationController,
                                          decoration: const InputDecoration(
                                            labelText: 'Sede',
                                          ),
                                          validator: (value) =>
                                              _validateRequired(value, 'Sede'),
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _instagramController,
                                          keyboardType: TextInputType.url,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Link Instagram (opzionale)',
                                          ),
                                          validator: _validateInstagramInput,
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _tiktokController,
                                          keyboardType: TextInputType.url,
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Link TikTok (opzionale)',
                                          ),
                                          validator: _validateTiktokInput,
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _websiteController,
                                          keyboardType: TextInputType.url,
                                          textInputAction: TextInputAction.done,
                                          decoration: const InputDecoration(
                                            labelText: 'Sito web (opzionale)',
                                          ),
                                          validator: _validateWebsiteInput,
                                        ),
                                        const SizedBox(height: 18),
                                        _PrimaryActionButton(
                                          text: 'Salva modifiche',
                                          onTap: isBusy ? null : _save,
                                        ),
                                        if (isBusy) ...[
                                          const SizedBox(height: 14),
                                          const Center(
                                            child: SinapsyLogoLoader(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF8C58F2).withValues(alpha: 0.28),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xD01A1230), Color(0xC0100B22), Color(0xAA130C28)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x70050412),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ActionCircleButton extends StatelessWidget {
  const _ActionCircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 20,
        splashColor: const Color(0x26FFFFFF),
        highlightColor: const Color(0x14FFFFFF),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFFF3EEFF),
            shadows: const [
              Shadow(
                color: Color(0x6622183A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: onTap == null
                ? [
                    const Color(0xFF7C5AB4).withValues(alpha: 0.34),
                    const Color(0xFF5D4388).withValues(alpha: 0.34),
                  ]
                : const [Color(0xFF8D5BFF), Color(0xFF6E41DA)],
          ),
          border: Border.all(
            color: const Color(0xFFE6D9FF).withValues(alpha: 0.24),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(
                    0xFFF7F2FF,
                  ).withValues(alpha: onTap == null ? 0.6 : 1),
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
