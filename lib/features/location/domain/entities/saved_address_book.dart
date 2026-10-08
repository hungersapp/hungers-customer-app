import '../entities/user_location.dart';

enum SavedAddressSlot { home, work, other }

extension SavedAddressSlotX on SavedAddressSlot {
  String get firestoreKey {
    switch (this) {
      case SavedAddressSlot.home:
        return 'home';
      case SavedAddressSlot.work:
        return 'work';
      case SavedAddressSlot.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case SavedAddressSlot.home:
        return 'Home';
      case SavedAddressSlot.work:
        return 'Work';
      case SavedAddressSlot.other:
        return 'Other';
    }
  }
}

class SavedAddressBook {
  const SavedAddressBook({this.home, this.work, this.other});

  final UserLocation? home;
  final UserLocation? work;
  final UserLocation? other;

  UserLocation? operator [](SavedAddressSlot slot) {
    switch (slot) {
      case SavedAddressSlot.home:
        return home;
      case SavedAddressSlot.work:
        return work;
      case SavedAddressSlot.other:
        return other;
    }
  }

  /// The saved slot whose coordinates match [location], if any.
  SavedAddressSlot? matchingSlot(UserLocation location) {
    for (final slot in SavedAddressSlot.values) {
      final saved = this[slot];
      if (saved != null &&
          saved.latitude == location.latitude &&
          saved.longitude == location.longitude) {
        return slot;
      }
    }
    return null;
  }

  SavedAddressBook copyWith({
    UserLocation? home,
    UserLocation? work,
    UserLocation? other,
    bool clearHome = false,
    bool clearWork = false,
    bool clearOther = false,
  }) {
    return SavedAddressBook(
      home: clearHome ? null : (home ?? this.home),
      work: clearWork ? null : (work ?? this.work),
      other: clearOther ? null : (other ?? this.other),
    );
  }
}
