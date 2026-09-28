import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:favorite_places/providers/auth_provider.dart';
import 'package:favorite_places/screens/auth/signup.dart';
import 'package:favorite_places/widgets/auth/email_sign_in_sheet.dart';
import 'package:favorite_places/widgets/auth/welcome_header.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _sheetOpen = false;

  void _createAccount() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SignUpScreen()),
      );

  Future<void> _openEmailSheet() async {
    setState(() => _sheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => EmailSignInSheet(
        onCreateAccount: () {
          Navigator.of(sheetContext).pop();
          _createAccount();
        },
      ),
    );
    if (mounted) setState(() => _sheetOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loading = ref.watch(authNotifierProvider).isLoading;
    final auth = ref.read(authNotifierProvider.notifier);
    final muted = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);

    ref.listen<AsyncValue<void>>(authNotifierProvider, (previous, next) {
      // The email sheet shows its own errors in place.
      if (_sheetOpen) return;
      next.whenOrNull(error: (error, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(firebaseAuthErrorMessage(error))),
        );
      });
    });

    final outlined = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      foregroundColor: scheme.onSurface,
      side: BorderSide(color: scheme.outline),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const WelcomeHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Save the places you love. Let AI plan the outing.',
                            style: TextStyle(fontSize: 30, height: 38 / 30, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Keep your favorite spots in one place, then ask for something like '
                            '"coffee, then a walk with a view."',
                            style: TextStyle(fontSize: 15, height: 22 / 15, color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                            ),
                            onPressed: loading ? null : auth.continueAsGuest,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Continue as guest'),
                                SizedBox(width: 10),
                                Icon(Icons.arrow_forward, size: 22),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.place, size: 14, color: scheme.primary),
                              const SizedBox(width: 6),
                              Text('5 sample places in San Francisco · no account needed', style: muted),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Already saving places? Sign in with',
                        textAlign: TextAlign.center,
                        style: muted.copyWith(color: scheme.outline),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: outlined,
                              onPressed: loading ? null : auth.signInWithGoogle,
                              icon: SvgPicture.asset('assets/google_g.svg', width: 20, height: 20),
                              label: const Text('Google'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: outlined,
                              onPressed: loading ? null : _openEmailSheet,
                              icon: Icon(Icons.mail, size: 20, color: scheme.primary),
                              label: const Text('Email'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('New here?', style: muted.copyWith(fontSize: 14)),
                          TextButton(onPressed: _createAccount, child: const Text('Create an account')),
                        ],
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
