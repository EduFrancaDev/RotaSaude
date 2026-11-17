import 'package:shared_preferences/shared_preferences.dart';

/// Lembra se a pessoa já aceitou a localização na primeira entrada.
abstract class LocationOnboardingStore {
  Future<bool> hasAccepted();
  Future<void> markAccepted();
}

class SharedLocationOnboardingStore implements LocationOnboardingStore {
  const SharedLocationOnboardingStore();

  static const _key = 'location_onboarding_accepted';

  @override
  Future<bool> hasAccepted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key) ?? false;
  }

  @override
  Future<void> markAccepted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_key, true);
  }
}

class MemoryLocationOnboardingStore implements LocationOnboardingStore {
  MemoryLocationOnboardingStore({this.accepted = false});

  bool accepted;

  @override
  Future<bool> hasAccepted() async => accepted;

  @override
  Future<void> markAccepted() async {
    accepted = true;
  }
}
