import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/appRoutes.dart';
import '../../../core/constants/appStrings.dart';
import '../../../core/network/apiUrl.dart';
import '../../../core/network/apiClient.dart';
import '../../../core/network/authTokenProvider.dart';
import '../../../core/theme/appTokens.dart';
import '../../../core/util/text_input_rules.dart';
import '../../../core/widgets/contourBackground.dart';
import '../../../core/widgets/primaryButton.dart';
import '../../../core/widgets/inlineErrorBanner.dart';
import '../providers/current_user_provider.dart';

/// Wire-contract field names for the /auth/signup response body. NOT
/// app-internal choices — must match the backend byte-for-byte.
/// `legacyTokenField` is the 7-day alias kept so the app still logs in
/// against a rolled-back backend that only returns `token` (L1).
class _SignupResponseWire {
  _SignupResponseWire._();

  static const String accessTokenField = 'accessToken';
  static const String legacyTokenField = 'token';
  static const String refreshTokenField = 'refreshToken';
  static const String userField = 'user';
}

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<void> _signup() async {
    // Basic client-side validation
    if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = AppStrings.allFieldsRequired);
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = AppStrings.passwordsDontMatch);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post(ApiUrl.signup, {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      // Defensive: accept the new pair, fall back to the legacy `token` field
      // so a rolled-back backend still logs the user in. Never a hard cast (L1).
      final access = (response[_SignupResponseWire.accessTokenField] as String?) ??
          (response[_SignupResponseWire.legacyTokenField] as String?);
      final refresh = response[_SignupResponseWire.refreshTokenField] as String?;
      if (access == null) {
        setState(() => _errorMessage = AppStrings.unknownError);
        return;
      }
      if (refresh != null) {
        await ref.read(authSessionProvider.notifier)
            .setTokens(accessToken: access, refreshToken: refresh);
      } else {
        await ref.read(authSessionProvider.notifier).setAccessToken(access);
      }
      final user = response[_SignupResponseWire.userField];
      if (user is Map<String, dynamic>) {
        await persistCurrentUser(ref, user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ApiException ? e.message : AppStrings.unknownError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: ContourBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.createAccountTitle,
                    style: textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    AppStrings.signupTagline,
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _firstNameController,
                            enabled: !_isLoading,
                            decoration: const InputDecoration(labelText: AppStrings.firstNameLabel),
                            textCapitalization: TextCapitalization.words,
                            inputFormatters: inputRules(),
                          ),
                          const SizedBox(height: AppSpace.md),
                          TextField(
                            controller: _lastNameController,
                            enabled: !_isLoading,
                            decoration: const InputDecoration(labelText: AppStrings.lastNameLabel),
                            textCapitalization: TextCapitalization.words,
                            inputFormatters: inputRules(),
                          ),
                          const SizedBox(height: AppSpace.md),
                          TextField(
                            controller: _emailController,
                            enabled: !_isLoading,
                            decoration: const InputDecoration(labelText: AppStrings.emailLabel),
                            keyboardType: TextInputType.emailAddress,
                            inputFormatters: inputRules(),
                          ),
                          const SizedBox(height: AppSpace.md),
                          TextField(
                            controller: _passwordController,
                            enabled: !_isLoading,
                            obscureText: _obscurePassword,
                            inputFormatters: inputRules(),
                            decoration: InputDecoration(
                              labelText: AppStrings.passwordLabel,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                tooltip: _obscurePassword ? AppStrings.showPassword : AppStrings.hidePassword,
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpace.md),
                          TextField(
                            controller: _confirmController,
                            enabled: !_isLoading,
                            obscureText: _obscureConfirm,
                            inputFormatters: inputRules(),
                            decoration: InputDecoration(
                              labelText: AppStrings.confirmPasswordLabel,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                tooltip: _obscureConfirm ? AppStrings.showPassword : AppStrings.hidePassword,
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: AppSpace.md),
                            InlineErrorBanner(message: _errorMessage!),
                          ],
                          const SizedBox(height: AppSpace.lg),
                          PrimaryButton(
                            label: AppStrings.signupButton,
                            loading: _isLoading,
                            onPressed: _isLoading ? null : _signup,
                          ),
                          const SizedBox(height: AppSpace.sm),
                          TextButton(
                            onPressed: _isLoading ? null : () => context.go(AppRoutes.login),
                            child: const Text(AppStrings.haveAccountPrompt),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
