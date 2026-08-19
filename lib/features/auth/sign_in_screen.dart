import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/feedback.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../domain/repositories.dart';
import '../../state/providers.dart';
import '../splash/splash_screen.dart';

/// Sign in / create account.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Which mode the screen opens in is not a default to guess at.
  ///
  /// On a device with no account, "Sign in" is a button that cannot succeed,
  /// and opening on it means a new user's first experience of Prayan is being
  /// told their account was not found. Resolved from the backend before the
  /// form is shown.
  bool _isRegistering = false;
  bool _ready = false;

  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  /// Set when a sign-in failed because no such account exists, so the error
  /// can offer the one thing that fixes it.
  bool _offerToCreate = false;

  @override
  void initState() {
    super.initState();
    _resolveOpeningMode();
  }

  Future<void> _resolveOpeningMode() async {
    final auth = ref.read(authRepositoryProvider);
    final existing = await auth.hasExistingAccount();
    final last = existing ? await auth.lastUsedIdentifier() : null;
    if (!mounted) return;
    setState(() {
      _isRegistering = !existing;
      if (last != null) _email.text = last;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      if (_isRegistering) {
        await auth.registerWithEmail(_email.text, _password.text);
      } else {
        await auth.signInWithEmail(_email.text, _password.text);
      }
      // Navigation is handled by the router's redirect, which reacts to the
      // auth stream — no imperative push here.
    } on RepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          // "No account found" is not a dead end, it is a fork: the fix is one
          // tap away and the user has already typed everything it needs.
          _offerToCreate = !_isRegistering && error.isNoSuchAccount;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Switches to creating the account the user just tried to sign in to,
  /// keeping what they typed. Retyping it is how a second typo happens.
  void _switchToCreating() {
    setState(() {
      _isRegistering = true;
      _error = null;
      _offerToCreate = false;
    });
  }

  Future<void> _federated(Future<AuthUser> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on RepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final auth = ref.read(authRepositoryProvider);
    final federated = auth.supportedProviders
        .where((p) => p != AuthProvider.emailPassword)
        .toSet();
    // Ask for what this backend can key an account by, rather than demanding
    // an email address for a field nothing will ever send mail to.
    final usernames = auth.identifierKind == AuthIdentifier.emailOrUsername;

    // Until the backend has said whether there is anything to sign into, the
    // screen has no honest heading to show — "Welcome back" flashing at
    // someone who has never been here is exactly the confusion being fixed.
    if (!_ready) {
      return const Scaffold(
        body: Center(child: PrayanMark(size: 64)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                        child:
                            PrayanMark(size: 72, animate: true, filled: true)),
                    const SizedBox(height: Spacing.xl),
                    Text(
                      _isRegistering ? 'Create your journal' : 'Welcome back',
                      style: text.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Plan the trade. Follow the rules. Measure the '
                      'discipline.',
                      style: text.bodyMedium
                          ?.copyWith(color: colors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Spacing.xxl),
                    TextFormField(
                      controller: _email,
                      keyboardType: usernames
                          ? TextInputType.text
                          : TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: [
                        if (usernames)
                          AutofillHints.username
                        else
                          AutofillHints.email,
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: usernames ? 'Email or username' : 'Email',
                        prefixIcon: Icon(usernames
                            ? Icons.person_outline_rounded
                            : Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        final input = value?.trim() ?? '';
                        if (input.isEmpty) {
                          return usernames
                              ? 'Enter your email address or username.'
                              : 'Enter your email address.';
                        }
                        // An address still has to look like one either way; a
                        // half-typed `shiva@` is a slip, not a username.
                        if (input.contains('@')) {
                          final parts = input.split('@');
                          if (parts.length != 2 ||
                              parts.first.isEmpty ||
                              !parts.last.contains('.')) {
                            return 'That does not look like an email address.';
                          }
                          return null;
                        }
                        if (!usernames) {
                          return 'That does not look like an email address.';
                        }
                        if (input.length < 3) {
                          return 'A username needs at least 3 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Spacing.md),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      autofillHints: [
                        if (_isRegistering)
                          AutofillHints.newPassword
                        else
                          AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        final input = value ?? '';
                        if (input.isEmpty) return 'Enter your password.';
                        if (_isRegistering && input.length < 8) {
                          return 'Use at least 8 characters.';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Spacing.lg),
                      ErrorState(
                        title: _isRegistering
                            ? 'Could not create the account'
                            : 'Could not sign in',
                        message: _offerToCreate
                            ? '$_error There is no account on this device '
                                'until you create one — nothing is stored on '
                                'a server.'
                            : _error!,
                        actionLabel:
                            _offerToCreate ? 'Create this account' : null,
                        onRetry: _offerToCreate ? _switchToCreating : null,
                      ),
                    ],
                    const SizedBox(height: Spacing.xl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isRegistering ? 'Create account' : 'Sign in'),
                    ),
                    const SizedBox(height: Spacing.sm),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _isRegistering = !_isRegistering;
                                _error = null;
                              }),
                      child: Text(_isRegistering
                          ? 'I already have an account'
                          : 'Create a new account'),
                    ),
                    // Only providers the backend can actually complete are
                    // offered. On the device-local build that is email alone,
                    // so the whole federated block disappears rather than
                    // presenting buttons that fail when tapped.
                    if (federated.isNotEmpty) ...[
                      const SizedBox(height: Spacing.lg),
                      Row(
                        children: [
                          Expanded(child: Divider(color: colors.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.md),
                            child: Text(
                              'or',
                              style: text.bodySmall
                                  ?.copyWith(color: colors.textTertiary),
                            ),
                          ),
                          Expanded(child: Divider(color: colors.border)),
                        ],
                      ),
                      const SizedBox(height: Spacing.lg),
                    ],
                    if (federated.contains(AuthProvider.google)) ...[
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _federated(auth.signInWithGoogle),
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                        label: const Text('Continue with Google'),
                      ),
                      const SizedBox(height: Spacing.sm),
                    ],
                    if (federated.contains(AuthProvider.apple))
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _federated(auth.signInWithApple),
                        icon: const Icon(Icons.apple_rounded),
                        label: const Text('Continue with Apple'),
                      ),
                    const SizedBox(height: Spacing.xl),
                    Text(
                      'Prayan never asks for your brokerage login. Your '
                      'journal is yours; you can export or delete it at any '
                      'time.',
                      textAlign: TextAlign.center,
                      style: text.labelSmall?.copyWith(
                        color: colors.textTertiary,
                        letterSpacing: 0,
                        height: 1.5,
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
