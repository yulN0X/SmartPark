import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/core/services/auth_service.dart';
import 'package:parkirboss/core/services/user_service.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  String _userName = 'Loading...';
  String _userEmail = '';
  Map<String, dynamic>? _profileData;
  bool _pushNotifications = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _userService.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _profileData = profile;
        _userName = (profile['name'] ?? 'USER').toString().toUpperCase();
        _userEmail = profile['email'] ?? '';
      });
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  // ─── Modal: Data Pribadi ───────────────────────────────────────────────────
  void _showPersonalData() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.onSurface, width: 4.0),
      ),
      builder: (context) {
        final phone = _profileData?['phone'] ?? '-';
        final balance = _profileData?['balance'] ?? 0.0;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      border: Border(
                        bottom: BorderSide(color: AppColors.onSurface, width: 4.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 32, color: AppColors.onPrimaryContainer),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'DATA PRIBADI',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildInfoRow('NAMA LENGKAP', _userName),
                  const SizedBox(height: AppSpacing.md),
                  _buildInfoRow('ALAMAT EMAIL', _userEmail),
                  const SizedBox(height: AppSpacing.md),
                  _buildInfoRow('NOMOR TELEPON', phone),
                  const SizedBox(height: AppSpacing.md),
                  _buildInfoRow('SALDO WALLET', 'Rp ${_formatCurrency(balance.toDouble())}'),
                  const SizedBox(height: AppSpacing.xl),
                  BrutalistButton(
                    label: 'TUTUP',
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.onSurface,
                    borderColor: AppColors.onSurface,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border.all(color: AppColors.onSurface, width: 3.0),
        boxShadow: const [
          BoxShadow(color: AppColors.onSurface, offset: Offset(3, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Modal: Metode Pembayaran ──────────────────────────────────────────────
  void _showPaymentMethods() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.onSurface, width: 4.0),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.secondaryContainer,
                      border: Border(
                        bottom: BorderSide(color: AppColors.onSurface, width: 4.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined, size: 32, color: AppColors.onSecondaryContainer),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'METODE PEMBAYARAN',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildPaymentMethodItem('E-WALLET (OVO/DANA/GOPAY)', 'Terhubung', Icons.account_balance_wallet_outlined, true),
                  const SizedBox(height: AppSpacing.md),
                  _buildPaymentMethodItem('VIRTUAL ACCOUNT (BCA/MANDIRI)', 'Siap Digunakan', Icons.account_balance_outlined, true),
                  const SizedBox(height: AppSpacing.md),
                  _buildPaymentMethodItem('KARTU KREDIT / DEBIT', 'Belum Terhubung', Icons.credit_card_outlined, false),
                  const SizedBox(height: AppSpacing.xl),
                  BrutalistButton(
                    label: 'TUTUP',
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.onSurface,
                    borderColor: AppColors.onSurface,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodItem(String title, String status, IconData icon, bool connected) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: connected ? AppColors.surfaceContainerLowest : AppColors.surfaceVariant,
        border: Border.all(color: AppColors.onSurface, width: 3.0),
        boxShadow: const [
          BoxShadow(color: AppColors.onSurface, offset: Offset(3, 3)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: connected ? AppColors.primary : AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  status,
                  style: AppTypography.bodySmall.copyWith(
                    color: connected ? AppColors.primary : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (!connected)
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Menghubungkan metode pembayaran baru...')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  border: Border.all(color: AppColors.onSurface, width: 2.0),
                ),
                child: Text(
                  'HUBUNGKAN',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Modal: PIN Transaksi ──────────────────────────────────────────────────
  void _showTransactionPin() {
    String pin = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.onSurface, width: 4.0),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: const BoxDecoration(
                        color: AppColors.errorContainer,
                        border: Border(
                          bottom: BorderSide(color: AppColors.onSurface, width: 4.0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pin_outlined, size: 32, color: AppColors.onErrorContainer),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'PIN TRANSAKSI',
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Masukkan 6 digit PIN Transaksi Anda untuk keamanan pembayaran.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // PIN Dots Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final filled = index < pin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: filled ? AppColors.onSurface : AppColors.surfaceContainerLowest,
                            border: Border.all(color: AppColors.onSurface, width: 3.0),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // Keypad
                    _buildPinKeypad(
                      onNumberPressed: (digit) {
                        if (pin.length < 6) {
                          setModalState(() {
                            pin += digit;
                          });
                          if (pin.length == 6) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PIN Transaksi berhasil diperbarui!'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        }
                      },
                      onBackPressed: () {
                        if (pin.isNotEmpty) {
                          setModalState(() {
                            pin = pin.substring(0, pin.length - 1);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    BrutalistButton(
                      label: 'BATAL',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.onSurface,
                      borderColor: AppColors.onSurface,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPinKeypad({
    required ValueChanged<String> onNumberPressed,
    required VoidCallback onBackPressed,
  }) {
    final List<String> keys = [
      '1', '2', '3',
      '4', '5', '6',
      '7', '8', '9',
      'C', '0', '⌫'
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.6,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final isAction = key == 'C' || key == '⌫';
        return GestureDetector(
          onTap: () {
            if (key == '⌫') {
              onBackPressed();
            } else if (key == 'C') {
              // Clear PIN
              for (int i = 0; i < 6; i++) {
                onBackPressed();
              }
            } else {
              onNumberPressed(key);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isAction ? AppColors.surfaceVariant : AppColors.surfaceContainerLowest,
              border: Border.all(color: AppColors.onSurface, width: 3.0),
              boxShadow: const [
                BoxShadow(color: AppColors.onSurface, offset: Offset(2, 2)),
              ],
            ),
            child: Center(
              child: Text(
                key,
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isAction ? AppColors.error : AppColors.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Modal: Pusat Bantuan ──────────────────────────────────────────────────
  void _showHelpCenter() {
    final List<Map<String, dynamic>> faqs = [
      {
        'question': 'Bagaimana cara membayar parkir?',
        'answer': 'Cukup scan kode QR tiket parkir Anda atau masukkan nomor plat kendaraan pada layar utama, kemudian selesaikan pembayaran menggunakan saldo dompet digital Parkir Boss.',
        'expanded': false,
      },
      {
        'question': 'Bagaimana cara melakukan top up saldo?',
        'answer': 'Buka menu Dompet/Top Up di dashboard, pilih atau masukkan jumlah nominal yang Anda inginkan, pilih metode pembayaran (E-wallet/Virtual Account), lalu lakukan transfer.',
        'expanded': false,
      },
      {
        'question': 'Kendaraan tidak terdeteksi saat keluar?',
        'answer': 'Jika kamera gerbang tidak mengenali plat kendaraan Anda, Anda dapat melakukan pembayaran manual menggunakan menu "Billing Keluar" atau menekan tombol bantuan di gerbang parkir fisik.',
        'expanded': false,
      },
      {
        'question': 'Hubungi Layanan Pelanggan (CS)?',
        'answer': 'Anda dapat menghubungi tim customer support kami via WhatsApp di nomor +62 821-2345-6789 atau melalui email ke support@parkirboss.com.',
        'expanded': false,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.onSurface, width: 4.0),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryContainer,
                            border: Border(
                              bottom: BorderSide(color: AppColors.onSurface, width: 4.0),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.help_outline, size: 32, color: AppColors.onSecondaryContainer),
                              const SizedBox(width: AppSpacing.md),
                              Text(
                                'PUSAT BANTUAN FAQ',
                                style: AppTypography.headlineSmall.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: faqs.length,
                            itemBuilder: (context, index) {
                              final faq = faqs[index];
                              final isExpanded = faq['expanded'] as bool;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLowest,
                                    border: Border.all(color: AppColors.onSurface, width: 3.0),
                                    boxShadow: const [
                                      BoxShadow(color: AppColors.onSurface, offset: Offset(3, 3)),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setModalState(() {
                                            faq['expanded'] = !isExpanded;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(AppSpacing.md),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  faq['question'],
                                                  style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isExpanded)
                                        Container(
                                          padding: const EdgeInsets.all(AppSpacing.md).copyWith(top: 0),
                                          child: Text(
                                            faq['answer'],
                                            style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        BrutalistButton(
                          label: 'TUTUP',
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.onSurface,
                          borderColor: AppColors.onSurface,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Modal: Tentang Aplikasi ───────────────────────────────────────────────
  void _showAboutApp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.onSurface, width: 4.0),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: const BoxDecoration(
                      color: AppColors.tertiaryContainer,
                      border: Border(
                        bottom: BorderSide(color: AppColors.onSurface, width: 4.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 32, color: AppColors.onTertiaryContainer),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'TENTANG APLIKASI',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      border: Border.all(color: AppColors.onSurface, width: 3.0),
                      boxShadow: const [
                        BoxShadow(color: AppColors.onSurface, offset: Offset(3, 3)),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.local_parking, size: 64, color: AppColors.primary),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'PARKIR BOSS',
                          style: AppTypography.headlineMedium.copyWith(
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Versi 1.0.4-build.18',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Aplikasi manajemen parkir pintar berbasis platform Flutter dengan visual Tech-Brutalist yang mutakhir dan premium.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(color: AppColors.onSurface, thickness: 2.0),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Dikembangkan oleh Proyek Sains Data.',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  BrutalistButton(
                    label: 'TUTUP',
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.onSurface,
                    borderColor: AppColors.onSurface,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Profile Header ──────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
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
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          size: 64,
                          color: AppColors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -8,
                      right: -8,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.tertiaryContainer,
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
                        child: const Icon(
                          Icons.photo_camera,
                          color: AppColors.onTertiaryContainer,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  _userName,
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  _userEmail,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ─── Stats Row ─────────────────────────────────────────────
          Container(
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
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem('24', 'Total Parkir'),
                  ),
                  const VerticalDivider(
                    color: AppColors.onSurface,
                    thickness: AppSpacing.borderMedium,
                    width: AppSpacing.borderMedium,
                  ),
                  Expanded(
                    child: Container(
                      color: AppColors.primaryContainer,
                      child: _buildStatItem('186k', 'Pengeluaran', fgColor: AppColors.onPrimaryContainer),
                    ),
                  ),
                  const VerticalDivider(
                    color: AppColors.onSurface,
                    thickness: AppSpacing.borderMedium,
                    width: AppSpacing.borderMedium,
                  ),
                  Expanded(
                    child: _buildStatItem('1j 45m', 'Rata-rata'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ─── Menu Sections ─────────────────────────────────────────
          _buildMenuSection(
            'KENDARAAN',
            [
              _buildMenuItem(
                Icons.directions_car,
                'Kendaraan Saya',
                color: AppColors.primary,
                onTap: () {
                  Navigator.of(context).pushNamed('/vehicle-management');
                },
              ),
              _buildMenuItem(
                Icons.add_circle_outline,
                'Tambah Kendaraan',
                color: AppColors.primary,
                onTap: () {
                  Navigator.of(context).pushNamed('/add-vehicle-step1');
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          _buildMenuSection(
            'AKUN',
            [
              _buildMenuItem(
                Icons.person_outline,
                'Data Pribadi',
                color: AppColors.primary,
                onTap: _showPersonalData,
              ),
              _buildMenuItem(
                Icons.payments_outlined,
                'Metode Pembayaran',
                color: AppColors.primary,
                onTap: _showPaymentMethods,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          _buildMenuSection(
            'PREFERENSI',
            [
              _buildMenuToggleItem(
                Icons.notifications_active_outlined,
                'Notifikasi Push',
                color: AppColors.tertiary,
                value: _pushNotifications,
                onChanged: (val) {
                  setState(() => _pushNotifications = val);
                },
              ),
              _buildMenuToggleItem(
                Icons.dark_mode_outlined,
                'Mode Gelap',
                color: AppColors.tertiary,
                value: _darkMode,
                onChanged: (val) {
                  setState(() => _darkMode = val);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          _buildMenuSection(
            'KEAMANAN',
            [
              _buildMenuItem(
                Icons.lock_reset_outlined,
                'Ubah Kata Sandi',
                color: AppColors.error,
                onTap: () {
                  Navigator.of(context).pushNamed('/change-password');
                },
              ),
              _buildMenuItem(
                Icons.pin_outlined,
                'PIN Transaksi',
                color: AppColors.error,
                onTap: _showTransactionPin,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          _buildMenuSection(
            'LAINNYA',
            [
              _buildMenuItem(
                Icons.help_outline,
                'Pusat Bantuan',
                color: AppColors.secondary,
                onTap: _showHelpCenter,
              ),
              _buildMenuItem(
                Icons.info_outline,
                'Tentang Aplikasi',
                color: AppColors.secondary,
                onTap: _showAboutApp,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ─── Logout Button ─────────────────────────────────────────
          BrutalistButton(
            label: 'KELUAR DARI AKUN',
            leadingIcon: Icons.logout,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.error,
            borderColor: AppColors.error,
            onPressed: () async {
              await _authService.logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, {Color fgColor = AppColors.onSurface}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTypography.headlineMedium.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: fgColor.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.xs),
          child: Container(
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
              title,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ),
        ),
        Container(
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
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  const Divider(
                    height: AppSpacing.borderMedium,
                    thickness: AppSpacing.borderMedium,
                    color: AppColors.onSurface,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {required Color color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.onSurface),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuToggleItem(
    IconData icon,
    String title, {
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            Container(
              width: 48,
              height: 24,
              decoration: BoxDecoration(
                color: value ? AppColors.primaryContainer : AppColors.surfaceVariant,
                border: Border.all(
                  color: AppColors.onSurface,
                  width: AppSpacing.borderMedium,
                ),
              ),
              child: Align(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.onSurface,
                    border: Border.all(
                      color: AppColors.onSurface,
                      width: AppSpacing.borderMedium,
                    ),
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
