import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/appRoutes.dart';
import '../../../core/constants/appStrings.dart';
import '../../../core/network/apiUrl.dart';
import '../../../core/network/apiClient.dart';
import '../../../core/network/authSession.dart';
import '../../../core/network/authTokenProvider.dart';
import '../../../core/theme/appTokens.dart';
import '../../../core/util/text_input_rules.dart';
import '../../../core/widgets/contourBackground.dart';
import '../../../core/widgets/primaryButton.dart';
import '../../../core/widgets/inlineErrorBanner.dart';
import '../providers/current_user_provider.dart';

/// Wire-contract field names for /auth/login. `legacyTokenField` is kept so login
/// still works against a rolled-back backend that only returns `token` (L1).
class _LoginResponseWire {
  _LoginResponseWire._();

  static const String accessTokenField = 'accessToken';
  static const String legacyTokenField = 'token';
  static const String refreshTokenField = 'refreshToken';
  static const String userField = 'user';
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // R4: explain a forced sign-out. Read once — consume clears it so it
    // won't reappear on rebuild; a deliberate log-out shows nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reason = ref.read(authSessionProvider.notifier).consumeLogoutReason();
      if (reason == LogoutReason.sessionExpired) {
        setState(() => _errorMessage = AppStrings.sessionExpiredBanner);
      }
    });
  }
  bool _obscurePassword = true;

  Future<void> _login() async {
    // Basic client-side validation
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = AppStrings.emptyCredentials;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post(ApiUrl.login, {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      // Defensive: accept the new pair, fall back to the legacy `token` field
      // so a rolled-back backend still logs the user in. Never a hard cast (L1).
      final access = (response[_LoginResponseWire.accessTokenField] as String?) ??
          (response[_LoginResponseWire.legacyTokenField] as String?);
      final refresh = response[_LoginResponseWire.refreshTokenField] as String?;
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
      final user = response[_LoginResponseWire.userField];
      if (user is Map<String, dynamic>) {
        await persistCurrentUser(ref, user);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.statusCode == 401 ? AppStrings.invalidCredentials : e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AppStrings.unknownError;
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
    _emailController.dispose();
    _passwordController.dispose();
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
                    AppStrings.appName,
                    style: textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    AppStrings.loginTagline,
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
                          if (_errorMessage != null) ...[
                            const SizedBox(height: AppSpace.md),
                            InlineErrorBanner(message: _errorMessage!),
                          ],
                          const SizedBox(height: AppSpace.lg),
                          PrimaryButton(
                            label: AppStrings.loginButton,
                            loading: _isLoading,
                            onPressed: _isLoading ? null : _login,
                          ),
                          const SizedBox(height: AppSpace.sm),
                          TextButton(
                            onPressed: _isLoading ? null : () => context.go(AppRoutes.signup),
                            child: const Text(AppStrings.noAccountPrompt),
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
