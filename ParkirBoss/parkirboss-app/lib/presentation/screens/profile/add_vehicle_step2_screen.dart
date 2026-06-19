import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

/// Step 2 of 3 — upload/capture the vehicle's STNK (registration) photo.
/// The user may use the camera or pick an existing photo of the document.
class AddVehicleStep2Screen extends StatefulWidget {
  final Map<String, dynamic>? args;
  const AddVehicleStep2Screen({super.key, this.args});

  @override
  State<AddVehicleStep2Screen> createState() => _AddVehicleStep2ScreenState();
}

class _AddVehicleStep2ScreenState extends State<AddVehicleStep2Screen> {
  final ImagePicker _picker = ImagePicker();
  File? _stnkPhoto;

  String get _plate => (widget.args?['plate'] ?? '').toString();

  Future<void> _pick(ImageSource source) async {
    try {
      final f = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (f != null) setState(() => _stnkPhoto = File(f.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    }
  }

  void _goNext() {
    if (_stnkPhoto == null) return;
    Navigator.of(context).pushNamed(
      '/add-vehicle-step3',
      arguments: {'plate': _plate, 'stnk_path': _stnkPhoto!.path},
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _stnkPhoto != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'TAMBAH KENDARAAN',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.tertiary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
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
            // ─── Progress Header ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.margin),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                border: Border(bottom: BorderSide(color: AppColors.onBackground, width: 4.0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP 02 OF 03',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.onPrimaryContainer,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'FOTO STNK',
                    style: AppTypography.headlineLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.onPrimaryContainer,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Content ───────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.margin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_plate.isNotEmpty) ...[
                      Row(
                        children: [
                          Text('PLAT: ', style: AppTypography.labelMedium.copyWith(color: AppColors.onSurfaceVariant)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer,
                              border: Border.all(color: AppColors.onBackground, width: 2.0),
                            ),
                            child: Text(
                              _plate,
                              style: AppTypography.labelMedium.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Photo area
                    Container(
                      height: 240,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        border: Border.all(color: AppColors.onBackground, width: 4.0),
                        boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(4, 4))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasPhoto
                          ? Image.file(_stnkPhoto!, fit: BoxFit.cover, width: double.infinity)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.description, size: 48, color: AppColors.onSurface),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'FOTO STNK BELUM ADA',
                                  style: AppTypography.labelMedium.copyWith(color: AppColors.onSurface),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Camera + Gallery
                    Row(
                      children: [
                        Expanded(
                          child: BrutalistButton(
                            label: 'KAMERA',
                            leadingIcon: Icons.camera_alt,
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.onSurface,
                            onPressed: () => _pick(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: BrutalistButton(
                            label: 'GALERI',
                            leadingIcon: Icons.photo_library,
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.onSurface,
                            onPressed: () => _pick(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Helper
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixed,
                        border: Border.all(color: AppColors.onBackground, width: 4.0),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info, color: AppColors.onBackground),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Pastikan seluruh data pada STNK terbaca jelas. Foto ini wajib diisi untuk melanjutkan.',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onBackground,
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

            // ─── Bottom CTA (mandatory) ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.margin),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.onBackground, width: 4.0)),
              ),
              child: BrutalistButton(
                label: hasPhoto ? 'LANJUT' : 'AMBIL FOTO STNK DULU',
                trailingIcon: hasPhoto ? Icons.arrow_forward : null,
                backgroundColor: AppColors.tertiary,
                foregroundColor: AppColors.onTertiary,
                onPressed: hasPhoto ? _goNext : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
