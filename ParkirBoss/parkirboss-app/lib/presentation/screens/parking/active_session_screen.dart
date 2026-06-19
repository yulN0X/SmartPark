import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/core/services/parking_service.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class ActiveSessionScreen extends StatefulWidget {
  final Map<String, dynamic>? sessionData;
  
  const ActiveSessionScreen({super.key, this.sessionData});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  final ParkingService _parkingService = ParkingService();
  Map<String, dynamic> _session = {};
  bool _isLoading = true;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  DateTime? _entryTime;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    if (widget.sessionData != null) {
      _parseSession(widget.sessionData!);
    } else {
      setState(() => _isLoading = true);
      final data = await _parkingService.getActiveSession();
      if (mounted && data['active'] == true) {
        _parseSession(data);
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _parseSession(Map<String, dynamic> data) {
    _session = data;
    try {
      _entryTime = DateTime.parse(data['entry_time'] ?? '');
    } catch (_) {
      _entryTime = DateTime.now();
    }
    _updateElapsed();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());
    setState(() => _isLoading = false);
  }

  void _updateElapsed() {
    if (_entryTime != null && mounted) {
      setState(() {
        _elapsed = DateTime.now().difference(_entryTime!);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatCurrency(num amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '--:--';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  double get _estimatedCost {
    final ratePerHour = (_session['rate_per_hour'] as num?)?.toDouble() ?? 3000.0;
    final hours = _elapsed.inMinutes / 60.0;
    return (hours.ceil()) * ratePerHour;
  }

  @override
  Widget build(BuildContext context) {
    final plate = _session['plate_number'] ?? _session['plate'] ?? 'B 1234 ABC';
    final gateIn = _session['gate_in_id'] ?? 'Gate';
    final ratePerHour = (_session['rate_per_hour'] as num?)?.toDouble() ?? 3000.0;
    final entryTimeStr = _formatTime(_session['entry_time']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        title: Text(
          'SESI PARKIR AKTIF',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.onPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.tertiary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.margin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Location Header Section ──────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryContainer,
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
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Icon(
                            Icons.qr_code_scanner,
                            size: 100,
                            color: AppColors.onTertiaryContainer.withOpacity(0.1),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gateIn.toUpperCase(),
                              style: AppTypography.displaySmall.copyWith(
                                color: AppColors.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.onBackground,
                                        width: 2.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'AKTIF',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.onPrimaryContainer,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
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
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(AppSpacing.xs),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondaryContainer,
                                          border: Border.all(
                                            color: AppColors.onBackground,
                                            width: 2.0,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: AppColors.onBackground,
                                              offset: Offset(2, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.directions_car,
                                          color: AppColors.onSecondaryContainer,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'KENDARAAN',
                                            style: AppTypography.labelSmall.copyWith(
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                          Text(
                                            plate,
                                            style: AppTypography.headlineMedium.copyWith(
                                              fontFamily: 'monospace',
                                              color: AppColors.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ─── Live Metrics Section ──────────────────────────────────
                  Container(
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
                    child: Column(
                      children: [
                        Text(
                          'DURASI BERJALAN',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _formatDuration(_elapsed),
                          style: AppTypography.displayLarge.copyWith(
                            color: AppColors.primary,
                            fontFamily: 'monospace',
                            letterSpacing: -2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ESTIMASI BIAYA',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.primaryFixedDim,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _formatCurrency(_estimatedCost),
                                style: AppTypography.headlineMedium.copyWith(
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TARIF',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              RichText(
                                text: TextSpan(
                                  style: AppTypography.headlineMedium.copyWith(
                                    color: AppColors.onSurface,
                                  ),
                                  children: [
                                    TextSpan(text: '${_formatCurrency(ratePerHour)}\n'),
                                    TextSpan(
                                      text: '/jam',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ─── Timeline Section ──────────────────────────────────────
                  Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.onSurface,
                                width: AppSpacing.borderMedium,
                              ),
                            ),
                          ),
                          child: Text(
                            'GARIS WAKTU',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            border: Border.all(
                              color: AppColors.onBackground,
                              width: 3.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: (_elapsed.inMinutes).clamp(1, 100),
                                child: Container(
                                  color: AppColors.tertiaryContainer,
                                ),
                              ),
                              Expanded(
                                flex: (100 - _elapsed.inMinutes).clamp(1, 100),
                                child: const SizedBox(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('MASUK', style: AppTypography.labelSmall),
                                Text(entryTimeStr, style: AppTypography.bodyMedium.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('SEKARANG', style: AppTypography.labelSmall.copyWith(color: AppColors.primary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('EST. KELUAR', style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant)),
                                Text('--:--', style: AppTypography.bodyMedium.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  // ─── Actions Section ───────────────────────────────────────
                  BrutalistButton(
                    label: 'Selesai Parkir',
                    backgroundColor: AppColors.errorContainer,
                    foregroundColor: AppColors.onErrorContainer,
                    borderColor: AppColors.error,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: AppColors.onSurface, width: 3),
                            borderRadius: BorderRadius.circular(0),
                          ),
                          title: Text('KELUAR PARKIR', style: AppTypography.headlineSmall),
                          content: Text(
                            'Sesi parkir Anda akan otomatis selesai saat kendaraan terdeteksi oleh kamera di gate keluar. Tidak perlu tindakan manual.',
                            style: AppTypography.bodyMedium,
                          ),
                          actions: [
                            BrutalistButton(
                              label: 'MENGERTI',
                              isFullWidth: false,
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: AppColors.onPrimaryContainer,
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }
}
