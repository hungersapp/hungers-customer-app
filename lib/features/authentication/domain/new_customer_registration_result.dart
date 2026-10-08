enum NewCustomerRegistrationStatus {
  created,
  existingCustomer,
  outsideZone,
  noActiveZones,
  locationPermissionDenied,
  locationServicesDisabled,
  gpsUnavailable,
  serviceabilityUnavailable,
}

class NewCustomerRegistrationResult {
  const NewCustomerRegistrationResult({
    required this.status,
    required this.profileCreated,
  });

  final NewCustomerRegistrationStatus status;
  final bool profileCreated;
}
