import 'package:flutter/material.dart';
import 'package:parkirboss/core/constants/app_colors.dart';
import 'package:parkirboss/core/constants/app_constants.dart';
import 'package:parkirboss/core/constants/app_typography.dart';
import 'package:parkirboss/core/services/notification_service.dart';
import 'package:parkirboss/presentation/common/buttons/brutalist_button.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  // Display order for the date-group headers.
  static const List<String> _groupOrder = ['TODAY', 'YESTERDAY', 'EARLIER'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final items = await _service.getNotifications();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'NOTIFIKASI',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            color: AppColors.tertiary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.tertiary,
          strokeWidth: 4,
        ),
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.margin),
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          const Icon(Icons.notifications_off,
              size: 48, color: AppColors.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'BELUM ADA NOTIFIKASI',
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Aktivitas parkir dan transaksi Anda akan muncul di sini.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    // Bucket items by their date group, preserving newest-first order.
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in _items) {
      final group = (item['group'] ?? 'EARLIER').toString();
      grouped.putIfAbsent(group, () => []).add(item);
    }

    final orderedGroups = [
      ..._groupOrder.where(grouped.containsKey),
      ...grouped.keys.where((g) => !_groupOrder.contains(g)),
    ];

    final children = <Widget>[];
    for (final group in orderedGroups) {
      children.add(_buildGroupHeader(group));
      children.add(const SizedBox(height: AppSpacing.md));
      final groupItems = grouped[group]!;
      for (var i = 0; i < groupItems.length; i++) {
        children.add(_buildNotificationCard(groupItems[i]));
        if (i < groupItems.length - 1) {
          children.add(const SizedBox(height: AppSpacing.md));
        }
      }
      children.add(const SizedBox(height: AppSpacing.xxxl));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.margin),
      children: children,
    );
  }

  Widget _buildGroupHeader(String label) {
    final isToday = label == 'TODAY';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isToday ? AppColors.primaryContainer : AppColors.surfaceContainerHigh,
          border: Border.all(color: AppColors.onBackground, width: 4.0),
          boxShadow: const [
            BoxShadow(color: AppColors.onBackground, offset: Offset(4, 4)),
          ],
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: isToday ? AppColors.onPrimaryContainer : AppColors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final category = (item['category'] ?? 'payment').toString();
    final title = (item['title'] ?? '').toString();
    final body = (item['body'] ?? '').toString();
    final time = _formatTime(item['timestamp']?.toString());

    final style = _styleFor(category);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: style.cardColor,
        border: Border.all(color: AppColors.onBackground, width: 4.0),
        boxShadow: const [
          BoxShadow(color: AppColors.onBackground, offset: Offset(6, 6)),
        ],
      ),
      child: Stack(
        children: [
          if (style.badge != null)
            Positioned(
              top: -AppSpacing.md,
              right: -AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                decoration: BoxDecoration(
                  color: style.badgeColor,
                  border: const Border(
                    left: BorderSide(color: AppColors.onBackground, width: 4.0),
                    bottom: BorderSide(color: AppColors.onBackground, width: 4.0),
                  ),
                ),
                child: Text(
                  style.badge!,
                  style: AppTypography.labelSmall.copyWith(color: style.badgeFg),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: style.iconBg,
                  border: Border.all(color: AppColors.onBackground, width: 3.0),
                ),
                child: Icon(style.icon, color: style.iconFg),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelLarge.copyWith(color: style.textColor),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      body,
                      style: AppTypography.bodySmall.copyWith(color: style.textColor),
                    ),
                    if (category == 'alert') ...[
                      const SizedBox(height: AppSpacing.sm),
                      BrutalistButton(
                        label: 'ISI SALDO',
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.onPrimaryContainer,
                        isFullWidth: false,
                        onPressed: () async {
                          await Navigator.of(context).pushNamed('/top-up');
                          _load();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  time,
                  style: AppTypography.labelSmall.copyWith(color: style.textColor),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  _NotifStyle _styleFor(String category) {
    switch (category) {
      case 'alert':
        return _NotifStyle(
          cardColor: AppColors.secondaryContainer,
          iconBg: AppColors.secondary,
          iconFg: AppColors.onSecondary,
          icon: Icons.warning,
          textColor: AppColors.onSecondaryContainer,
          badge: 'ALERT',
          badgeColor: AppColors.error,
          badgeFg: AppColors.onError,
        );
      case 'session':
        return _NotifStyle(
          cardColor: AppColors.tertiaryContainer,
          iconBg: AppColors.tertiary,
          iconFg: AppColors.onTertiary,
          icon: Icons.directions_car,
          textColor: AppColors.onTertiaryContainer,
          badge: 'ACTIVE',
          badgeColor: AppColors.primaryContainer,
          badgeFg: AppColors.onPrimaryContainer,
        );
      case 'topup':
        return _NotifStyle(
          cardColor: AppColors.surface,
          iconBg: AppColors.primaryContainer,
          iconFg: AppColors.onPrimaryContainer,
          icon: Icons.account_balance_wallet,
          textColor: AppColors.onSurface,
        );
      case 'payment':
      default:
        return _NotifStyle(
          cardColor: AppColors.surface,
          iconBg: AppColors.primaryContainer,
          iconFg: AppColors.onPrimaryContainer,
          icon: Icons.receipt_long,
          textColor: AppColors.onSurface,
        );
    }
  }
}

class _NotifStyle {
  final Color cardColor;
  final Color iconBg;
  final Color iconFg;
  final IconData icon;
  final Color textColor;
  final String? badge;
  final Color badgeColor;
  final Color badgeFg;

  _NotifStyle({
    required this.cardColor,
    required this.iconBg,
    required this.iconFg,
    required this.icon,
    required this.textColor,
    this.badge,
    this.badgeColor = AppColors.primaryContainer,
    this.badgeFg = AppColors.onPrimaryContainer,
  });
}
