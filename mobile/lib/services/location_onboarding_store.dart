import 'package:rotasaude/models/health_unit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lembra se a pessoa já aceitou a localização na primeira entrada.
abstract class LocationOnboardingStore {
  Future<bool> hasAccepted();
  Future<void> markAccepted();
  Future<SearchArea?> loadArea();
  Future<void> saveArea(SearchArea area);
}

class SharedLocationOnboardingStore implements LocationOnboardingStore {
  const SharedLocationOnboardingStore();

  static const _key = 'location_onboarding_accepted';
  static const _areaKey = 'discovery_search_area';

  @override
  Future<SearchArea?> loadArea() async {
    final preferences = await SharedPreferences.getInstance();
    final id = preferences.getString(_areaKey);
    return SearchArea.suggestions.where((area) => area.id == id).firstOrNull;
  }

  @override
  Future<void> saveArea(SearchArea area) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_areaKey, area.id);
  }

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
  SearchArea? _area;

  @override
  Future<SearchArea?> loadArea() async => _area;

  @override
  Future<void> saveArea(SearchArea area) async => _area = area;

  @override
  Future<bool> hasAccepted() async => accepted;

  @override
  Future<void> markAccepted() async {
    accepted = true;
  }
}
