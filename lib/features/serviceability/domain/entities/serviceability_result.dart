import 'package:equatable/equatable.dart';

/// Explicit domain outcome for a pincode serviceability check.
enum ServiceabilityOutcome {
  serviceable,
  notServiceable,
  invalidPincode,
  unavailable,
}

class ServiceabilityResult extends Equatable {
  const ServiceabilityResult({
    required this.outcome,
    this.pincode,
  });

  const ServiceabilityResult.serviceable(String pincode)
      : this(outcome: ServiceabilityOutcome.serviceable, pincode: pincode);

  const ServiceabilityResult.notServiceable(String pincode)
      : this(outcome: ServiceabilityOutcome.notServiceable, pincode: pincode);

  const ServiceabilityResult.invalidPincode([String? pincode])
      : this(outcome: ServiceabilityOutcome.invalidPincode, pincode: pincode);

  const ServiceabilityResult.unavailable([String? pincode])
      : this(outcome: ServiceabilityOutcome.unavailable, pincode: pincode);

  final ServiceabilityOutcome outcome;
  final String? pincode;

  bool get isServiceable => outcome == ServiceabilityOutcome.serviceable;

  @override
  List<Object?> get props => [outcome, pincode];
}
