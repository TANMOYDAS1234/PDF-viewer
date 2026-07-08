import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: Listenable.merge([themeController, settingsStore]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text('Settings',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 24),
              _sectionLabel(context, 'APPEARANCE'),
              const SizedBox(height: 10),
              _appearanceCard(context),
              const SizedBox(height: 24),
              _sectionLabel(context, 'AUDIO & ACCESSIBILITY'),
              const SizedBox(height: 10),
              _ttsCard(context),
              const SizedBox(height: 24),
              _sectionLabel(context, 'ABOUT & SUPPORT'),
              const SizedBox(height: 10),
              _aboutCard(context),
              const SizedBox(height: 28),
              Center(
                child: Text('PDF Viewer Pro · v1.0.0',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.8),
      );

  Widget _card(BuildContext context, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );

  // -------------------------------------------------------------- appearance

  Widget _appearanceCard(BuildContext context) {
    return _card(
      context,
      Row(
        children: [
          _themeOption(context, 'Light', Icons.light_mode_rounded,
              ThemeMode.light),
          const SizedBox(width: 12),
          _themeOption(
              context, 'Dark', Icons.dark_mode_rounded, ThemeMode.dark),
          const SizedBox(width: 12),
          _themeOption(context, 'System', Icons.brightness_auto_rounded,
              ThemeMode.system),
        ],
      ),
    );
  }

  Widget _themeOption(
      BuildContext context, String label, IconData icon, ThemeMode mode) {
    final selected = themeController.mode == mode;
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => themeController.setMode(mode),
        child: Column(
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Icon(icon,
                  color: selected ? AppColors.primary : scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : scheme.onSurface,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------- tts

  Widget _ttsCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rate = settingsStore.ttsRate; // 0.25..1.0
    final multiplier = (rate / 0.5); // 0.5x .. 2x
    return _card(
      context,
      Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.record_voice_over_rounded,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Read-aloud speed',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Adjust voice narration pace',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Text('${multiplier.toStringAsFixed(multiplier == multiplier.roundToDouble() ? 0 : 1)}x',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
            ],
          ),
          Slider(
            value: rate,
            min: 0.25,
            max: 1.0,
            divisions: 3,
            onChanged: (v) => settingsStore.setTtsRate(v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Slow',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              Text('Normal',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              Text('Fast',
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- about

  Widget _aboutCard(BuildContext context) {
    return _card(
      context,
      Column(
        children: [
          _aboutRow(context, Icons.shield_outlined, 'Privacy & Security',
              'All processing happens on your device. Nothing is uploaded.'),
          const Divider(height: 24),
          _aboutRow(context, Icons.help_outline_rounded, 'How it works',
              'Open a PDF from anywhere, or tap Open File. Use Tools to merge, split and protect.'),
        ],
      ),
    );
  }

  Widget _aboutRow(BuildContext context, IconData icon, String title,
      String body) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(body,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
