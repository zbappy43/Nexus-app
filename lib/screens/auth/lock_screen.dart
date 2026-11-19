import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_config.dart';
import '../../constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';

/// Biometric app lock (fingerprint / face, with device PIN fallback).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    // Prompt automatically once the screen is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<AuthProvider>().unlock());
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final bool face = auth.capability.hasFace && !auth.capability.hasFingerprint;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[AppColors.primary, AppColors.primaryDark],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                const Spacer(flex: 2),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const AppLogo(size: 84),
                ),
                const SizedBox(height: 24),
                Text(
                  AppConfig.appName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.unlockReason,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const Spacer(flex: 2),
                IconButton.filled(
                  iconSize: 48,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.all(20),
                  ),
                  onPressed: auth.isAuthenticating ? null : auth.unlock,
                  icon: Icon(face ? Icons.face_rounded : Icons.fingerprint_rounded),
                ),
                const SizedBox(height: 16),
                Text(
                  auth.isAuthenticating ? 'Waiting for authentication…' : 'Tap to ${AppStrings.unlock.toLowerCase()}',
                  style: const TextStyle(color: Colors.white),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
