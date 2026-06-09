import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class DigitalReceiptScreen extends StatelessWidget {
  final Map<String, dynamic>? receiptData;
  const DigitalReceiptScreen({super.key, this.receiptData});

  String _fmt(num a) => 'Rp ${a.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  @override
  Widget build(BuildContext context) {
    final plate = receiptData?['plate_number'] ?? receiptData?['plate'] ?? 'B 1234 XYZ';
    final cost = (receiptData?['total_cost'] ?? receiptData?['cost'] as num?)?.toDouble() ?? 4800.0;
    final durationMin = (receiptData?['duration_min'] as num?)?.toInt() ?? 150;
    final hours = durationMin ~/ 60;
    final mins = durationMin % 60;
    final durationStr = '$hours Jam $mins Menit';
    final gateIn = receiptData?['gate_in_id'] ?? 'Gate';
    final sessionId = receiptData?['id'] ?? receiptData?['session_id'] ?? 'PB-XXXX';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.margin, top: AppSpacing.sm, bottom: AppSpacing.sm),
          child: Container(decoration: BoxDecoration(color: AppColors.surfaceVariant, border: Border.all(color: AppColors.onBackground, width: AppSpacing.borderMedium), shape: BoxShape.circle), child: const Icon(Icons.person, color: AppColors.onSurfaceVariant)),
        ),
        title: Text('PARKIR BOSS', style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: AppColors.tertiary, letterSpacing: -1.0)),
        centerTitle: true,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(AppSpacing.borderMedium), child: Container(color: AppColors.onBackground, height: AppSpacing.borderMedium)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.margin),
        child: Column(children: [
          // ─── Success Header ──────────────────────────────────────────
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.tertiaryContainer, shape: BoxShape.circle, border: Border.all(color: AppColors.onBackground, width: 6.0), boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(6, 6))]),
            child: const Center(child: Icon(Icons.check, size: 48, color: AppColors.onTertiaryContainer)),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('PEMBAYARAN\nBERHASIL!', textAlign: TextAlign.center, style: AppTypography.displaySmall.copyWith(fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1.1)),
          const SizedBox(height: AppSpacing.xl),

          // ─── Receipt Card ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, border: Border.all(color: AppColors.onBackground, width: AppSpacing.borderMedium), boxShadow: const [BoxShadow(color: AppColors.onBackground, offset: Offset(6, 6))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PARKIR BOSS', style: AppTypography.labelLarge),
                  Text('Digital Receipt', style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, border: Border.all(color: AppColors.onBackground, width: 2.0)),
                  child: Text(sessionId.toString().length > 15 ? sessionId.toString().substring(0, 15) : sessionId.toString(), style: AppTypography.bodySmall.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              _buildDashedLine(),
              const SizedBox(height: AppSpacing.md),

              Row(children: [
                Expanded(child: _buildDetailItem('LOKASI', gateIn)),
                Expanded(child: _buildDetailItem('DURASI', durationStr)),
              ]),
              const SizedBox(height: AppSpacing.sm),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('KENDARAAN', style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(color: AppColors.secondaryContainer, border: Border.all(color: AppColors.onBackground, width: 2.0)),
                  child: Text(plate, style: AppTypography.bodyMedium.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer)),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              _buildDashedLine(),
              const SizedBox(height: AppSpacing.md),

              Container(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.onBackground, width: 2.0))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('TOTAL BAYAR', style: AppTypography.labelLarge),
                  Text(_fmt(cost), style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),

              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: AppColors.inverseSurface, border: Border.all(color: AppColors.onBackground, width: 2.0)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('METODE', style: AppTypography.labelSmall.copyWith(color: AppColors.inverseOnSurface)),
                  Text('E-Wallet', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.inverseOnSurface)),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),

              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.onBackground, width: AppSpacing.borderMedium)),
                child: Column(children: [
                  const Icon(Icons.qr_code_2, size: 120, color: AppColors.onBackground),
                  const SizedBox(height: AppSpacing.xs),
                  Text('SCAN UNTUK KELUAR GATE', style: AppTypography.labelSmall),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ─── Actions ──────────────────────────────────────────────────
          BrutalistButton(
            label: 'SELESAI',
            backgroundColor: AppColors.tertiary,
            foregroundColor: AppColors.onTertiary,
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false),
          ),
        ]),
      ),
    );
  }

  Widget _buildDashedLine() {
    return SizedBox(height: 4, child: LayoutBuilder(builder: (context, constraints) {
      final boxWidth = constraints.constrainWidth();
      const dashWidth = 8.0;
      const dashSpace = 4.0;
      final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(dashCount, (_) => Container(width: dashWidth, height: 4, color: AppColors.onBackground)));
    }));
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant)),
      Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
    ]);
  }
}
