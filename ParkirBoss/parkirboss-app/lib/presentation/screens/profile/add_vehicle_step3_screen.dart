import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/core/services/vehicle_service.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

/// Step 3 of 3 — the vehicle photo MUST be captured live with the camera
/// (no gallery), then the vehicle is saved.
class AddVehicleStep3Screen extends StatefulWidget {
  final Map<String, dynamic>? args;
  const AddVehicleStep3Screen({super.key, this.args});

  @override
  State<AddVehicleStep3Screen> createState() => _AddVehicleStep3ScreenState();
}

class _AddVehicleStep3ScreenState extends State<AddVehicleStep3Screen> {
  final ImagePicker _picker = ImagePicker();
  final VehicleService _vehicleService = VehicleService();
  File? _vehiclePhoto;
  bool _isSaving = false;

  String get _plate => (widget.args?['plate'] ?? '').toString();

  Future<void> _capture() async {
    try {
      // Camera only — the user must take the photo on the spot.
      final f = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (f != null) setState(() => _vehiclePhoto = File(f.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_vehiclePhoto == null || _isSaving) return;
    setState(() => _isSaving = true);
    final success = await _vehicleService.addVehicle(_plate);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.onSurface, width: 3),
            borderRadius: BorderRadius.circular(0),
          ),
          title: Text('BERHASIL', style: AppTypography.headlineSmall),
          content: Text(
            'Kendaraan $_plate berhasil ditambahkan.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            BrutalistButton(
              label: 'SELESAI',
              isFullWidth: false,
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimaryContainer,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      if (!mounted) return;
      // Pop the whole add-vehicle flow back to the vehicle list.
      Navigator.of(context).popUntil(
        (route) => route.settings.name == '/vehicle-management' || route.isFirst,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan kendaraan, coba lagi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _vehiclePhoto != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          'TAMBAH KENDARAAN',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.onPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppSpacing.borderMedium),
          child: Container(color: AppColors.onBackground, height: AppSpacing.borderMedium),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.margin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'STEP 03 OF 03',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'FOTO KENDARAAN',
                      style: AppTypography.headlineLarge.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Potret kendaraan Anda secara langsung. Foto wajib diambil dari kamera.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Live-capture area
                    InkWell(
                      onTap: _isSaving ? null : _capture,
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            border: Border.all(color: AppColors.onBackground, width: 4.0),
                            boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(4, 4))],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: hasPhoto
                              ? Image.file(_vehiclePhoto!, fit: BoxFit.cover, width: double.infinity)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerLowest,
                                        border: Border.all(color: AppColors.onBackground, width: 3.0),
                                        boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(4, 4))],
                                      ),
                                      child: const Icon(Icons.photo_camera, size: 32, color: AppColors.onSurface),
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    Text(
                                      'KETUK UNTUK MEMOTRET',
                                      style: AppTypography.labelLarge.copyWith(color: AppColors.onSurface),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    if (hasPhoto)
                      BrutalistButton(
                        label: 'POTRET ULANG',
                        leadingIcon: Icons.refresh,
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.onSurface,
                        onPressed: _isSaving ? null : _capture,
                      ),
                  ],
                ),
              ),
            ),

            // ─── Bottom CTA (mandatory) ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.margin),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.onBackground, width: 4.0)),
              ),
              child: BrutalistButton(
                label: _isSaving
                    ? 'MENYIMPAN...'
                    : (hasPhoto ? 'SIMPAN KENDARAAN' : 'POTRET KENDARAAN DULU'),
                leadingIcon: hasPhoto && !_isSaving ? Icons.check : null,
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                onPressed: (hasPhoto && !_isSaving) ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
