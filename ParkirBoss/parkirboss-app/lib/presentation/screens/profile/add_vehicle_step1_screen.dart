import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class AddVehicleStep1Screen extends StatefulWidget {
  const AddVehicleStep1Screen({super.key});

  @override
  State<AddVehicleStep1Screen> createState() => _AddVehicleStep1ScreenState();
}

class _AddVehicleStep1ScreenState extends State<AddVehicleStep1Screen> {
  final TextEditingController _plateController = TextEditingController();

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  void _goNext() {
    final plate = _plateController.text.trim().toUpperCase();
    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor plat kendaraan')),
      );
      return;
    }
    // Carry the plate forward; the vehicle is saved at the final step.
    Navigator.of(context).pushNamed(
      '/add-vehicle-step2',
      arguments: {'plate': plate},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'ADD VEHICLE',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.onSurface,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
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
        child: Column(
          children: [
            // ─── Progress Bar ───────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: AppColors.tertiary,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.onBackground,
                    width: 4.0,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STEP 01 / PLAT NOMOR',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.onTertiary,
                      letterSpacing: 2.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.onTertiary,
                      border: Border.all(
                        color: AppColors.onBackground,
                        width: 2.0,
                      ),
                    ),
                    child: Text(
                      '1/3',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Main Content ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.margin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // License Plate Input
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(left: AppSpacing.sm),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            border: Border.all(color: AppColors.onBackground, width: 4.0),
                          ),
                          child: Text(
                            'LICENSE PLATE',
                            style: AppTypography.labelLarge,
                          ),
                        ),
                        // The actual input
                        Transform.translate(
                          offset: const Offset(0, -4),
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              border: Border.all(color: AppColors.onBackground, width: 4.0),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.onBackground,
                                  offset: Offset(4, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: TextField(
                                    controller: _plateController,
                                    textAlign: TextAlign.center,
                                    textCapitalization: TextCapitalization.characters,
                                    style: AppTypography.displaySmall.copyWith(
                                      fontFamily: 'monospace',
                                      letterSpacing: 4.0,
                                      fontWeight: FontWeight.w900,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'B 1234 XYZ',
                                      hintStyle: AppTypography.displaySmall.copyWith(
                                        fontFamily: 'monospace',
                                        letterSpacing: 4.0,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.outlineVariant,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                // Crosshairs
                                const Positioned(top: 8, left: 8, child: _Crosshair(topLeft: true)),
                                const Positioned(top: 8, right: 8, child: _Crosshair(topRight: true)),
                                const Positioned(bottom: 8, left: 8, child: _Crosshair(bottomLeft: true)),
                                const Positioned(bottom: 8, right: 8, child: _Crosshair(bottomRight: true)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxxl),

                    // Supplemental Info
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        border: Border.all(color: AppColors.onBackground, width: 4.0),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Pastikan nomor plat sesuai dengan dokumen resmi kendaraan untuk menghindari kesalahan validasi parkir.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Bottom Action ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.margin),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.onBackground,
                    width: 4.0,
                  ),
                ),
              ),
              child: BrutalistButton(
                label: 'LANJUT',
                trailingIcon: Icons.arrow_forward,
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryContainer,
                onPressed: _goNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Crosshair extends StatelessWidget {
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const _Crosshair({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: topLeft || topRight ? const BorderSide(color: AppColors.onBackground, width: 4.0) : BorderSide.none,
          bottom: bottomLeft || bottomRight ? const BorderSide(color: AppColors.onBackground, width: 4.0) : BorderSide.none,
          left: topLeft || bottomLeft ? const BorderSide(color: AppColors.onBackground, width: 4.0) : BorderSide.none,
          right: topRight || bottomRight ? const BorderSide(color: AppColors.onBackground, width: 4.0) : BorderSide.none,
        ),
      ),
    );
  }
}
