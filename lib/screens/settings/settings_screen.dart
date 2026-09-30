import 'package:flutter/material.dart';
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
  String? _shownMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _purchases.removeListener(_onPurchase);
    _purchases.addListener(_onPurchase);
  }

  @override
  void dispose() {
    _purchases.removeListener(_onPurchase);
    super.dispose();
  }

  void _onPurchase() {
    final msg = _purchases.message;
    if (msg != null && msg != _shownMessage && mounted) {
      _shownMessage = msg;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      _purchases.clearMessage();
    }
    if (mounted) setState(() {});
  }

  Future<void> _openLink(String url, String title, String fallback) async {
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
              Text(title, style: AppText.title),
              const SizedBox(height: 10),
              Flexible(child: SingleChildScrollView(child: Text(fallback, style: AppText.body))),
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
    if (email.isNotEmpty) {
      try {
        if (await launchUrl(Uri(scheme: 'mailto', path: email, query: 'subject=Cut%20%26%20Run%20support'))) return;
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Support contact is available on our Google Play store listing.')),
    );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the store.')));
      }
    }
  }

  static const _privacyText =
      'Cut & Run stores your progress, coins and settings only on this device. We do not run our own servers and do not collect personal information.\n\n'
      'Ads are provided by Google AdMob, which may use device identifiers to show and measure ads according to your consent choices. '
      'Purchases are processed by Google Play.\n\nYou can clear all game data at any time from Android Settings → Apps → Cut & Run → Storage.';

  static const _termsText =
      'Cut & Run is provided for personal entertainment. Virtual coins have no real-world value and cannot be exchanged for money. '
      'The Remove Ads purchase is a one-time, non-consumable purchase that removes interstitial ads; optional rewarded ads remain available by choice.';

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final settings = s.settings;
    final busy = _purchases.state == PurchaseUiState.loading || _purchases.state == PurchaseUiState.pending;
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
            const _Section('PURCHASES'),
            _Tile(
              icon: Icons.block_rounded,
              title: 'Remove Ads',
              subtitle: _purchases.removeAds
                  ? 'Purchased — thank you!'
                  : (_purchases.price != null ? 'One-time purchase · ${_purchases.price}' : 'One-time purchase'),
              trailing: _purchases.removeAds
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                  : busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: _purchases.removeAds || busy ? null : _purchases.buyRemoveAds,
            ),
            _Tile(
              icon: Icons.restore_rounded,
              title: 'Restore Purchases',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: busy ? null : _purchases.restore,
            ),
            const _Section('ABOUT'),
            _Tile(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy Policy',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: () => _openLink(AppConfig.privacyPolicyUrl, 'Privacy Policy', _privacyText),
            ),
            _Tile(
              icon: Icons.description_rounded,
              title: 'Terms of Use',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: () => _openLink(AppConfig.termsUrl, 'Terms of Use', _termsText),
            ),
            _Tile(
              icon: Icons.mail_rounded,
              title: 'Contact Us',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: _contact,
            ),
            _Tile(
              icon: Icons.star_rate_rounded,
              title: 'Rate Us',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: _rate,
            ),
            const SizedBox(height: 24),
            const Text('Cut & Run · v1.0.0', style: AppText.label, textAlign: TextAlign.center),
          ],
        ),
      ),
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
  const _Tile({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
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
