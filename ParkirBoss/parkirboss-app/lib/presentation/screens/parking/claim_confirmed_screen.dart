import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class ClaimConfirmedScreen extends StatelessWidget {
  const ClaimConfirmedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false, // Suppressed trailing actions for focused flow
        title: Center(
          child: Text(
            'PARKIR BOSS',
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: AppColors.tertiary,
              letterSpacing: -1,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppSpacing.borderMedium),
          child: Container(
            color: AppColors.onBackground,
            height: AppSpacing.borderMedium,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin, vertical: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─── Success Indicator ────────────────────────────────────
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.onBackground,
                    width: 4.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.onBackground,
                      offset: Offset(4, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.check,
                    size: 64,
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ─── Success Headline ─────────────────────────────────────
              Text(
                'SLOT BERHASIL\nDIKLAIM!',
                textAlign: TextAlign.center,
                style: AppTypography.displaySmall.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.onBackground,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ─── Timer Countdown Accent ───────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  border: Border.all(
                    color: AppColors.onBackground,
                    width: 3.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.onBackground,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_top, color: AppColors.onErrorContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'EXPIRES IN: 14:59',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.onErrorContainer,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ─── Slot Details Card ────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  border: Border.all(
                    color: AppColors.onBackground,
                    width: 3.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.onBackground,
                      offset: Offset(4, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Location', 'Central Plaza', bgColor: AppColors.surfaceVariant),
                    _buildDetailRow('Floor', 'Lantai A'),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: const BoxDecoration(
                        color: AppColors.tertiaryFixed,
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.1,
                              child: CustomPaint(
                                painter: _StripedPainter(color: AppColors.onBackground),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SLOT',
                                style: AppTypography.labelMedium.copyWith(color: AppColors.onBackground),
                              ),
                              Text(
                                'A3',
                                style: AppTypography.displayMedium.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.onBackground,
                                  letterSpacing: -2.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // ─── Action Buttons ───────────────────────────────────────
              BrutalistButton(
                label: 'Lihat Peta Slot',
                leadingIcon: Icons.map,
                backgroundColor: AppColors.tertiary,
                foregroundColor: AppColors.onTertiary,
                onPressed: () {
                  // Wait, no map view route defined yet, maybe just pop to home
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              BrutalistButton(
                label: 'Kembali ke Home',
                leadingIcon: Icons.home,
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.onSurface,
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? bgColor}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(
          bottom: BorderSide(
            color: AppColors.onBackground,
            width: 3.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.labelMedium.copyWith(color: AppColors.onSurfaceVariant),
          ),
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(color: AppColors.onSurface),
          ),
        ],
      ),
    );
  }
}

class _StripedPainter extends CustomPainter {
  final Color color;

  _StripedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;

    for (double i = -size.height; i < size.width; i += 8.0) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
