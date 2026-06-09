import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/core/services/vehicle_service.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  final VehicleService _vehicleService = VehicleService();
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoading = true);
    final vehicles = await _vehicleService.getVehicles();
    if (mounted) {
      setState(() {
        _vehicles = vehicles;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteVehicle(String vehicleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('HAPUS KENDARAAN', style: AppTypography.headlineSmall),
        content: Text('Apakah Anda yakin ingin menghapus kendaraan ini?', style: AppTypography.bodyMedium),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.onSurface, width: 3),
          borderRadius: BorderRadius.circular(0),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _vehicleService.deleteVehicle(vehicleId);
      if (success) {
        _loadVehicles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kendaraan berhasil dihapus')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menghapus kendaraan')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'PARKIR BOSS',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: AppColors.tertiary,
            letterSpacing: -1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.tertiary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).pushNamed('/notifications');
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppSpacing.borderMedium),
          child: Container(
            color: AppColors.onBackground,
            height: AppSpacing.borderMedium,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadVehicles,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.margin).copyWith(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header ───────────────────────────────────────────────────
              Text(
                'KENDARAAN SAYA',
                style: AppTypography.headlineLarge.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Kelola kendaraan yang terdaftar untuk akses parkir cepat.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ─── Add Vehicle Button ───────────────────────────────────────
              BrutalistButton(
                label: 'Tambah Kendaraan',
                leadingIcon: Icons.add_circle,
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryContainer,
                onPressed: () async {
                  await Navigator.of(context).pushNamed('/add-vehicle-step1');
                  _loadVehicles(); // Refresh after returning
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // ─── Vehicle List ─────────────────────────────────────────────
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xxxl),
                    child: CircularProgressIndicator(
                      color: AppColors.tertiary,
                      strokeWidth: 4,
                    ),
                  ),
                )
              else if (_vehicles.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xxxl),
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
                      const Icon(Icons.directions_car, size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'BELUM ADA KENDARAAN',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Tambah kendaraan untuk mulai parkir.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(_vehicles.length, (index) {
                  final v = _vehicles[index];
                  final plate = v['plate_number'] ?? '-';
                  final brand = v['brand'] ?? v['color'] ?? 'Kendaraan';
                  final id = v['id'] ?? '';
                  final isMotor = plate.contains('D') || (v['type'] ?? '').toString().toLowerCase().contains('motor');
                  
                  return Padding(
                    padding: EdgeInsets.only(bottom: index < _vehicles.length - 1 ? AppSpacing.md : 0),
                    child: _buildVehicleCard(
                      headerColor: index % 2 == 0 ? AppColors.tertiaryFixed : AppColors.secondaryFixed,
                      typeLabel: isMotor ? 'MOTOR' : 'MOBIL',
                      plateNumber: plate,
                      icon: isMotor ? Icons.two_wheeler : Icons.directions_car,
                      brandType: brand,
                      vehicleId: id,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard({
    required Color headerColor,
    required String typeLabel,
    required String plateNumber,
    required IconData icon,
    required String brandType,
    required String vehicleId,
  }) {
    return Container(
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
          // Top Part (Header)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: headerColor,
              border: const Border(
                bottom: BorderSide(
                  color: AppColors.onBackground,
                  width: 3.0,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                      color: AppColors.onBackground,
                      child: Text(
                        typeLabel,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      plateNumber,
                      style: AppTypography.headlineMedium.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
                Icon(
                  icon,
                  size: 32,
                  color: AppColors.onBackground,
                ),
              ],
            ),
          ),
          
          // Bottom Part
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEREK / TIPE',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      brandType,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Delete Button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.error,
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
                      child: IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        color: AppColors.onError,
                        padding: EdgeInsets.zero,
                        onPressed: () => _deleteVehicle(vehicleId),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
