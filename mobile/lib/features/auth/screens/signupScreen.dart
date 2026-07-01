import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/apiUrl.dart';
import '../../../core/network/apiClient.dart';
import '../../../core/network/authTokenProvider.dart';
import '../../../core/theme/appTokens.dart';
import '../../../core/widgets/contourBackground.dart';
import '../../../core/widgets/primaryButton.dart';
import '../../../core/widgets/inlineErrorBanner.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signup() async {
    // Basic client-side validation
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Email and password fields cannot be empty.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post(ApiUrl.signup, {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      final token = response['token'] as String;
      await ref.read(authTokenProvider.notifier).setToken(token);
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e is ApiException) {
            _errorMessage = e.message;
          } else {
            _errorMessage = e.toString().replaceFirst('Exception: ', '');
          }
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
                    'Create your account',
                    style: textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Start a trip and bring your people along.',
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
                            decoration: const InputDecoration(labelText: 'Email address'),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: AppSpace.md),
                          TextField(
                            controller: _passwordController,
                            enabled: !_isLoading,
                            decoration: const InputDecoration(labelText: 'Password'),
                            obscureText: true,
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: AppSpace.md),
                            InlineErrorBanner(message: _errorMessage!),
                          ],
                          const SizedBox(height: AppSpace.lg),
                          PrimaryButton(
                            label: 'Sign up',
                            loading: _isLoading,
                            onPressed: _isLoading ? null : _signup,
                          ),
                          const SizedBox(height: AppSpace.sm),
                          TextButton(
                            onPressed: _isLoading ? null : () => context.go('/login'),
                            child: const Text('Already have an account? Log in'),
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
