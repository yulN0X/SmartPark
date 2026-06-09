import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/core/services/wallet_service.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  int _selectedAmount = 100000;
  final TextEditingController _amountController = TextEditingController();
  final WalletService _walletService = WalletService();
  double _currentBalance = 0.0;
  bool _isLoading = false;
  
  String _selectedPaymentMethodTitle = 'E-WALLET';
  String _selectedPaymentMethodSubtitle = 'OVO / GoPay / Dana';
  IconData _selectedPaymentMethodIcon = Icons.account_balance_wallet;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final balance = await _walletService.getBalance();
    if (mounted) setState(() => _currentBalance = balance);
  }

  void _selectAmount(int amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.clear();
    });
  }

  int get _effectiveAmount {
    if (_amountController.text.isNotEmpty) {
      return int.tryParse(_amountController.text) ?? 0;
    }
    return _selectedAmount;
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Future<void> _doTopUp() async {
    final amount = _effectiveAmount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih atau masukkan nominal')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final success = await _walletService.topUp(amount.toDouble());
    setState(() => _isLoading = false);
    if (success && mounted) {
      final newBalance = await _walletService.getBalance();
      Navigator.of(context).pushReplacementNamed('/top-up-success', arguments: {
        'amount': amount.toDouble(),
        'new_balance': newBalance,
        'method': _selectedPaymentMethodTitle,
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Top up gagal, coba lagi')),
      );
    }
  }

  void _showPaymentMethodBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.onBackground, width: 4.0),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.onBackground, width: 4.0)),
                ),
                child: Text('PILIH METODE PEMBAYARAN', style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900)),
              ),
              _buildPaymentOption(
                title: 'E-WALLET',
                subtitle: 'OVO / GoPay / Dana / LinkAja',
                icon: Icons.account_balance_wallet,
              ),
              _buildPaymentOption(
                title: 'VIRTUAL ACCOUNT',
                subtitle: 'BCA / Mandiri / BNI / BRI',
                icon: Icons.account_balance,
              ),
              _buildPaymentOption(
                title: 'KARTU KREDIT / DEBIT',
                subtitle: 'Visa / Mastercard / JCB',
                icon: Icons.credit_card,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentOption({required String title, required String subtitle, required IconData icon}) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethodTitle = title;
          _selectedPaymentMethodSubtitle = subtitle;
          _selectedPaymentMethodIcon = icon;
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.onBackground, width: 2.0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: AppColors.tertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
            icon: const Icon(Icons.notifications, color: AppColors.tertiary),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.margin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header Title ───────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.onBackground,
                      width: 4.0,
                    ),
                  ),
                ),
                child: Text(
                  'TOP UP BALANCE',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ─── Current Balance Card ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary,
                border: Border.all(color: AppColors.onBackground, width: 4.0),
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
                    'CURRENT BALANCE',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.surfaceContainerHigh,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'RP ',
                        style: AppTypography.headlineMedium.copyWith(
                          color: AppColors.tertiaryFixed,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _formatCurrency(_currentBalance),
                        style: AppTypography.displayMedium.copyWith(
                          color: AppColors.tertiaryFixed,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.onPrimary, width: 2.0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ACCOUNT: USER BOSS',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.onPrimary),
                        ),
                        Text(
                          'ID: #PB-8472',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.onPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ─── Amount Selection ──────────────────────────────────────
            Text(
              'SELECT AMOUNT',
              style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _buildAmountButton(20000, '20K')),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _buildAmountButton(50000, '50K')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _buildAmountButton(100000, '100K')),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _buildAmountButton(200000, '200K')),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // ─── Custom Amount ─────────────────────────────────────────
            Text(
              'CUSTOM AMOUNT',
              style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.onBackground, width: 4.0),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md),
                    child: Text(
                      'RP',
                      style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900),
                      decoration: InputDecoration(
                        hintText: 'ENTER AMOUNT',
                        hintStyle: AppTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.outlineVariant,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            _selectedAmount = 0; // Clear selected predefined amount
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ─── Payment Method ────────────────────────────────────────
            Text(
              'PAYMENT METHOD',
              style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _showPaymentMethodBottomSheet,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.onBackground, width: 4.0),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.onBackground,
                      offset: Offset(4, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        border: Border.all(color: AppColors.onBackground, width: 2.0),
                      ),
                      child: Icon(_selectedPaymentMethodIcon, color: AppColors.onPrimaryContainer),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedPaymentMethodTitle, style: AppTypography.labelLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text(_selectedPaymentMethodSubtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 32),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),

            // ─── CTA Button ────────────────────────────────────────────
            BrutalistButton(
              label: _isLoading ? 'PROCESSING...' : 'TOP UP SEKARANG',
              backgroundColor: AppColors.tertiary,
              foregroundColor: AppColors.onTertiary,
              onPressed: _isLoading ? () {} : _doTopUp,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountButton(int amount, String label) {
    final isSelected = _selectedAmount == amount;
    return GestureDetector(
      onTap: () => _selectAmount(amount),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tertiaryContainer : AppColors.surface,
          border: Border.all(color: AppColors.onBackground, width: 4.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.onBackground,
              offset: isSelected ? const Offset(2, 2) : const Offset(4, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.w900,
              color: isSelected ? AppColors.onTertiaryContainer : AppColors.onBackground,
            ),
          ),
        ),
      ),
    );
  }
}
