import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_routes.dart';
import '../../../location/presentation/helpers/post_login_location_flow.dart';
import '../../domain/entities/auth_user.dart';
import '../../providers/auth_provider.dart';

/// Existing customer → restore session. New customer → zone gate first.
Future<void> continueAfterPhoneAuth({
  required BuildContext context,
  required WidgetRef ref,
  required AuthUser user,
}) async {
  final profile = await ref.read(authProvider.notifier).loadCustomerProfile(
        user.uid,
      );
  if (!context.mounted) {
    return;
  }

  if (profile != null) {
    await handlePostLoginNavigation(
      context: context,
      ref: ref,
      userId: user.uid,
    );
    return;
  }

  Navigator.pushReplacementNamed(context, AppRoutes.zoneRegistration);
}
