import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/core/services/parking_service.dart';

class SessionsView extends StatefulWidget {
  const SessionsView({super.key});

  @override
  State<SessionsView> createState() => _SessionsViewState();
}

class _SessionsViewState extends State<SessionsView> {
  final ParkingService _parkingService = ParkingService();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _parkingService.getHistory();
      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(num amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '-';
    try {
      final dt = DateTime.parse(isoString);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.margin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Page Title ──────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
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
                    'PARKING HISTORY',
                    style: AppTypography.displayMedium.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Review your past parking sessions and receipts.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // ─── Content ───────────────────────────────────────────────
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
            else if (_history.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
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
                  children: [
                    const Icon(Icons.history, size: 48, color: AppColors.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'BELUM ADA RIWAYAT',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Riwayat parkir akan muncul setelah sesi selesai.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_history.length, (index) {
                final item = _history[index];
                final status = (item['status'] ?? 'COMPLETED').toString().toUpperCase();
                final isCancelled = status == 'CANCELLED' || status == 'BATAL';
                final plate = item['plate_number'] ?? item['plate'] ?? '-';
                final cost = (item['total_cost'] as num?)?.toDouble() ?? 0.0;
                final gateIn = item['gate_in_id'] ?? 'Unknown';
                final entryTime = _formatDateTime(item['entry_time']);
                final exitTime = item['exit_time'] != null 
                    ? _formatDateTime(item['exit_time']) 
                    : '';
                final dateStr = exitTime.isNotEmpty 
                    ? '$entryTime - ${exitTime.split('•').last.trim()}'
                    : entryTime;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _history.length - 1 ? AppSpacing.md : 0,
                  ),
                  child: _buildHistoryItem(
                    context: context,
                    plate: plate,
                    status: isCancelled ? 'BATAL' : 'LUNAS',
                    location: gateIn,
                    date: dateStr,
                    price: _formatCurrency(cost),
                    plateColor: AppColors.primaryContainer,
                    plateFg: AppColors.onPrimaryContainer,
                    statusColor: isCancelled ? AppColors.errorContainer : AppColors.tertiaryContainer,
                    statusFg: isCancelled ? AppColors.onErrorContainer : AppColors.onTertiaryContainer,
                    isCancelled: isCancelled,
                    sessionData: item,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem({
    required BuildContext context,
    required String plate,
    required String status,
    required String location,
    required String date,
    required String price,
    required Color plateColor,
    required Color plateFg,
    required Color statusColor,
    required Color statusFg,
    bool isCancelled = false,
    Map<String, dynamic>? sessionData,
  }) {
    return GestureDetector(
      onTap: () {
        if (!isCancelled) {
          Navigator.pushNamed(context, '/digital-receipt', arguments: sessionData);
        }
      },
      child: Opacity(
        opacity: isCancelled ? 0.75 : 1.0,
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
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: plateColor,
                      border: Border.all(
                        color: AppColors.onSurface,
                        width: 2.0,
                      ),
                    ),
                    child: Text(
                      plate,
                      style: AppTypography.labelSmall.copyWith(
                        color: plateFg,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: statusColor,
                      border: Border.all(
                        color: AppColors.onSurface,
                        width: 2.0,
                      ),
                    ),
                    child: Text(
                      status,
                      style: AppTypography.labelSmall.copyWith(
                        color: statusFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.toUpperCase(),
                          style: AppTypography.labelLarge.copyWith(
                            color: isCancelled ? AppColors.onSurfaceVariant : AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          date,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    price,
                    style: AppTypography.headlineMedium.copyWith(
                      color: isCancelled ? AppColors.onSurfaceVariant : AppColors.onSurface,
                      fontWeight: FontWeight.w900,
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
