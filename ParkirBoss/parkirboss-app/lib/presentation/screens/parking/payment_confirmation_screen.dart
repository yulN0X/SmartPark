import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class PaymentConfirmationScreen extends StatelessWidget {
  const PaymentConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'PARKIR BOSS',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: AppColors.tertiary,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.onSurface, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppSpacing.borderMedium),
          child: Container(
            color: AppColors.onBackground,
            height: AppSpacing.borderMedium,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin, vertical: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Success Banner Hero ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.tertiaryFixed,
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
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.onBackground, width: AppSpacing.borderMedium),
                          left: BorderSide(color: AppColors.onBackground, width: AppSpacing.borderMedium),
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
                          bottom: BorderSide(color: AppColors.onBackground, width: AppSpacing.borderMedium),
                          right: BorderSide(color: AppColors.onBackground, width: AppSpacing.borderMedium),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.onBackground,
                          size: 72,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'PAYMENT\nCONFIRMED',
                          textAlign: TextAlign.center,
                          style: AppTypography.displaySmall.copyWith(
                            color: AppColors.onBackground,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Your parking slot is officially locked in.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ─── Receipt Details Card ────────────────────────────────────
            Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Amount Header
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainer,
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.onBackground,
                          width: AppSpacing.borderMedium,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL AUTHORIZED',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'Rp ',
                              style: AppTypography.headlineMedium.copyWith(
                                color: AppColors.onBackground,
                              ),
                            ),
                            Text(
                              '24.500',
                              style: AppTypography.displayLarge.copyWith(
                                color: AppColors.onBackground,
                                letterSpacing: -1.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Meta Grid
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: AppColors.onBackground,
                                  width: AppSpacing.borderMedium,
                                ),
                                bottom: BorderSide(
                                  color: AppColors.onBackground,
                                  width: AppSpacing.borderMedium,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'METHOD',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.onSurfaceVariant, // Outline color
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    const Icon(Icons.credit_card, color: AppColors.onBackground),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      '**** 8902',
                                      style: AppTypography.labelMedium.copyWith(
                                        color: AppColors.onBackground,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.onBackground,
                                  width: AppSpacing.borderMedium,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DATE & TIME',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'OCT 28, 2023\n14:30 PM',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.onBackground,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Line Items
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        _buildLineItem('Location', 'Sector 7G - North'),
                        const SizedBox(height: AppSpacing.md),
                        _buildLineItem('Duration', '4 Hours'),
                        const SizedBox(height: AppSpacing.md),
                        _buildLineItem('Vehicle Plate', 'XYZ-9876', isTrackingWidest: true, noBorder: true),
                      ],
                    ),
                  ),

                  // Barcode Footer
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      border: Border(
                        top: BorderSide(
                          color: AppColors.onBackground,
                          width: AppSpacing.borderMedium,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(
                              14,
                              (index) => Container(
                                width: [4.0, 12.0, 4.0, 8.0, 16.0, 4.0, 8.0, 12.0, 4.0, 8.0, 4.0, 16.0, 4.0, 8.0][index],
                                height: [48.0, 48.0, 38.0, 48.0, 48.0, 38.0, 48.0, 48.0, 48.0, 38.0, 48.0, 48.0, 48.0, 48.0][index],
                                color: AppColors.onBackground.withOpacity(0.8),
                                margin: const EdgeInsets.symmetric(horizontal: 1.0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'REF: PB-492-XQ',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.onSurface,
                            letterSpacing: 4.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),

            // ─── Fixed Action Area ───────────────────────────────────────
            BrutalistButton(
              label: 'VIEW ACTIVE TICKET',
              leadingIcon: Icons.confirmation_number,
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimaryContainer,
              onPressed: () {},
            ),
            const SizedBox(height: AppSpacing.md),
            BrutalistButton(
              label: 'RETURN TO HOME',
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.onSurface,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItem(String label, String value, {bool isTrackingWidest = false, bool noBorder = false}) {
    return Container(
      padding: EdgeInsets.only(bottom: noBorder ? 0 : AppSpacing.xs),
      decoration: BoxDecoration(
        border: noBorder
            ? null
            : const Border(
                bottom: BorderSide(
                  color: AppColors.outlineVariant,
                  width: 2.0,
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            value.toUpperCase(),
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.onBackground,
              letterSpacing: isTrackingWidest ? 2.0 : null,
            ),
          ),
        ],
      ),
    );
  }
}
