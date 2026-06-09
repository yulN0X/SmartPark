import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';
import 'package:parkirboss/presentation/common/cards/brutalist_image_card.dart';

/// Onboarding screen translated 1:1 from the Stitch design.
/// Features a PageView carousel with neo-brutalist styling.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA-cMWrsLlfJwv-OIejWJ_QQPCdOYrCl-dixpFPRemWrSVnRUBvQgMyNN0GgVpK9FbiMqJ_mZuZMjqRMLDfe_5ofn02Xhd8TPlrLSmvy0Im3yNy-yFTBHWHopu5MJVBbkYwI0uJC2Whj9X0QAC2sGTPayygVkZLEbGb0bfFmi90ivYrbSlisOo4ewih3koN1GS1VqxmKm1pgd_uAAN5IdZ-_vN76d4B3GZvaRFpf2mFVE5-bZfMrrwpr6z7PjdmPesnKTkTWgaXUEfv',
      badgeIcon: Icons.qr_code_scanner,
      title: 'KAMERA AI\nBACA PLAT\nOTOMATIS',
      description:
          'Parkir instan tanpa tiket fisik. Sistem kami mengenali kendaraan Anda dalam sekejap.',
      isNetworkImage: true,
    ),
    _OnboardingSlide(
      image: AppAssets.onboardingCamera,
      badgeIcon: Icons.local_parking,
      title: 'Cari Slot\nParkir\nMudah',
      description:
          'Lihat ketersediaan slot parkir secara real-time. Temukan tempat parkir kosong dengan cepat tanpa harus berputar-putar.',
    ),
    _OnboardingSlide(
      image: AppAssets.onboardingCamera,
      badgeIcon: Icons.payments,
      title: 'Bayar\nCepat &\nMudah',
      description:
          'Pembayaran otomatis tanpa antri. Cukup scan dan keluar, biaya parkir langsung dihitung dan dikirim ke aplikasi.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to login
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _skip() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                offset: Offset(AppSpacing.shadowLarge, AppSpacing.shadowLarge),
              ),
            ],
          ),
          margin: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            children: [
              // ─── Header ─────────────────────────────────────
              _buildHeader(),

              // ─── Carousel ───────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return _buildSlide(_slides[index]);
                  },
                ),
              ),

              // ─── Footer ────────────────────────────────────
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo text with gold drop-shadow
          Text(
            'PARKIR BOSS',
            style: AppTypography.titleMedium.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryContainer,
              shadows: const [
                Shadow(
                  color: AppColors.onSurface,
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ),

          // Skip button
          GestureDetector(
            onTap: _skip,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
              ),
              child: Text(
                'SKIP',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(_OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          // Illustration card with badge
          BrutalistImageCard(
            imagePath: slide.image,
            isNetworkImage: slide.isNetworkImage,
            altText: slide.title,
            badge: Icon(
              slide.badgeIcon,
              color: AppColors.onTertiary,
              size: 32,
            ),
          ),

          const SizedBox(height: 40),

          // Title — uppercase, black, heavy
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: AppColors.onSurface,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Description with left tertiary accent border
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.tertiary,
                  width: AppSpacing.borderMedium,
                ),
              ),
            ),
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: Text(
              slide.description,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
            ),
          ), // Container
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.onSurface,
            width: AppSpacing.borderMedium,
          ),
        ),
      ),
      child: Column(
        children: [
          // Pagination dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: isActive ? 48 : 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : AppColors.surfaceContainerHighest,
                  border: Border.all(
                    color: AppColors.onSurface,
                    width: AppSpacing.borderThin,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  boxShadow: isActive
                      ? const [
                          BoxShadow(
                            color: AppColors.onSurface,
                            offset: Offset(2, 2),
                          ),
                        ]
                      : [],
                ),
              );
            }),
          ),

          const SizedBox(height: AppSpacing.xl),

          // CTA button
          BrutalistButton(
            label: _currentPage < _slides.length - 1 ? 'LANJUT' : 'MULAI',
            trailingIcon: Icons.arrow_forward,
            onPressed: _nextPage,
          ),
        ],
      ),
    );
  }
}

/// Data model for onboarding slides.
class _OnboardingSlide {
  final String image;
  final IconData badgeIcon;
  final String title;
  final String description;
  final bool isNetworkImage;

  const _OnboardingSlide({
    required this.image,
    required this.badgeIcon,
    required this.title,
    required this.description,
    this.isNetworkImage = false,
  });
}
