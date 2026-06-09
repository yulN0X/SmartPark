import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class TopUpSuccessScreen extends StatelessWidget {
  final Map<String, dynamic>? topUpData;
  const TopUpSuccessScreen({super.key, this.topUpData});

  String _fmt(num a) => 'Rp ${a.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final amount = (topUpData?['amount'] as num?)?.toDouble() ?? 100000.0;
    final newBalance = (topUpData?['new_balance'] as num?)?.toDouble() ?? 245000.0;
    final method = topUpData?['method'] ?? 'E-Wallet';
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final timeStr = '${now.day} ${months[now.month - 1]} ${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative background pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(
                  painter: _GridPainter(
                    color: AppColors.onBackground,
                    spacing: 24.0,
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin, vertical: AppSpacing.xxxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixed,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.onBackground,
                          width: 4.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.onBackground,
                            offset: Offset(6, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle,
                          color: AppColors.onBackground,
                          size: 72,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Headline
                    Text(
                      'TOP UP\nBERHASIL!',
                      textAlign: TextAlign.center,
                      style: AppTypography.displayLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: AppColors.onBackground,
                        height: 1.0,
                        letterSpacing: -2.0,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Transaction Details Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
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
                          _buildDetailRow('Jumlah Top Up', _fmt(amount), isHeadline: true, bgColor: AppColors.surfaceVariant),
                          _buildDetailRow('Metode', method),
                          _buildDetailRow('Waktu', timeStr, isLast: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Main Balance Summary
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.inverseSurface,
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SALDO BARU',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.surfaceVariant,
                            ),
                          ),
                          Text(
                            _fmt(newBalance),
                            style: AppTypography.headlineLarge.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.tertiaryFixed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),

                    // CTA Button
                    BrutalistButton(
                      label: 'KEMBALI KE BERANDA',
                      backgroundColor: AppColors.tertiaryFixed,
                      foregroundColor: AppColors.onBackground,
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHeadline = false, Color? bgColor, String? valueFontFamily, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.surface,
        border: isLast
            ? null
            : const Border(
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
            style: isHeadline
                ? AppTypography.labelMedium.copyWith(color: AppColors.onSurfaceVariant)
                : AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
          ),
          Flexible(
            child: Text(
              value.toUpperCase(),
              style: isHeadline
                  ? AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900)
                  : AppTypography.labelMedium.copyWith(fontFamily: valueFontFamily),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  final double spacing;

  _GridPainter({required this.color, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
