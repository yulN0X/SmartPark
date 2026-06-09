import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

import 'package:parkirboss/core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await _authService.login(email, password);

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed. Please check your credentials.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.margin),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                border: Border.all(
                  color: AppColors.onSurface,
                  width: 3.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.onSurface,
                    offset: Offset(4, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Header ─────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          border: Border.all(
                            color: AppColors.onSurface,
                            width: 3.0,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.onSurface,
                              offset: Offset(4, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_parking,
                          color: AppColors.onPrimaryContainer,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'PARKIR BOSS',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ─── Title & Subtitle ───────────────────────────
                  RichText(
                    text: const TextSpan(
                      style: AppTypography.displayLarge,
                      children: [
                        TextSpan(
                          text: 'Welcome\n',
                          style: TextStyle(color: AppColors.onSurface),
                        ),
                        TextSpan(
                          text: 'Back',
                          style: TextStyle(color: AppColors.tertiary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Enter your details to access your account.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ─── Login Form ─────────────────────────────────
                  _buildLabel('Email Address'),
                  _buildInput(
                    controller: _emailController,
                    icon: Icons.mail_outline,
                    placeholder: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel('Password'),
                      Text(
                        'FORGOT PASSWORD?',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                  _buildInput(
                    controller: _passwordController,
                    icon: Icons.lock_outline,
                    placeholder: '••••••••',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ─── Submit Button ──────────────────────────────
                  BrutalistButton(
                    label: _isLoading ? 'LOGGING IN...' : 'LOG IN',
                    trailingIcon: Icons.arrow_forward,
                    backgroundColor: AppColors.tertiary,
                    foregroundColor: AppColors.onTertiary,
                    onPressed: _isLoading ? () {} : _login,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ─── Divider ────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(
                          color: AppColors.onSurface,
                          thickness: 3,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(
                          color: AppColors.onSurface,
                          thickness: 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ─── Social Login ───────────────────────────────
                  Row(
                    children: [
                      Expanded(child: _buildSocialButton('Google')),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _buildSocialButton('Apple')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ─── Footer Link ────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacementNamed('/signup');
                      },
                      child: RichText(
                        text: TextSpan(
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: 'CREATE ACCOUNT',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.tertiary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.labelMedium.copyWith(
        color: AppColors.onSurface,
      ),
    );
  }

  Widget _buildInput({
    required IconData icon,
    required String placeholder,
    TextEditingController? controller,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.onSurface,
            width: 3.0,
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            icon,
            color: AppColors.onSurfaceVariant,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
    );
  }

  Widget _buildSocialButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border.all(
          color: AppColors.onSurface,
          width: 3.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.onSurface,
            offset: Offset(4, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.onSurface,
        ),
      ),
    );
  }
}
