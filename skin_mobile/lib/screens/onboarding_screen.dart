import 'package:flutter/material.dart';

import '../l10n/locale_context.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.document_scanner_rounded,
                  color: c.onPrimary,
                  size: 46,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'DermaScanAI',
                style: AppTheme.display(c, size: 34),
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('onboarding.tagline'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: c.textMuted,
                ),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  child: Text(context.tr('onboarding.getStarted')),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('onboarding.disclaimer'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: c.textLight),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
