import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:rotasaude/models/health_unit.dart';
import 'package:rotasaude/services/straight_line_distance.dart';
import 'package:url_launcher/url_launcher.dart';

String? mapDestination(HealthUnit unit) =>
    isValidGeographicPosition(unit.position)
    ? '${unit.position.latitude},${unit.position.longitude}'
    : unit.address.trim().isEmpty
    ? null
    : unit.address.trim();

Future<bool> openUnitInMaps(HealthUnit unit) async {
  final destination = mapDestination(unit);
  if (destination == null) return false;
  final encoded = Uri.encodeComponent(destination);
  final uri = switch (defaultTargetPlatform) {
    TargetPlatform.android => Uri.parse('geo:0,0?q=$encoded'),
    TargetPlatform.iOS => Uri.parse('maps://?daddr=$encoded&dirflg=d'),
    _ => Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': destination,
    }),
  };
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
