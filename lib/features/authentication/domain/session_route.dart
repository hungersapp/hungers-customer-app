/// Startup route from the existing Firebase session + customer profile.
enum SessionRoute {
  login,
  dashboard,
  zoneRegistration,
}

SessionRoute resolveSessionRoute({
  required bool isAuthenticated,
  required bool hasCustomerProfile,
}) {
  if (!isAuthenticated) {
    return SessionRoute.login;
  }
  if (hasCustomerProfile) {
    return SessionRoute.dashboard;
  }
  return SessionRoute.zoneRegistration;
}
