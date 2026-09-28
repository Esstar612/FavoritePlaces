import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:favorite_places/providers/auth_provider.dart';

class EmailSignInSheet extends ConsumerStatefulWidget {
  const EmailSignInSheet({super.key, required this.onCreateAccount});

  final VoidCallback onCreateAccount;

  @override
  ConsumerState<EmailSignInSheet> createState() => _EmailSignInSheetState();
}

class _EmailSignInSheetState extends ConsumerState<EmailSignInSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _show(String? message, {bool error = false}) => setState(() {
        _message = message;
        _messageIsError = error;
      });

  Future<void> _signIn() async {
    _show(null);
    final auth = ref.read(authNotifierProvider.notifier);
    await auth.signInWithEmail(_email.text.trim(), _password.text.trim());
    if (!mounted) return;
    final state = ref.read(authNotifierProvider);
    if (state.hasError) {
      _show(firebaseAuthErrorMessage(state.error!), error: true);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _show('Enter your email first, then tap Forgot password.', error: true);
      return;
    }
    await ref.read(authNotifierProvider.notifier).resetPassword(email);
    if (!mounted) return;
    final state = ref.read(authNotifierProvider);
    state.hasError
        ? _show(firebaseAuthErrorMessage(state.error!), error: true)
        : _show('Check your inbox: a reset link is on its way to $email.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final loading = ref.watch(authNotifierProvider).isLoading;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Welcome back', style: TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w500)),
              ),
              IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => loading ? null : _signIn(),
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: loading ? null : _resetPassword, child: const Text('Forgot password?')),
          ),
          if (_message case final message?) ...[
            Text(
              message,
              style: TextStyle(fontSize: 13, color: _messageIsError ? scheme.error : scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            onPressed: loading ? null : _signIn,
            child: loading
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Sign in'),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('New here?', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
              TextButton(onPressed: widget.onCreateAccount, child: const Text('Create an account')),
            ],
          ),
        ],
      ),
    );
  }
}
