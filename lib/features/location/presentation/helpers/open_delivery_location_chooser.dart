import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../screens/delivery_address_editor_screen.dart';

/// Opens the location selector from Home: the customer uses their current
/// location, searches ANY place (adjusting the pin on the map), or picks a
/// saved Home / Work / Other address.
///
/// It is the existing address editor without the door / street step (those are
/// collected at checkout). Confirming makes the place the customer's active
/// location; restaurant discovery and its serviceability check follow the
/// active location, so nothing needs to be refreshed here. Cancelling
/// changes nothing. Does nothing when nobody is signed in.
Future<void> openDeliveryLocationChooser(
  BuildContext context,
  WidgetRef ref,
) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) {
    return;
  }
  final current = ref.read(userLocationProvider(userId)).valueOrNull;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => DeliveryAddressEditorScreen(
        initial: current,
        requireAddressDetails: false,
      ),
    ),
  );
}
