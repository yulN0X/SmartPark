import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';

class ExitBillingScreen extends StatelessWidget {
  final Map<String, dynamic>? billingData;
  const ExitBillingScreen({super.key, this.billingData});

  String _formatCurrency(num amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final plate = billingData?['plate'] ?? 'B 1234 ABC';
    final cost = (billingData?['cost'] as num?)?.toDouble() ?? 4800.0;
    final durationMin = (billingData?['duration_min'] as num?)?.toInt() ?? 88;
    final newBalance = (billingData?['new_balance'] as num?)?.toDouble() ?? 0.0;
    final hours = durationMin ~/ 60;
    final mins = durationMin % 60;
    final durationStr = '${hours}j ${mins}m';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary, elevation: 0, centerTitle: true,
        title: Text('VERIFIKASI KELUAR', style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(AppSpacing.borderMedium), child: Container(color: AppColors.onBackground, height: AppSpacing.borderMedium)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.margin).copyWith(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Plate Verification
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.onBackground, width: 3.0), boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(4, 4))]),
                  child: Container(
                    width: double.infinity, margin: const EdgeInsets.all(AppSpacing.sm), padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: AppColors.surfaceVariant, border: Border.all(color: AppColors.onBackground, width: 3.0)),
                    child: Column(children: [
                      Text(plate, style: AppTypography.displayMedium.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w900, letterSpacing: 4.0)),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(color: AppColors.primaryContainer, border: Border.all(color: AppColors.onBackground, width: 3.0), boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(2, 2))]),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_circle, color: AppColors.onPrimaryContainer, size: 20),
                          const SizedBox(width: AppSpacing.xs),
                          Text('PLAT TERVERIFIKASI', style: AppTypography.labelMedium.copyWith(color: AppColors.onPrimaryContainer)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // 2. Session Summary
                Container(
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, border: Border.all(color: AppColors.onBackground, width: 3.0), boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(4, 4))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: const BoxDecoration(color: AppColors.primary, border: Border(bottom: BorderSide(color: AppColors.onBackground, width: 3.0))),
                      child: Text('RINGKASAN SESI', style: AppTypography.labelLarge.copyWith(color: AppColors.onPrimary)),
                    ),
                    Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(children: [
                      _buildSummaryRow(icon: Icons.directions_car, iconColor: AppColors.primary, iconFg: AppColors.onPrimary, label: 'KENDARAAN', value: plate),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.onBackground, width: 3.0))),
                        child: _buildSummaryRow(icon: Icons.timer, iconColor: AppColors.surface, iconFg: AppColors.onBackground, label: 'DURASI TOTAL', value: durationStr, isHeadline: true),
                      ),
                    ])),
                  ]),
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // 3. Cost Breakdown
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md).copyWith(top: AppSpacing.xl),
                    decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.onBackground, width: 3.0), boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(4, 4))]),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Parkir ($durationStr)', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                        Text(_formatCurrency(cost), style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.onBackground, width: 3.0))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('TOTAL BAYAR', style: AppTypography.labelLarge),
                          Text(_formatCurrency(cost), style: AppTypography.headlineMedium.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w900)),
                        ]),
                      ),
                    ]),
                  ),
                  Positioned(top: -16, left: 16, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(color: AppColors.primary, border: Border.all(color: AppColors.onBackground, width: 3.0), boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(2, 2))]),
                    child: Text('RINCIAN BIAYA', style: AppTypography.labelMedium.copyWith(color: AppColors.onPrimary)),
                  )),
                ]),
                const SizedBox(height: AppSpacing.xl),

                // 4. Payment Method
                Text('METODE PEMBAYARAN', style: AppTypography.labelMedium.copyWith(color: AppColors.onBackground)),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(child: _buildPaymentMethod('E-Wallet', Icons.account_balance_wallet, true)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _buildPaymentMethod('QRIS', Icons.qr_code_scanner, false)),
                ]),
              ],
            ),
          ),

          // ─── Fixed CTA Bottom Bar ─────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.onBackground, width: 4.0))),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacementNamed('/digital-receipt', arguments: {
                    'plate': plate, 'cost': cost, 'duration_min': durationMin, 'new_balance': newBalance,
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.primaryContainer, border: Border.all(color: AppColors.onBackground, width: 4.0), boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(4, 4))]),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('BAYAR SEKARANG', style: AppTypography.headlineMedium.copyWith(color: AppColors.onPrimaryContainer, fontWeight: FontWeight.w900, letterSpacing: 2.0, fontSize: 20)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(color: AppColors.tertiary, border: Border.all(color: AppColors.onBackground, width: 3.0), boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(2, 2))]),
                      child: Text(_formatCurrency(cost), style: AppTypography.labelLarge.copyWith(color: AppColors.onTertiary)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({required IconData icon, required Color iconColor, required Color iconFg, required String label, required String value, bool isHeadline = false}) {
    return Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle, border: Border.all(color: AppColors.onBackground, width: 3.0), boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(2, 2))]), child: Icon(icon, color: iconFg, size: 20)),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant)),
        Text(value, style: isHeadline ? AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900) : AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
      ])),
    ]);
  }

  Widget _buildPaymentMethod(String label, IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: isSelected ? AppColors.tertiaryContainer : AppColors.surface, border: Border.all(color: AppColors.onBackground, width: 3.0), boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(4, 4))]),
      child: Center(child: Column(children: [
        Icon(icon, size: 32, color: isSelected ? AppColors.onTertiaryContainer : AppColors.onBackground),
        const SizedBox(height: AppSpacing.sm),
        Text(label.toUpperCase(), style: AppTypography.labelSmall.copyWith(color: isSelected ? AppColors.onTertiaryContainer : AppColors.onBackground)),
      ])),
    );
  }
}
