import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/repositories/health_unit_parser.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';

/// JSON no formato real de `/api/v1/units/` (serializer `HealthUnitSerializer`).
Map<String, dynamic> unitJson({
  required String id,
  required String name,
  String address = 'Rua Exemplo, 1 · Goiânia',
  double latitude = -16.6862,
  double longitude = -49.264,
  List<String> services = const ['Clínica geral'],
  String? openingHours = '24 horas',
  bool isDemo = true,
  Map<String, dynamic>? operationalStatus,
  Object? lastOperationalUpdateAt,
}) => {
  'id': id,
  'name': name,
  'address': address,
  'city': 'Goiânia',
  'state': 'GO',
  'latitude': latitude,
  'longitude': longitude,
  'phone': null,
  'opening_hours': openingHours,
  'is_demo': isDemo,
  'services': services,
  'operational_status': operationalStatus,
  'last_operational_update_at':
      lastOperationalUpdateAt ?? operationalStatus?['source_updated_at'],
};

/// Leitura operacional no formato da API, atualizada há [age].
Map<String, dynamic> statusJson({
  Object? level = 'HIGH',
  Object? wait = 20,
  Object? people = 18,
  Duration age = const Duration(minutes: 5),
  bool isDemo = true,
}) {
  final instant = DateTime.now().subtract(age).toUtc().toIso8601String();
  return {
    'people_waiting': people,
    'estimated_wait_minutes': wait,
    'availability_level': level,
    'source_updated_at': instant,
    'received_at': instant,
    'is_demo': isDemo,
  };
}

/// Quatro unidades no formato da API, em ordem alfabética (como o backend).
/// Oeste vem sem leitura operacional.
List<Map<String, dynamic>> goianiaUnitsJson() => [
  unitJson(
    id: 'upa-centro',
    name: 'UPA Exemplo Centro',
    services: ['Clínica geral', 'Ortopedia', 'Pediatria'],
    operationalStatus: statusJson(),
  ),
  unitJson(
    id: 'upa-norte',
    name: 'UPA Exemplo Norte',
    latitude: -16.655,
    services: ['Clínica geral'],
    operationalStatus: statusJson(level: 'LOW', wait: 65, people: 54),
  ),
  unitJson(
    id: 'upa-oeste',
    name: 'UPA Exemplo Oeste',
    longitude: -49.295,
    services: ['Clínica geral', 'Pediatria'],
  ),
  unitJson(
    id: 'upa-sul',
    name: 'UPA Exemplo Sul',
    latitude: -16.71,
    services: ['Clínica geral', 'Ortopedia'],
    operationalStatus: statusJson(level: 'MODERATE', wait: 40, people: 32),
  ),
];

List<HealthUnit> goianiaUnits() => [
  for (final json in goianiaUnitsJson()) parseHealthUnit(json),
];

/// Repositório em memória para os testes de tela.
class FakeHealthUnitRepository implements HealthUnitRepository {
  FakeHealthUnitRepository({this.unitsByCity = const {}, this.failure});

  /// Resposta por cidade; cidades ausentes devolvem lista vazia.
  Map<String, List<HealthUnit>> unitsByCity;

  /// Quando definido, [fetchUnits] falha com ele.
  HealthApiException? failure;

  final requestedCities = <String?>[];

  @override
  Future<List<HealthUnit>> fetchUnits({String? city}) async {
    requestedCities.add(city);
    if (failure case final error?) throw error;
    return unitsByCity[city] ?? const [];
  }

  @override
  Future<HealthUnit> fetchUnit(String id) => throw UnimplementedError();

  @override
  Future<List<String>> fetchServices() => throw UnimplementedError();

  @override
  void close() {}
}
