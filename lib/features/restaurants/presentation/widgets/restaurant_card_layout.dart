/// Layout breakpoints for responsive restaurant presentation.
class RestaurantCardLayout {
  RestaurantCardLayout._();

  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 900;

  static const double maxCardWidth = 520;
  static const double cardSpacing = 16;

  static bool isTablet(double width) => width >= tabletBreakpoint;

  static bool isDesktop(double width) => width >= desktopBreakpoint;

  static int gridCrossAxisCount(double width) {
    if (isDesktop(width)) {
      return 3;
    }
    if (isTablet(width)) {
      return 2;
    }
    return 1;
  }
}
