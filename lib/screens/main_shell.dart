import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'tools_screen.dart';

/// App shell hosting the three primary tabs with a custom pill bottom nav.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    _TabDef('Library', Icons.description_outlined, Icons.description_rounded),
    _TabDef('Tools', Icons.build_outlined, Icons.build_rounded),
    _TabDef('Settings', Icons.settings_outlined, Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          ToolsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildNav(context),
    );
  }

  Widget _buildNav(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _tabs.length; i++)
                _navItem(scheme, i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(ColorScheme scheme, int i) {
    final tab = _tabs[i];
    final selected = _index == i;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _index = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
            horizontal: selected ? 20 : 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              selected ? tab.activeIcon : tab.icon,
              color: selected ? Colors.white : muted,
              size: 24,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        tab.label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabDef(this.label, this.icon, this.activeIcon);
}
