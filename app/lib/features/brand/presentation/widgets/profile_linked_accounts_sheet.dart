import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/sinapsy_confirm_dialog.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/saved_accounts_store.dart';
import '../../../profile/data/profile_model.dart';
import '../../../profile/data/profile_repository.dart';

class ProfileLinkedAccountsSheet extends ConsumerStatefulWidget {
  const ProfileLinkedAccountsSheet({required this.activeProfile, super.key});

  final ProfileModel activeProfile;

  @override
  ConsumerState<ProfileLinkedAccountsSheet> createState() =>
      _ProfileLinkedAccountsSheetState();
}

class _ProfileLinkedAccountsSheetState
    extends ConsumerState<ProfileLinkedAccountsSheet> {
  bool _isLoading = true;
  bool _isMutating = false;
  String? _activeUserId;
  List<SavedAccount> _savedAccounts = const <SavedAccount>[];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadAccounts);
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    await _rememberCurrentAccount(profileOverride: widget.activeProfile);
    final accounts = await ref.read(savedAccountsStoreProvider).load();
    final activeUserId = ref.read(authRepositoryProvider).currentUser?.id;
    if (!mounted) return;
    setState(() {
      _savedAccounts = accounts;
      _activeUserId = activeUserId;
      _isLoading = false;
    });
  }

  Future<void> _rememberCurrentAccount({ProfileModel? profileOverride}) async {
    final authRepository = ref.read(authRepositoryProvider);
    final session = authRepository.currentSession;
    final user = authRepository.currentUser;
    final refreshToken = session?.refreshToken?.trim() ?? '';
    if (user == null || refreshToken.isEmpty) return;

    ProfileModel? profile = profileOverride;
    if (profile == null || profile.id.trim() != user.id.trim()) {
      try {
        profile = await ref.read(profileRepositoryProvider).getMyProfile();
      } catch (_) {}
    }

    await ref
        .read(savedAccountsStoreProvider)
        .upsert(
          SavedAccount(
            userId: user.id.trim(),
            refreshToken: refreshToken,
            email: user.email?.trim(),
            username: profile?.username.trim(),
            role: profile?.role?.value,
            avatarUrl: profile?.avatarUrl?.trim(),
            location: profile?.location.trim(),
            updatedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> _switchToAccount(SavedAccount target) async {
    if (_isMutating) return;
    if ((_activeUserId ?? '').trim() == target.userId.trim()) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isMutating = true);
    try {
      await _rememberCurrentAccount(profileOverride: widget.activeProfile);
      await ref
          .read(authRepositoryProvider)
          .setSessionWithRefreshToken(target.refreshToken);
      await _rememberCurrentAccount();

      if (!mounted) return;
      setState(() => _isMutating = false);
      Navigator.of(context).pop();
      context.go(AppRouter.splashPath);
    } on AuthException {
      if (!mounted) return;
      setState(() => _isMutating = false);
      _showSnack(
        'Sessione non valida o scaduta. Il profilo collegato non e stato rimosso: accedi di nuovo per aggiornarlo.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isMutating = false);
      _showSnack('Errore cambio account: $error');
    }
  }

  Future<void> _removeSavedAccount(SavedAccount account) async {
    if (_isMutating) return;
    if ((_activeUserId ?? '').trim() == account.userId.trim()) {
      _showSnack('Non puoi rimuovere l\'account attivo.');
      return;
    }
    setState(() => _isMutating = true);
    try {
      final next = await ref
          .read(savedAccountsStoreProvider)
          .removeByUserId(account.userId);
      if (!mounted) return;
      setState(() {
        _savedAccounts = next;
        _isMutating = false;
      });
      _showSnack('Account rimosso dal dispositivo.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isMutating = false);
      _showSnack('Errore rimozione account: $error');
    }
  }

  Future<void> _confirmAndRemoveSavedAccount(SavedAccount account) async {
    if (_isMutating) return;

    final username = (account.username ?? '').trim();
    final email = (account.email ?? '').trim();
    final accountLabel = username.isNotEmpty
        ? '@$username'
        : (email.isNotEmpty ? email : 'questo account');

    final shouldRemove = await showSinapsyConfirmDialog(
      context: context,
      title: 'Rimuovere profilo collegato?',
      message:
          'Stai per rimuovere $accountLabel da questo dispositivo. Potrai aggiungerlo di nuovo effettuando l\'accesso.',
      cancelLabel: 'Annulla',
      confirmLabel: 'Rimuovi',
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (!shouldRemove || !mounted) return;

    await _removeSavedAccount(account);
  }

  Future<void> _openAddAccountSheet() async {
    if (_isMutating) return;
    final action = await showModalBottomSheet<_AccountAuthAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddAccountSheet(),
    );
    if (!mounted || action == null) return;

    setState(() => _isMutating = true);
    try {
      await _rememberCurrentAccount(profileOverride: widget.activeProfile);
      final authRepository = ref.read(authRepositoryProvider);

      if (action.mode == _AccountAuthMode.signIn) {
        await authRepository.signInWithEmail(
          email: action.email,
          password: action.password,
        );
      } else {
        await authRepository.signUpWithEmail(
          email: action.email,
          password: action.password,
        );
        var hasSession = authRepository.currentSession != null;
        if (!hasSession) {
          await authRepository.signInWithEmail(
            email: action.email,
            password: action.password,
          );
          hasSession = authRepository.currentSession != null;
        }
        if (!hasSession) {
          if (!mounted) return;
          setState(() => _isMutating = false);
          _showSnack(
            'Account creato. Verifica la mail e poi accedi per completare il profilo.',
          );
          return;
        }
      }

      await _rememberCurrentAccount();
      if (!mounted) return;
      setState(() => _isMutating = false);
      Navigator.of(context).pop();
      context.go(AppRouter.splashPath);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _isMutating = false);
      _showSnack(error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isMutating = false);
      _showSnack('Errore aggiunta account: $error');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactiveSavedAccounts = _savedAccounts
        .where(
          (account) => account.userId.trim() != (_activeUserId ?? '').trim(),
        )
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.8,
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(
                color: const Color(0xFF9FC8F8).withValues(alpha: 0.2),
              ),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xE01A2A3D), Color(0xDC0E1828)],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Account',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFFEAF3FF),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              physics: const BouncingScrollPhysics(),
                              children: [
                                _AccountTile(
                                  title: '@${widget.activeProfile.username}',
                                  subtitle: widget.activeProfile.location,
                                  avatarUrl: widget.activeProfile.avatarUrl,
                                  badge: 'Attivo',
                                  onTap: null,
                                ),
                                const SizedBox(height: 12),
                                if (inactiveSavedAccounts.isEmpty)
                                  const Text(
                                    'Nessun account salvato su questo dispositivo.',
                                  ),
                                ...inactiveSavedAccounts.map((account) {
                                  final username = (account.username ?? '')
                                      .trim();
                                  final email = (account.email ?? '').trim();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _AccountTile(
                                      title: username.isNotEmpty
                                          ? '@$username'
                                          : email,
                                      subtitle: (account.location ?? '').trim(),
                                      avatarUrl: account.avatarUrl,
                                      badge: account.roleLabel,
                                      onTap: _isMutating
                                          ? null
                                          : () => _switchToAccount(account),
                                      trailing: IconButton(
                                        onPressed: _isMutating
                                            ? null
                                            : () =>
                                                  _confirmAndRemoveSavedAccount(
                                                    account,
                                                  ),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _isMutating ? null : _openAddAccountSheet,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          _isMutating ? 'Aggiorno...' : 'Aggiungi profilo',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF8EC8FF,
                          ).withValues(alpha: 0.2),
                          foregroundColor: const Color(0xFFEAF3FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.badge,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? avatarUrl;
  final String badge;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final clean = avatarUrl?.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF9FC8F8).withValues(alpha: 0.18),
            ),
            color: const Color(0xFF0E182A).withValues(alpha: 0.7),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: clean != null && clean.isNotEmpty
                    ? NetworkImage(clean)
                    : null,
                child: clean == null || clean.isEmpty
                    ? Text(
                        title.trim().isEmpty
                            ? 'S'
                            : title.trim().substring(0, 1).toUpperCase(),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Utente' : title,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFFEAF3FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle.isEmpty ? 'Profilo salvato' : subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFCFE6FF).withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFF8EC8FF).withValues(alpha: 0.14),
                  border: Border.all(
                    color: const Color(0xFF9FC8F8).withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  badge,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFEAF3FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ..._optionalTrailing(trailing),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _optionalTrailing(Widget? trailingWidget) {
    if (trailingWidget == null) return const <Widget>[];
    return <Widget>[trailingWidget];
  }
}

class _AddAccountSheet extends StatefulWidget {
  const _AddAccountSheet();

  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreateMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _AccountAuthAction(
        mode: _isCreateMode ? _AccountAuthMode.signUp : _AccountAuthMode.signIn,
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.66,
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              color: const Color(0xEE102033),
              border: Border.all(
                color: const Color(0xFF9FC8F8).withValues(alpha: 0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isCreateMode ? 'Crea account' : 'Accedi account',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Switch(
                          value: _isCreateMode,
                          onChanged: (value) =>
                              setState(() => _isCreateMode = value),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) return 'Email obbligatoria';
                        if (!email.contains('@')) return 'Email non valida';
                        return null;
                      },
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      validator: (value) {
                        if ((value ?? '').length < 6) {
                          return 'Minimo 6 caratteri';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: _submit,
                        child: Text(
                          _isCreateMode
                              ? 'Crea e usa profilo'
                              : 'Accedi e usa profilo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AccountAuthMode { signIn, signUp }

class _AccountAuthAction {
  const _AccountAuthAction({
    required this.mode,
    required this.email,
    required this.password,
  });

  final _AccountAuthMode mode;
  final String email;
  final String password;
}
