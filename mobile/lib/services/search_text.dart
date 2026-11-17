/// Normaliza o texto digitado sem alterar o nome exibido ou enviado à API.
String normalizedSearchText(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[áàãâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòõôö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c');
