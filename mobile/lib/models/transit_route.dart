import 'package:latlong2/latlong.dart';

/// Ponto de embarque ou desembarque de uma rota de ônibus.
class TransitStop {
  const TransitStop({required this.name, required this.position});

  final String name;
  final LatLng position;
}

/// Resposta normalizada de `GET /api/v1/routes/?mode=bus`.
///
/// Hoje o backend só entrega rotas **simuladas** (demonstração acadêmica):
/// linha, pontos e horários são fictícios e o traçado é esquemático. Por isso
/// o parser exige `is_simulated: true`; uma rota de ônibus sem essa marca não
/// é apresentada.
class TransitRoute {
  const TransitRoute({
    required this.provider,
    required this.unitId,
    required this.routeId,
    required this.lineCode,
    required this.lineName,
    required this.boardingStop,
    required this.alightingStop,
    required this.walkToStopMeters,
    required this.walkToStopSeconds,
    required this.waitSeconds,
    required this.inVehicleSeconds,
    required this.walkFromStopMeters,
    required this.walkFromStopSeconds,
    required this.departureAt,
    required this.busDepartureAt,
    required this.busArrivalAt,
    required this.arrivalAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    this.notice,
  });

  final String provider;
  final String unitId;
  final String routeId;
  final String lineCode;
  final String lineName;
  final TransitStop boardingStop;
  final TransitStop alightingStop;
  final double walkToStopMeters;
  final double walkToStopSeconds;
  final double waitSeconds;
  final double inVehicleSeconds;
  final double walkFromStopMeters;
  final double walkFromStopSeconds;

  /// Saída da origem, saída e chegada do ônibus e chegada à unidade. Todos
  /// são horários fictícios, não oficiais.
  final DateTime departureAt;
  final DateTime busDepartureAt;
  final DateTime busArrivalAt;
  final DateTime arrivalAt;
  final double distanceMeters;
  final double durationSeconds;

  /// Traçado esquemático (linhas retas entre os pontos), não navegação.
  final List<LatLng> polyline;

  /// Aviso de simulação enviado pelo backend.
  final String? notice;

  double get distanceKm => distanceMeters / 1000;

  int get durationMinutes => (durationSeconds / 60).round().clamp(1, 999999);

  int get waitMinutes => (waitSeconds / 60).round();
}
