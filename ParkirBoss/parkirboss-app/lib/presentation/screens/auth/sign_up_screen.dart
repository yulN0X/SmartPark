import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/core/services/auth_service.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();

  Future<void> _showRegisterDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('BUAT AKUN BARU'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'No. HP'), keyboardType: TextInputType.phone),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
          ElevatedButton(
            onPressed: () async {
              final success = await _authService.register(
                nameCtrl.text, emailCtrl.text, phoneCtrl.text, passCtrl.text,
              );
              if (success) {
                // Auto-login after register
                await _authService.login(emailCtrl.text, passCtrl.text);
              }
              Navigator.pop(ctx, success);
            },
            child: const Text('DAFTAR'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else if (result == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registrasi gagal, coba lagi')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // ─── Background Accents ─────────────────────────────────
            Positioned(
              top: 40,
              left: 40,
              child: Opacity(
                opacity: 0.5,
                child: Text(
                  'SYS.AUTH.01',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              right: 40,
              child: Opacity(
                opacity: 0.5,
                child: Text(
                  'GRID_LOCK://SECURE',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.onBackground, width: AppSpacing.borderMedium),
                    bottom: BorderSide(color: AppColors.onBackground, width: AppSpacing.borderMedium),
                  ),
                ),
              ).withOpacity(0.1),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                width: 128,
                height: 128,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppColors.onBackground, width: AppSpacing.borderMedium),
                    top: BorderSide(color: AppColors.onBackground, width: AppSpacing.borderMedium),
                  ),
                ),
              ).withOpacity(0.1),
            ),

            // ─── Main Content ───────────────────────────────────────
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.margin),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(
                      color: AppColors.onBackground,
                      width: AppSpacing.borderMedium,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.onBackground,
                        offset: Offset(4, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Crosshair Corners
                      _buildCrosshairs(),
                      
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ─── Header / Logo ──────────────────────────────
                          Container(
                            width: 96,
                            height: 96,
                            margin: const EdgeInsets.only(bottom: AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.tertiaryContainer,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.onBackground,
                                width: AppSpacing.borderMedium,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.onBackground,
                                  offset: Offset(4, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'P',
                                style: AppTypography.displayLarge.copyWith(
                                  color: AppColors.onTertiaryContainer,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.onBackground,
                                  width: AppSpacing.borderMedium,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Text(
                              'PARKIR BOSS',
                              textAlign: TextAlign.center,
                              style: AppTypography.headlineLarge.copyWith(
                                color: AppColors.onBackground,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              border: Border.all(
                                color: AppColors.onBackground,
                                width: 2.0,
                              ),
                            ),
                            child: Text(
                              'Secure access to the urban grid.',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // ─── Actions ──────────────────────────────────
                          BrutalistButton(
                            label: 'Sign up with Email',
                            trailingIcon: Icons.person,
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimaryContainer,
                            onPressed: _showRegisterDialog,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(
                                  color: AppColors.onBackground,
                                  thickness: AppSpacing.borderMedium,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                                child: Text(
                                  'OR',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.onBackground,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                                  color: AppColors.onBackground,
                                  thickness: AppSpacing.borderMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          BrutalistButton(
                            label: 'Continue with Apple',
                            trailingIcon: Icons.phone_iphone,
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.onSurface,
                            onPressed: () {},
                          ),
                          const SizedBox(height: AppSpacing.gutter),
                          BrutalistButton(
                            label: 'Continue with Google',
                            trailingIcon: Icons.account_circle,
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.onSurface,
                            onPressed: () {},
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // ─── Footer Link ──────────────────────────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: AppColors.onBackground,
                                  width: AppSpacing.borderMedium,
                                ),
                              ),
                            ),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushReplacementNamed('/login');
                              },
                              child: Text(
                                'ALREADY STARTED? LOGIN',
                                textAlign: TextAlign.center,
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.tertiary,
                                  decoration: TextDecoration.underline,
                                  decorationThickness: 4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrosshairs() {
    return Positioned.fill(
      child: Stack(
        children: [
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.onBackground, width: 2),
                right: BorderSide(color: AppColors.onBackground, width: 2),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.onBackground, width: 2),
                left: BorderSide(color: AppColors.onBackground, width: 2),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.onBackground, width: 2),
                right: BorderSide(color: AppColors.onBackground, width: 2),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.onBackground, width: 2),
                left: BorderSide(color: AppColors.onBackground, width: 2),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}

extension OpacityExtension on Widget {
  Widget withOpacity(double opacity) {
    return Opacity(
      opacity: opacity,
      child: this,
    );
  }
}
