import 'package:latlong2/latlong.dart';
import 'package:rotasaude/models/health_unit.dart';

/// Converte o JSON de `/api/v1/units/` no modelo do app.
///
/// Campos obrigatórios ausentes ou inválidos lançam [FormatException]: uma
/// violação do contrato não pode virar uma unidade com dados inventados. Campos
/// opcionais ou operacionais ausentes viram `null`.
HealthUnit parseHealthUnit(Object? json) {
  final map = _asMap(json, 'unidade');
  final status = switch (map['operational_status']) {
    final Map<String, dynamic> value => value,
    _ => null,
  };

  final updatedAt =
      _timestamp(map['last_operational_update_at']) ??
      _timestamp(status?['source_updated_at']);

  return HealthUnit(
    id: _requiredString(map, 'id'),
    name: _requiredString(map, 'name'),
    address: _requiredString(map, 'address'),
    position: LatLng(
      _requiredCoordinate(map, 'latitude', 90),
      _requiredCoordinate(map, 'longitude', 180),
    ),
    services: [
      if (map['services'] case final List<dynamic> services)
        for (final service in services)
          if (service is String && service.trim().isNotEmpty) service.trim(),
    ],
    openingHours: _optionalString(map['opening_hours']),
    phone: _optionalString(map['phone']),
    isDemo: map['is_demo'] == true || status?['is_demo'] == true,
    operationalData: status == null
        ? null
        : UnitOperationalData(
            availability: _availability(status['availability_level']),
            waitMinutes: _nonNegativeInt(status['estimated_wait_minutes']),
            peopleWaiting: _nonNegativeInt(status['people_waiting']),
            updatedAt: updatedAt,
          ),
  );
}

/// Nomes dos serviços de `/api/v1/services/`.
String parseServiceName(Object? json) =>
    _requiredString(_asMap(json, 'serviço'), 'name');

Map<String, dynamic> _asMap(Object? value, String what) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('Esperava um objeto JSON para $what.');
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('Campo obrigatório "$key" ausente ou inválido.');
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double _requiredCoordinate(Map<String, dynamic> map, String key, double limit) {
  final value = switch (map[key]) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };
  if (value == null || !value.isFinite || value.abs() > limit) {
    throw FormatException('Campo obrigatório "$key" ausente ou inválido.');
  }
  return value;
}

int? _nonNegativeInt(Object? value) {
  if (value is! num || !value.isFinite || value < 0) return null;
  return value == value.truncate() ? value.toInt() : null;
}

AvailabilityLevel? _availability(Object? value) => switch (value) {
  'HIGH' => AvailabilityLevel.high,
  'MODERATE' => AvailabilityLevel.moderate,
  'LOW' => AvailabilityLevel.low,
  'CRITICAL' => AvailabilityLevel.critical,
  _ => null,
};

DateTime? _timestamp(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
