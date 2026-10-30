import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/result.dart';
import '../../data/repository_providers.dart';
import '../checkout/checkout_logic.dart';
import 'auth_logic.dart';

enum _Mode { signIn, signUp, reset }

OutlineInputBorder _border(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadii.md),
  borderSide: BorderSide(color: color),
);

InputDecoration _decoration(String label, {Widget? suffix}) => InputDecoration(
  labelText: label,
  suffixIcon: suffix,
  filled: true,
  fillColor: AppColors.surface,
  border: _border(AppColors.outline),
  enabledBorder: _border(AppColors.outline),
  focusedBorder: _border(AppColors.forest),
  errorBorder: _border(AppColors.error),
  focusedErrorBorder: _border(AppColors.error),
);

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _hidePassword = true;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _setMode(_Mode mode) => setState(() {
    _mode = mode;
    _message = null;
  });

  void _show(String message, {required bool error, bool busy = false}) {
    setState(() {
      _busy = busy;
      _message = message;
      _messageIsError = error;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(authRepositoryProvider);
    setState(() {
      _busy = true;
      _message = null;
    });

    switch (_mode) {
      case _Mode.signIn:
        final r = await repo.signIn(
          email: _email.text,
          password: _password.text,
        );
        if (!mounted) return;
        switch (r) {
          case Ok<AuthUser>():
            context.pop();
          case Failure<AuthUser>(:final message):
            _show(message, error: true);
          case NotAvailable<AuthUser>(:final message):
            _show(message, error: true);
        }
      case _Mode.signUp:
        final r = await repo.signUp(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );
        if (!mounted) return;
        switch (r) {
          case Ok<AuthUser?>(:final value):
            if (value != null) {
              context.pop();
            } else {
              _password.clear();
              _confirm.clear();
              setState(() => _mode = _Mode.signIn);
              _show(
                'Check your email for a verification link, then sign in.',
                error: false,
              );
            }
          case Failure<AuthUser?>(:final message):
            _show(message, error: true);
          case NotAvailable<AuthUser?>(:final message):
            _show(message, error: true);
        }
      case _Mode.reset:
        final r = await repo.requestPasswordReset(email: _email.text);
        if (!mounted) return;
        switch (r) {
          case Ok<void>():
            _show(
              'If an account exists for that email, a reset link was sent. '
              'Finishing a reset inside the app is not built yet.',
              error: false,
            );
          case Failure<void>(:final message):
            _show(message, error: true);
          case NotAvailable<void>(:final message):
            _show(message, error: true);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    final connected = ref.watch(authRepositoryProvider).isConnected;

    if (!connected) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                NotConnectedAuthRepository.message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      );
    }

    final (heading, button) = switch (_mode) {
      _Mode.signIn => ('Sign in to Amole', 'Sign in'),
      _Mode.signUp => ('Create your account', 'Create account'),
      _Mode.reset => ('Reset your password', 'Send reset link'),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Local test backend. Your orders, addresses and favorites '
                  'still use demo data on this phone for now.',
                  style: secondary,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_mode == _Mode.signUp) ...[
                  TextFormField(
                    key: const Key('auth_name'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: validateName,
                    decoration: _decoration('Full name'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  key: const Key('auth_email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: validateEmail,
                  decoration: _decoration('Email'),
                ),
                if (_mode != _Mode.reset) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('auth_password'),
                    controller: _password,
                    obscureText: _hidePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: _mode == _Mode.signUp
                        ? TextInputAction.next
                        : TextInputAction.done,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: _mode == _Mode.signUp
                        ? validatePassword
                        : validateSignInPassword,
                    decoration: _decoration(
                      'Password',
                      suffix: IconButton(
                        tooltip: _hidePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                  ),
                ],
                if (_mode == _Mode.signUp) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('auth_confirm'),
                    controller: _confirm,
                    obscureText: _hidePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) =>
                        validateConfirmPassword(_password.text, v),
                    decoration: _decoration('Confirm password'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('At least 10 characters.', style: secondary),
                ],
                if (_message != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: _messageIsError
                            ? AppColors.error
                            : AppColors.forest,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(button),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_mode == _Mode.signIn) ...[
                  TextButton(
                    onPressed: () => _setMode(_Mode.signUp),
                    child: const Text('Create an account'),
                  ),
                  TextButton(
                    onPressed: () => _setMode(_Mode.reset),
                    child: const Text('Forgot password?'),
                  ),
                ] else
                  TextButton(
                    onPressed: () => _setMode(_Mode.signIn),
                    child: const Text('I already have an account'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
