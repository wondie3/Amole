import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/result.dart';
import '../../data/repository_providers.dart';
import '../../shared/widgets/amole_wordmark.dart';
import '../checkout/checkout_logic.dart';
import 'auth_logic.dart';

enum _Mode { signIn, signUp, reset }

const Color _greenLight = Color(0xFF4A8B7C);
const Color _greenDark = Color(0xFF285446);
const Color _lightButton = Color(0xFFBFD3CE);
const Color _errorOnGreen = Color(0xFFFFD9D2);
const LinearGradient _gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_greenLight, _greenDark],
);
const double _pill = 32;

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _hidePassword = true;
  bool _started = false;
  bool _reduceMotion = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    if (_reduceMotion) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
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

  // ---- Building blocks ----

  /// Fades and slides [child] in, one after another by [index].
  Widget _reveal(int index, Widget child) {
    final start = (index * 0.1).clamp(0.0, 0.6);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final curve = CurveTween(
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: _entrance.drive(curve),
      child: SlideTransition(
        position: _entrance
            .drive(curve)
            .drive(
              Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero),
            ),
        child: child,
      ),
    );
  }

  Widget _icon(IconData icon, {required Color color, required Color circle}) {
    final pop = _entrance.drive(
      CurveTween(curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );
    return ScaleTransition(
      scale: pop,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
        child: Icon(icon, size: 80, color: color),
      ),
    );
  }

  Widget _close(Color color) => Align(
    alignment: Alignment.centerRight,
    child: IconButton(
      tooltip: 'Close',
      icon: Icon(Icons.close, color: color),
      onPressed: () => context.pop(),
    ),
  );

  Widget _frame({
    required SystemUiOverlayStyle overlay,
    required Widget child,
    Decoration? decoration,
    bool safeTop = true,
  }) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: DecoratedBox(
        decoration: decoration ?? const BoxDecoration(color: Colors.white),
        child: SafeArea(
          top: safeTop,
          bottom: false,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    required bool onGreen,
    TextInputType? keyboardType,
    TextInputAction? action,
    bool obscure = false,
    Widget? suffix,
    TextCapitalization capitalization = TextCapitalization.none,
    bool plain = false,
  }) {
    final fg = onGreen ? Colors.white : AppColors.forest;
    final errorColor = onGreen ? _errorOnGreen : AppColors.error;
    OutlineInputBorder border(Color c, [double w = 2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(_pill),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: action,
      obscureText: obscure,
      enableSuggestions: !plain,
      autocorrect: !plain,
      textCapitalization: capitalization,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      cursorColor: fg,
      style: TextStyle(color: fg, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: TextStyle(color: fg.withValues(alpha: 0.8)),
        prefixIcon: Icon(icon, color: fg.withValues(alpha: 0.8)),
        suffixIcon: suffix,
        suffixIconColor: fg,
        filled: !onGreen,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 18,
        ),
        border: border(fg),
        enabledBorder: border(fg),
        focusedBorder: border(fg, 3),
        errorBorder: border(errorColor),
        focusedErrorBorder: border(errorColor, 3),
        errorStyle: TextStyle(color: errorColor),
      ),
    );
  }

  Widget _emailField({required bool onGreen}) => _field(
    fieldKey: const Key('auth_email'),
    controller: _email,
    label: 'Email',
    icon: Icons.mail_outline,
    validator: validateEmail,
    onGreen: onGreen,
    keyboardType: TextInputType.emailAddress,
    action: TextInputAction.next,
    plain: true,
  );

  Widget _passwordField({required bool onGreen, required bool signUp}) =>
      _field(
        fieldKey: const Key('auth_password'),
        controller: _password,
        label: 'Password',
        icon: Icons.lock_outline,
        validator: signUp ? validatePassword : validateSignInPassword,
        onGreen: onGreen,
        obscure: _hidePassword,
        action: signUp ? TextInputAction.next : TextInputAction.done,
        plain: true,
        suffix: IconButton(
          tooltip: _hidePassword ? 'Show password' : 'Hide password',
          icon: Icon(
            _hidePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _hidePassword = !_hidePassword),
        ),
      );

  Widget _message_({required Color ok, required Color error}) {
    final text = _message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: _messageIsError ? error : ok, fontSize: 14),
        ),
      ),
    );
  }

  Widget _submitButton(String label, {bool light = false}) {
    return FilledButton(
      onPressed: _busy ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: light ? _lightButton : _greenDark,
        foregroundColor: light ? AppColors.forest : Colors.white,
        disabledBackgroundColor: light
            ? _lightButton.withValues(alpha: 0.6)
            : _greenDark.withValues(alpha: 0.6),
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
      child: _busy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: light ? AppColors.forest : Colors.white,
              ),
            )
          : Text(label),
    );
  }

  // ---- Pages ----

  Widget _signInPage() {
    return _frame(
      overlay: SystemUiOverlayStyle.light,
      decoration: const BoxDecoration(gradient: _gradient),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _close(Colors.white),
          ),
          _reveal(
            0,
            _icon(
              Icons.delivery_dining,
              color: AppColors.cream,
              circle: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _reveal(1, const AmoleWordmark(fontSize: 46, color: AppColors.cream)),
          const SizedBox(height: AppSpacing.xs),
          _reveal(
            2,
            Column(
              children: [
                const Text(
                  'Sign in to Amole',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  'Local test backend. Orders stay demo data for now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                _reveal(3, _emailField(onGreen: true)),
                const SizedBox(height: AppSpacing.md),
                _reveal(4, _passwordField(onGreen: true, signUp: false)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: _reveal(
              5,
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  32,
                  AppSpacing.md,
                  32,
                  AppSpacing.lg + MediaQuery.viewPaddingOf(context).bottom,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => _setMode(_Mode.reset),
                      child: const Text('Forgot password?'),
                    ),
                    _message_(ok: AppColors.forest, error: AppColors.error),
                    _submitButton('Sign in'),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('or'),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.tonal(
                      onPressed: () => _setMode(_Mode.signUp),
                      style: FilledButton.styleFrom(
                        backgroundColor: _lightButton,
                        foregroundColor: AppColors.forest,
                        minimumSize: const Size.fromHeight(56),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text('Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _signUpPage() {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return _frame(
      overlay: SystemUiOverlayStyle.light,
      safeTop: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              32,
              topInset + AppSpacing.sm,
              AppSpacing.lg,
              32,
            ),
            decoration: const BoxDecoration(
              gradient: _gradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _close(Colors.white),
                _reveal(
                  0,
                  const Text(
                    'Let\u2019s',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w300,
                      height: 1.1,
                    ),
                  ),
                ),
                _reveal(
                  1,
                  const Text(
                    'Create Your Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, AppSpacing.lg),
            child: Column(
              children: [
                _reveal(
                  2,
                  _field(
                    fieldKey: const Key('auth_name'),
                    controller: _name,
                    label: 'Full name',
                    icon: Icons.person_outline,
                    validator: validateName,
                    onGreen: false,
                    action: TextInputAction.next,
                    capitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _reveal(3, _emailField(onGreen: false)),
                const SizedBox(height: AppSpacing.md),
                _reveal(4, _passwordField(onGreen: false, signUp: true)),
                const SizedBox(height: AppSpacing.md),
                _reveal(
                  5,
                  _field(
                    fieldKey: const Key('auth_confirm'),
                    controller: _confirm,
                    label: 'Confirm password',
                    icon: Icons.lock_outline,
                    validator: (v) =>
                        validateConfirmPassword(_password.text, v),
                    onGreen: false,
                    obscure: _hidePassword,
                    action: TextInputAction.done,
                    plain: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'At least 10 characters.',
                  style: TextStyle(
                    color: AppColors.forest.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _message_(ok: AppColors.forest, error: AppColors.error),
                _reveal(6, _submitButton('Create account')),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Have an account?'),
                    TextButton(
                      onPressed: () => _setMode(_Mode.signIn),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resetPage() {
    return _frame(
      overlay: SystemUiOverlayStyle.dark,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _close(AppColors.forest),
          ),
          _reveal(
            0,
            _icon(
              Icons.lock,
              color: AppColors.forest,
              circle: AppColors.forest.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _reveal(
            1,
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(
                    text: 'Forgot\n',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: 'Password?',
                    style: TextStyle(fontWeight: FontWeight.w300),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.forest,
                fontSize: 38,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _reveal(
            2,
            const Text(
              'No worries, we\u2019ll send you\nreset instructions',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.forest, fontSize: 15),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: _reveal(
              3,
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  32,
                  32,
                  32,
                  AppSpacing.lg + MediaQuery.viewPaddingOf(context).bottom,
                ),
                decoration: const BoxDecoration(
                  gradient: _gradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _emailField(onGreen: true),
                    const SizedBox(height: AppSpacing.lg),
                    _message_(ok: Colors.white, error: _errorOnGreen),
                    _submitButton('Send reset link', light: true),
                    const SizedBox(height: AppSpacing.xl),
                    Center(
                      child: TextButton(
                        onPressed: () => _setMode(_Mode.signIn),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Back to Login',
                          style: TextStyle(
                            fontSize: 18,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      );
    }

    final page = switch (_mode) {
      _Mode.signIn => _signInPage(),
      _Mode.signUp => _signUpPage(),
      _Mode.reset => _resetPage(),
    };

    return Scaffold(
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: AnimatedSwitcher(
          duration: _reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, if (current != null) current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.04, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey<_Mode>(_mode), child: page),
        ),
      ),
    );
  }
}
