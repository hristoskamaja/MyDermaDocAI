import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/locale_context.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/page_hero_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final oldController = TextEditingController();
    final newController = TextEditingController();
    String? error;
    bool loading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final c = context.colors;
            return AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(context.tr('profile.changePassword')),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: c.highSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(error!, style: TextStyle(color: c.high, fontSize: 12.5)),
                      ),
                    ],
                    TextFormField(
                      controller: oldController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: context.tr('profile.currentPassword')),
                      validator: (v) => (v == null || v.isEmpty) ? context.tr('profile.required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newController,
                      obscureText: true,
                      decoration: InputDecoration(labelText: context.tr('profile.newPassword')),
                      validator: (v) {
                        if (v == null || v.isEmpty) return context.tr('profile.required');
                        if (v.length < 8) return context.tr('profile.atLeast8');
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.tr('profile.cancel')),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            loading = true;
                            error = null;
                          });
                          final auth = dialogContext.read<AuthProvider>();
                          final ok = await auth.changePassword(
                            oldPassword: oldController.text,
                            newPassword: newController.text,
                          );
                          if (ok) {
                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.tr('profile.pwSuccess'))),
                              );
                            }
                          } else {
                            setState(() {
                              loading = false;
                              error = auth.lastError ?? 'Could not change password.';
                            });
                          }
                        },
                  child: loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: context.colors.onPrimary),
                        )
                      : Text(context.tr('profile.save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: c.background,
      appBar: PageHeroHeader(
        title: context.tr('profile.title'),
        subtitle: context.tr('profile.subtitle'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user?.initials ?? '?',
                      style: AppTheme.display(c, size: 30).copyWith(color: c.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user?.fullName ?? '',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: TextStyle(fontSize: 13, color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _settingsCard(
            c,
            children: [
              _settingsTile(
                c,
                icon: Icons.lock_outline_rounded,
                title: context.tr('profile.changePassword'),
                onTap: () => _showChangePasswordDialog(context),
              ),
              Divider(color: c.border, height: 1),
              _settingsSwitchTile(
                c,
                icon: Icons.dark_mode_outlined,
                title: context.tr('profile.darkTheme'),
                value: themeProvider.isDark,
                onChanged: (v) => themeProvider.setDark(v),
              ),
              Divider(color: c.border, height: 1),
              _settingsLanguageTile(
                c,
                title: context.tr('profile.language'),
                value: localeProvider.lang,
                onChanged: (lang) => localeProvider.setLang(lang),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (r) => false);
                }
              },
              icon: Icon(Icons.logout_rounded, color: c.high),
              label: Text(context.tr('profile.logout'), style: TextStyle(color: c.high)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: c.high.withValues(alpha: 0.4))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(AppColors c, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsTile(
    AppColors c, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: c.primary),
      title: Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded, color: c.textLight),
    );
  }

  Widget _settingsSwitchTile(
    AppColors c, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: c.primary),
      title: Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
      trailing: Switch(value: value, onChanged: onChanged, activeThumbColor: c.primary),
    );
  }

  /// EN/MK pill toggle - the Flutter counterpart of the web app's
  /// PatientLayout language switch (.patient-lang-switch).
  Widget _settingsLanguageTile(
    AppColors c, {
    required String title,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      leading: Icon(Icons.translate_rounded, color: c.primary),
      title: Text(title, style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
      trailing: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _langPillBtn(c, 'EN', value == 'en', () => onChanged('en')),
            _langPillBtn(c, 'MK', value == 'mk', () => onChanged('mk')),
          ],
        ),
      ),
    );
  }

  Widget _langPillBtn(AppColors c, String label, bool active, VoidCallback onTap) {
    return Material(
      color: active ? c.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: active ? c.primary : c.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }
}
