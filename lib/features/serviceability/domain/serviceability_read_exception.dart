/// Fail-closed zone-master read. Never treat this as serviceable.
class ServiceabilityReadException implements Exception {
  const ServiceabilityReadException({this.permissionDenied = false});

  final bool permissionDenied;
}
