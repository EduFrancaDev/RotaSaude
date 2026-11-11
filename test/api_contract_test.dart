import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/repositories/health_unit_repository.dart';

/// Respostas reais do backend Django (`feat/backend-mvp`), capturadas com
/// `curl` após `seed_demo_units`, em `test/fixtures/api/`. Garantem que o
/// parser lê o contrato publicado e não apenas JSON escrito à mão.
String fixture(String name) =>
    File('test/fixtures/api/$name').readAsStringSync();

http.Response served(String name, {int status = 200}) => http.Response.bytes(
  utf8.encode(fixture(name)),
  status,
  headers: const {'content-type': 'application/json'},
);

void main() {
  late List<Uri> requested;
  late ApiHealthUnitRepository repository;

  setUp(() {
    requested = [];
    repository = ApiHealthUnitRepository(
      baseUri: Uri.parse('http://10.0.2.2:8000'),
      pageSize: 3,
      client: MockClient((request) async {
        requested.add(request.url);
        final query = request.url.queryParameters;
        return switch (request.url.path) {
          '/api/v1/units/' when query['city'] == 'Aparecida de Goiânia' =>
            served('units_empty.json'),
          '/api/v1/units/' when query['page'] == '2' => served(
            'units_page2.json',
          ),
          '/api/v1/units/' => served('units_page1.json'),
          '/api/v1/units/upa-oeste/' => served('unit_without_status.json'),
          '/api/v1/services/' => served('services.json'),
          _ => served('unit_not_found.json', status: 404),
        };
      }),
    );
  });

  test('lê as unidades paginadas do backend real', () async {
    final units = await repository.fetchUnits(city: 'Goiânia');

    expect(units.map((unit) => unit.id), [
      'upa-centro',
      'upa-norte',
      'upa-oeste',
      'upa-sul',
    ]);
    // `next` aponta para 127.0.0.1 (Host da captura); o app usa a URL base.
    expect(requested.map((url) => url.host).toSet(), {'10.0.2.2'});
    expect(requested.last.queryParameters['page'], '2');

    final centro = units.first;
    expect(centro.address, 'Rua Exemplo, 120 · Setor Central, Goiânia');
    expect(centro.services, ['Clínica geral', 'Ortopedia', 'Pediatria']);
    expect(centro.operationalData?.availability, AvailabilityLevel.high);
    expect(centro.operationalData?.waitMinutes, 20);
    expect(centro.operationalData?.peopleWaiting, 18);
    expect(centro.isDemo, isTrue);
    expect(units[1].operationalData?.availability, AvailabilityLevel.low);
    expect(units[3].operationalData?.availability, AvailabilityLevel.moderate);
  });

  test('a leitura capturada deixa de ser atual ao envelhecer', () async {
    final centro = (await repository.fetchUnits(city: 'Goiânia')).first;
    final updatedAt = centro.operationalData!.updatedAt!;

    expect(
      centro.operationalState(now: updatedAt.add(const Duration(minutes: 5))),
      OperationalDataState.current,
    );
    expect(
      centro.operationalState(now: updatedAt.add(const Duration(hours: 2))),
      OperationalDataState.stale,
    );
  });

  test('unidade sem leitura operacional vem com dados ausentes', () async {
    final oeste = await repository.fetchUnit('upa-oeste');

    expect(oeste.operationalData, isNull);
    expect(oeste.operationalState(), OperationalDataState.missing);
    expect(oeste.isDemo, isTrue);
  });

  test('cidade sem unidades devolve lista vazia', () async {
    expect(await repository.fetchUnits(city: 'Aparecida de Goiânia'), isEmpty);
  });

  test('lê o catálogo de serviços', () async {
    expect(await repository.fetchServices(), [
      'Clínica geral',
      'Ortopedia',
      'Pediatria',
    ]);
  });

  test('404 do backend vira erro do cliente', () async {
    await expectLater(
      repository.fetchUnit('nao-existe'),
      throwsA(
        isA<HealthApiException>()
            .having((e) => e.kind, 'kind', HealthApiFailureKind.client)
            .having((e) => e.statusCode, 'status', 404),
      ),
    );
  });
}
