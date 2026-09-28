import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/services/firestore_service.dart';
import 'package:favorite_places/utils/palette.dart';
import 'package:favorite_places/utils/password_strength.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_refresh);
    _confirmPasswordController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _leave() => Navigator.of(context).popUntil((route) => route.isFirst);

  Future<void> _signUp() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name');
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Please enter your email');
      return;
    }
    if (!passwordStrength(_passwordController.text.trim()).allowsSignUp) {
      _showSnackBar('Password must be at least $minPasswordLength characters');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match');
      return;
    }

    final wasGuest = _isGuest;
    await ref.read(authNotifierProvider.notifier).signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _nameController.text.trim(),
        );

    if (!mounted) return;
    if (!ref.read(authNotifierProvider).hasError) _finish(wasGuest);
  }

  Future<void> _signUpWithGoogle() async {
    final wasGuest = _isGuest;
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) _finish(wasGuest);
  }

  bool get _isGuest => FirebaseAuth.instance.currentUser?.isAnonymous ?? false;

  void _finish(bool wasGuest) {
    final messenger = ScaffoldMessenger.of(context);
    _leave();
    if (wasGuest) _dropSamples(messenger);
  }

  Future<void> _dropSamples(ScaffoldMessengerState messenger) async {
    try {
      final removed = await FirestoreService.deleteSamplePlaces();
      if (removed > 0) {
        messenger.showSnackBar(SnackBar(content: Text('Removed $removed sample places')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: const Text("Couldn't remove the sample places"),
        action: SnackBarAction(label: 'Retry', onPressed: () => _dropSamples(messenger)),
      ));
    }
  }

  Future<void> _offerSignIn() async {
    final signIn = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('That account already exists'),
        content: const Text("Sign in to it instead? Places you added as a guest won't carry over."),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign in')),
        ],
      ),
    );
    if (signIn != true || !mounted) return;
    final navigator = Navigator.of(context);
    await ref.read(authNotifierProvider.notifier).signOut();
    navigator.popUntil((route) => route.isFirst);
  }

  void _continueAsGuest() {
    final auth = ref.read(authNotifierProvider.notifier);
    _leave();
    auth.continueAsGuest();
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    ref.listen<AsyncValue<void>>(authNotifierProvider, (previous, next) {
      next.whenOrNull(error: (error, _) {
        if (isAccountExistsError(error) && _isGuest) {
          _offerSignIn();
        } else {
          _showSnackBar(firebaseAuthErrorMessage(error));
        }
      });
    });

    final password = _passwordController.text.trim();
    final strength = passwordStrength(password);
    final confirm = _confirmPasswordController.text;
    final mismatch = confirm.isNotEmpty && confirm != _passwordController.text;

    const border = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)));
    final help = TextStyle(fontSize: 12, height: 16 / 12, color: scheme.onSurfaceVariant);
    final link = TextButton.styleFrom(textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to sign in',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create your account',
                      style: TextStyle(fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your places sync across devices, and the AI planner works from your own list.',
                      style: TextStyle(fontSize: 14, height: 20 / 14, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.nickname],
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        helperText: 'Shown on your profile',
                        border: border,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email', border: border),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: border,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StrengthMeter(strength: strength),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 0, 0),
                      child: Text(
                        password.isEmpty
                            ? 'At least $minPasswordLength characters.'
                            : '${strength.label}. At least $minPasswordLength characters.',
                        style: help,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => isLoading ? null : _signUp(),
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        border: border,
                        errorText: mismatch ? "Passwords don't match yet" : null,
                        suffixIcon: mismatch
                            ? Icon(Icons.error, color: scheme.error)
                            : IconButton(
                                tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                                icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      onPressed: isLoading ? null : _signUp,
                      child: isLoading
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.outline),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      onPressed: isLoading ? null : _signUpWithGoogle,
                      icon: SvgPicture.asset('assets/google_g.svg', width: 20, height: 20),
                      label: const Text('Sign up with Google'),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Already have an account?', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                          TextButton(
                            style: link,
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Sign in'),
                          ),
                        ],
                      ),
                      if (!_isGuest)
                        TextButton(
                          style: link,
                          onPressed: isLoading ? null : _continueAsGuest,
                          child: const Text('Just looking? Continue as guest'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.strength});

  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = switch (strength) {
      PasswordStrength.tooShort || PasswordStrength.weak => scheme.error,
      PasswordStrength.fair => scheme.star,
      PasswordStrength.good || PasswordStrength.strong => scheme.positive,
    };
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < strength.segments ? fill : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
