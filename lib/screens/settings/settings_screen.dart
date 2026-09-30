import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_services.dart';
import '../../core/constants/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../services/purchases/purchase_service.dart';
import '../../widgets/common/badges.dart';
import '../../widgets/common/game_button.dart';
import '../../widgets/common/screen_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final PurchaseService _purchases = AppScope.of(context).purchases;
  bool _listening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listening) {
      _listening = true;
      _purchases.addListener(_onPurchase);
    }
  }

  @override
  void dispose() {
    _purchases.removeListener(_onPurchase);
    super.dispose();
  }

  void _onPurchase() {
    if (!mounted) return;
    final msg = _purchases.message;
    if (msg != null) {
      _purchases.clearMessage();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
    setState(() {});
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _privacy() async {
    const url = AppConfig.privacyPolicyUrl;
    if (url.isNotEmpty) {
      try {
        if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Privacy Policy', style: AppText.title),
              const SizedBox(height: 10),
              const Flexible(child: SingleChildScrollView(child: Text(_privacyText, style: AppText.body))),
              const SizedBox(height: 16),
              GameButton(label: 'CLOSE', style: GameButtonStyle.secondary, onTap: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _contact() async {
    const email = AppConfig.supportEmail;
    final uri =
        Uri(scheme: 'mailto', path: email, query: 'subject=${Uri.encodeComponent('Slice & Run: Cut Master support')}');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    // No email app installed: copy the address instead.
    await Clipboard.setData(const ClipboardData(text: email));
    if (mounted) _snack('No email app found. Address copied: $email');
  }

  Future<void> _rate() async {
    const pkg = AppConfig.playStorePackage;
    try {
      if (await launchUrl(Uri.parse('market://details?id=$pkg'), mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    try {
      await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=$pkg'),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _snack('Could not open Google Play.');
    }
  }

  Future<void> _manageSubscription() async {
    final uri = Uri.parse('https://play.google.com/store/account/subscriptions'
        '?sku=${AppConfig.adsFreeMonthlyId}&package=${AppConfig.playStorePackage}');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted) _snack('Open Google Play → Payments & subscriptions to manage your plan.');
  }

  static const _privacyText =
      'Slice & Run: Cut Master stores your progress, coins and settings only on this device. We do not run our own servers '
      'and do not ask for your name, email or any account.\n\n'
      'Ads are provided by Google AdMob, which may collect device identifiers (such as the advertising ID), IP '
      'address and diagnostic information to show and measure ads, according to your consent choices.\n\n'
      'Ads-Free packages are sold and processed by Google Play. We never see your payment details.\n\n'
      'Questions: ${AppConfig.supportEmail}';

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ScreenScaffold(
      title: 'Settings',
      showCoins: false,
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            const _Section('AUDIO'),
            _SwitchTile(
                icon: Icons.music_note_rounded,
                title: 'Music',
                value: settings.music,
                onChanged: (v) => settings.music = v),
            _SwitchTile(
                icon: Icons.volume_up_rounded,
                title: 'Sound effects',
                value: settings.sfx,
                onChanged: (v) => settings.sfx = v),
            const _Section('FEEDBACK'),
            _SwitchTile(
                icon: Icons.vibration_rounded,
                title: 'Vibration',
                value: settings.vibration,
                onChanged: (v) => settings.vibration = v),
            const _Section('REMOVE ADS'),
            _PlanCard(
              plan: AdFreePlan.monthly,
              purchases: _purchases,
              subtitle: 'Auto-renews every month. Cancel anytime in Google Play.',
            ),
            _PlanCard(
              plan: AdFreePlan.lifetime,
              purchases: _purchases,
              subtitle: 'One-time payment. No forced ads, forever.',
            ),
            if (_purchases.monthlyActive && !_purchases.lifetimeOwned)
              _Tile(
                icon: Icons.manage_accounts_rounded,
                title: 'Manage subscription',
                subtitle: 'Cancel or change your plan in Google Play',
                trailing: const Icon(Icons.open_in_new_rounded, color: AppColors.textMuted, size: 20),
                onTap: _manageSubscription,
              ),
            _Tile(
              icon: Icons.restore_rounded,
              title: 'Restore Purchases',
              trailing: _purchases.state == PurchaseUiState.loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: _purchases.busy ? null : _purchases.restore,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
              child: Text(
                'Payments are handled by Google Play. Optional rewarded ads (continue, double coins) stay available by choice.',
                style: AppText.muted.copyWith(fontSize: 12),
              ),
            ),
            const _Section('ABOUT'),
            _Tile(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy Policy',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: _privacy,
            ),
            _Tile(
              icon: Icons.mail_rounded,
              title: 'Contact Us',
              subtitleWidget: Semantics(
                link: true,
                label: 'Email ${AppConfig.supportEmail}',
                child: Text(
                  AppConfig.supportEmail,
                  style: AppText.body.copyWith(
                    fontSize: 13,
                    color: AppColors.accent,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.accent,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: const Icon(Icons.open_in_new_rounded, color: AppColors.textMuted, size: 20),
              onTap: _contact,
            ),
            _Tile(
              icon: Icons.star_rate_rounded,
              title: 'Rate Us',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: _rate,
            ),
            const SizedBox(height: 24),
            const Text('Slice & Run: Cut Master · v1.0.0', style: AppText.label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// One ads-free package with its Google Play price and buy / status button.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.purchases, required this.subtitle});

  final AdFreePlan plan;
  final PurchaseService purchases;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final lifetime = plan == AdFreePlan.lifetime;
    final owned = purchases.owns(plan);
    final coveredByLifetime = !lifetime && purchases.lifetimeOwned;
    final color = lifetime ? AppColors.reward : AppColors.accent;
    Widget action;
    if (owned) {
      action = _Badge(text: lifetime ? 'OWNED' : 'ACTIVE', color: AppColors.success);
    } else if (coveredByLifetime) {
      action = const _Badge(text: 'INCLUDED', color: AppColors.textMuted);
    } else {
      action = GameButton(
        label: 'BUY',
        style: lifetime ? GameButtonStyle.reward : GameButtonStyle.accent,
        height: 40,
        expand: false,
        fontSize: 14,
        onTap: purchases.busy ? null : () => purchases.buy(plan),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: owned ? AppColors.success : color.withOpacity(0.55), width: owned ? 2 : 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
              child: Icon(lifetime ? Icons.all_inclusive_rounded : Icons.calendar_month_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(plan.title,
                            style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (lifetime) ...[
                        const SizedBox(width: 6),
                        const _Badge(text: 'BEST VALUE', color: AppColors.reward, small: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lifetime ? purchases.priceFor(plan) : '${purchases.priceFor(plan)} / month',
                    style: AppText.section.copyWith(color: color, fontSize: 17),
                  ),
                  Text(subtitle, style: AppText.muted.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            action,
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, this.small = false});
  final String text;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 10, vertical: small ? 2 : 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Text(text, style: AppText.label.copyWith(color: color, fontSize: small ? 9 : 11)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(text, style: AppText.label),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, this.subtitleWidget, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.stroke.withOpacity(0.7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                      if (subtitle != null) Text(subtitle!, style: AppText.muted.copyWith(fontSize: 12.5)),
                      if (subtitleWidget != null) subtitleWidget!,
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.icon, required this.title, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      icon: icon,
      title: title,
      subtitle: value ? 'On' : 'Off',
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}
