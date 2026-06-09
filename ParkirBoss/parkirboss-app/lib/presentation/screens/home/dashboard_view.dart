import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/core/services/wallet_service.dart';
import 'package:parkirboss/core/services/parking_service.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final WalletService _walletService = WalletService();
  final ParkingService _parkingService = ParkingService();
  
  double _balance = 0.0;
  Map<String, dynamic> _activeSession = {'active': false};
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final balance = await _walletService.getBalance();
      final session = await _parkingService.getActiveSession();
      final locations = await _parkingService.getLocations();
      if (mounted) {
        setState(() {
          _balance = balance;
          _activeSession = session;
          _locations = locations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.margin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Main Balance Card ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
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
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      Icons.account_balance_wallet,
                      size: 100,
                      color: AppColors.onPrimary.withOpacity(0.1),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MAIN BALANCE',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _isLoading
                        ? Text(
                            'Loading...',
                            style: AppTypography.displayLarge.copyWith(
                              color: AppColors.onPrimary,
                            ),
                          )
                        : Text(
                            _formatCurrency(_balance),
                            style: AppTypography.displayLarge.copyWith(
                              color: AppColors.onPrimary,
                            ),
                          ),
                      const SizedBox(height: AppSpacing.md),
                      BrutalistButton(
                        label: 'TOP UP',
                        trailingIcon: Icons.add,
                        backgroundColor: AppColors.tertiaryContainer,
                        foregroundColor: AppColors.onTertiaryContainer,
                        onPressed: () async {
                          await Navigator.of(context).pushNamed('/top-up');
                          _loadData(); // Refresh balance after returning
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ─── Low Balance Warning (active session only) ──────────────
            if (_activeSession['active'] == true &&
                _activeSession['balance_sufficient'] == false) ...[
              _buildLowBalanceWarning(),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ─── Active Session Card ────────────────────────────────────
            _activeSession['active'] == true
              ? _buildActiveSessionCard()
              : _buildNoActiveSessionCard(),
            const SizedBox(height: AppSpacing.xl),

            // ─── Nearby Availability ────────────────────────────────────
            Container(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.tertiary,
                    width: 8.0,
                  ),
                ),
              ),
              child: Text(
                'NEARBY SLOTS',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Nearby parking locations from API (live availability)
            if (_isLoading && _locations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.tertiary,
                    strokeWidth: 4,
                  ),
                ),
              )
            else if (_locations.isEmpty)
              Text(
                'Tidak ada lokasi parkir terdekat.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              )
            else
              ...List.generate(_locations.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _locations.length - 1 ? AppSpacing.sm : 0,
                  ),
                  child: _buildNearbyFromData(_locations[index]),
                );
              }),
            const SizedBox(height: AppSpacing.xl),

            // ─── Promo Banner ───────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.tertiary,
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
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: -20,
                    child: Icon(
                      Icons.local_activity,
                      size: 150,
                      color: AppColors.onSurface.withOpacity(0.2),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        color: AppColors.onSurface,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        child: Text(
                          'WEEKEND SPECIAL',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.surface,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '50% OFF\nPARKING',
                        style: AppTypography.displayMedium.copyWith(
                          color: AppColors.onTertiary,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      BrutalistButton(
                        label: 'CLAIM NOW',
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.onSurface,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard() {
    final plate = _activeSession['plate'] ?? 'B 1234 ABC';
    final durationMin = _activeSession['duration_minutes'] ?? 0;
    final hours = durationMin ~/ 60;
    final mins = durationMin % 60;
    final timeStr = '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:00';
    final cost = (_activeSession['current_cost'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/active-session'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.onSurface,
                    width: AppSpacing.borderMedium,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          border: Border.all(color: AppColors.onSurface, width: 2),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'ACTIVE SESSION',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    color: AppColors.onSurface,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: AppColors.surface, size: 14),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          timeStr,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.surface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.onSurface, width: 2.0),
                        ),
                        child: Text(
                          plate,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _formatCurrency(cost),
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.tertiary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BrutalistButton(
                    label: 'VIEW DETAILS',
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                    onPressed: () => Navigator.pushNamed(context, '/active-session'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoActiveSessionCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.local_parking, size: 48, color: AppColors.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'TIDAK ADA SESI AKTIF',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Parkir melalui gate masuk untuk memulai sesi',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowBalanceWarning() {
    final balance = (_activeSession['user_balance'] as num?)?.toDouble() ?? _balance;
    final cost = (_activeSession['current_cost'] as num?)?.toDouble() ?? 0.0;
    final shortfall = (cost - balance).clamp(0, double.infinity).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        border: Border.all(
          color: AppColors.onSurface,
          width: AppSpacing.borderMedium,
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.onSurface, offset: Offset(4, 4)),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  border: Border.all(color: AppColors.onSurface, width: 2.0),
                ),
                child: const Icon(Icons.warning_amber, color: AppColors.onError),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALDO TIDAK CUKUP',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      shortfall > 0
                        ? 'Biaya berjalan ${_formatCurrency(cost)} melebihi saldo ${_formatCurrency(balance)}. Kurang ${_formatCurrency(shortfall)}. Top up agar tidak terkunci di gate keluar.'
                        : 'Saldo Anda menipis untuk biaya parkir berjalan. Segera top up.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          BrutalistButton(
            label: 'TOP UP SEKARANG',
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.onSurface,
            onPressed: () async {
              await Navigator.of(context).pushNamed('/top-up');
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyFromData(Map<String, dynamic> loc) {
    final name = (loc['name'] ?? '-').toString();
    final distanceKm = (loc['distance_km'] as num?)?.toDouble() ?? 0.0;
    final available = (loc['available_slots'] as num?)?.toInt() ?? 0;
    final total = (loc['total_slots'] as num?)?.toInt() ?? 0;
    final occupancy = (loc['occupancy'] as num?)?.toDouble() ?? 0.0;
    final status = (loc['status'] ?? 'AVAILABLE').toString();

    Color statusBg;
    Color statusFg;
    Color progressColor;
    switch (status) {
      case 'FULL':
        statusBg = AppColors.error;
        statusFg = AppColors.onError;
        progressColor = AppColors.error;
        break;
      case 'FAST FILLING':
        statusBg = AppColors.secondary;
        statusFg = AppColors.onSecondary;
        progressColor = AppColors.error;
        break;
      default:
        statusBg = Colors.greenAccent;
        statusFg = AppColors.onSurface;
        progressColor = AppColors.tertiaryContainer;
    }

    return _buildNearbyLocation(
      title: name,
      distance: '${distanceKm.toStringAsFixed(1)} km away',
      status: status,
      statusColor: statusFg,
      statusBgColor: statusBg,
      progress: occupancy,
      progressColor: progressColor,
      availableSlots: '$available/$total',
    );
  }

  Widget _buildNearbyLocation({
    required String title,
    required String distance,
    required String status,
    required Color statusColor,
    required Color statusBgColor,
    required double progress,
    required Color progressColor,
    required String availableSlots,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.onSurface,
          width: AppSpacing.borderMedium,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.onSurface,
            offset: Offset(2, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    distance,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  border: Border.all(color: AppColors.onSurface, width: 2.0),
                ),
                child: Text(
                  status,
                  style: AppTypography.labelSmall.copyWith(
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    border: Border.all(
                      color: AppColors.onSurface,
                      width: 2.0,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          width: constraints.maxWidth * progress,
                          height: double.infinity,
                          color: progressColor,
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 64,
                child: Text(
                  availableSlots,
                  textAlign: TextAlign.right,
                  style: AppTypography.labelMedium.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
