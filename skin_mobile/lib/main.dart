import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/register_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';

void main() {
  runApp(const DermaScanApp());
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class DermaScanApp extends StatelessWidget {
  const DermaScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()
            ..onForcedLogout = () => _navigatorKey.currentState
                ?.pushNamedAndRemoveUntil('/login', (_) => false),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'DermaScanAI',
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.mode,
            initialRoute: '/',
            routes: {
              '/': (_) => const _AppStart(),
              '/onboarding': (_) => const OnboardingScreen(),
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/home': (_) => const AppShell(),
            },
          );
        },
      ),
    );
  }
}

/// Decides the initial route: checks the stored auth token (and theme
/// preference) before routing to Home or Onboarding.
class _AppStart extends StatefulWidget {
  const _AppStart();

  @override
  State<_AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<_AppStart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final themeProvider = context.read<ThemeProvider>();
    final localeProvider = context.read<LocaleProvider>();
    await Future.wait([auth.bootstrap(), themeProvider.load(), localeProvider.load()]);
    if (!mounted) return;
    final loggedIn = auth.status == AuthStatus.authenticated;
    Navigator.of(context).pushReplacementNamed(loggedIn ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: CircularProgressIndicator(color: c.primary),
      ),
    );
  }
}
