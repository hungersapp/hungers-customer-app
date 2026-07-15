class PasswordValidator {
  PasswordValidator._();

  /// Returns null if password is valid.
  /// Otherwise returns an error message.
  static String? validate(String password) {
    if (password.isEmpty) {
      return 'Please enter password';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number';
    }

    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=/\\[\];`~]').hasMatch(password)) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  /// Returns true if password is valid.
  static bool isValid(String password) {
    return validate(password) == null;
  }
}