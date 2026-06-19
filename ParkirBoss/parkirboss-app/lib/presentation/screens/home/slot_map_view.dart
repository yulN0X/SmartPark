import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class SlotMapView extends StatefulWidget {
  const SlotMapView({super.key});

  @override
  State<SlotMapView> createState() => _SlotMapViewState();
}

class _SlotMapViewState extends State<SlotMapView> {
  int _selectedFloor = 0;
  String _selectedSlot = 'A3';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: AppSpacing.margin,
            right: AppSpacing.margin,
            top: AppSpacing.margin,
            bottom: 200, // Space for bottom sheet
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header Info ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer, // equivalent to primary-fixed somewhat
                  border: Border.all(
                    color: AppColors.onSurface,
                    width: AppSpacing.borderMedium,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.onSurface,
                      offset: Offset(4, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PILIH SLOT PARKIR',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: AppColors.onSurface,
                            width: 3.0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 18, color: AppColors.onSurface),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'CENTRAL PLAZA · 24 SLOT TERSEDIA',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ─── Floor Tabs ─────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.onSurface,
                        width: 3.0,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildFloorTab(0, 'LANTAI A'),
                      const SizedBox(width: AppSpacing.md),
                      _buildFloorTab(1, 'LANTAI B'),
                      const SizedBox(width: AppSpacing.md),
                      _buildFloorTab(2, 'LANTAI C'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ─── Parking Grid ───────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildSlot('A1', AppColors.surface, AppColors.onSurface)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: _buildSlot('A2', AppColors.error, AppColors.onError)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: _buildSlot('A3', AppColors.tertiary, AppColors.onTertiary, isSelected: true, badge: 'TERDEKAT')),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(child: _buildSlot('B1', AppColors.surface, AppColors.onSurface)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: _buildSlot('B2', AppColors.surface, AppColors.onSurface)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: _buildSlot('B3', AppColors.error, AppColors.onError)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(child: _buildSlot('C1', AppColors.primaryContainer, AppColors.onPrimaryContainer)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: _buildSlot('C2', AppColors.surface, AppColors.onSurface)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: _buildSlot('C3', AppColors.surface, AppColors.onSurface)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildSlot('A4', AppColors.primaryContainer, AppColors.onPrimaryContainer)),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: _buildSlot('X', AppColors.surfaceVariant, AppColors.onSurfaceVariant, isIcon: true, icon: Icons.close)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          height: 180, // Approximate height for spanning 2 rows
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            border: Border.all(
                              color: AppColors.onSurface,
                              width: 3.0,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(
                                  color: AppColors.onSurface,
                                  width: 2.0,
                                ),
                              ),
                              child: Text(
                                'JALUR KELUAR',
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ─── Bottom Sheet Action ────────────────────────────────────
        if (_selectedSlot.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.margin),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.onSurface,
                    width: AppSpacing.borderMedium,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'SLOT $_selectedSlot',
                                style: AppTypography.headlineMedium.copyWith(
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.onSurface,
                                    width: 3.0,
                                  ),
                                ),
                                child: Text(
                                  'TERSEDIA',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Lantai A · 12m dari Gate A',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.tertiaryContainer,
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
                          Icons.directions_car,
                          color: AppColors.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  BrutalistButton(
                    label: 'CLAIM SLOT INI',
                    backgroundColor: AppColors.tertiary,
                    foregroundColor: AppColors.onTertiary,
                    onPressed: () {
                      Navigator.of(context).pushNamed('/claim-confirmed');
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFloorTab(int index, String title) {
    final isActive = _selectedFloor == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFloor = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isActive ? AppColors.tertiary : AppColors.surface,
          border: Border.all(
            color: AppColors.onSurface,
            width: 3.0,
          ),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: AppColors.onSurface,
                    offset: Offset(4, 4),
                  ),
                ]
              : null,
        ),
        transform: isActive ? Matrix4.translationValues(0, -4, 0) : null,
        child: Text(
          title,
          style: AppTypography.labelMedium.copyWith(
            color: isActive ? AppColors.onTertiary : AppColors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildSlot(String label, Color bgColor, Color fgColor, {bool isSelected = false, bool isIcon = false, IconData? icon, String? badge}) {
    return GestureDetector(
      onTap: () {
        if (!isIcon) {
          setState(() {
            _selectedSlot = label;
          });
        }
      },
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: AppColors.onSurface,
            width: 3.0,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: AppColors.onSurface,
                    offset: Offset(4, 4),
                  ),
                ]
              : null,
        ),
        transform: isSelected ? Matrix4.translationValues(0, -4, 0) : null,
        child: Stack(
          children: [
            Center(
              child: isIcon
                  ? Icon(icon, color: fgColor)
                  : Text(
                      label,
                      style: AppTypography.labelMedium.copyWith(
                        color: fgColor,
                      ),
                    ),
            ),
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    border: Border.all(
                      color: AppColors.onSurface,
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    badge,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onSecondary,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
