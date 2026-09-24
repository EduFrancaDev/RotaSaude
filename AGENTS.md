# Regras do repositório RotaSaúde

Estas regras se aplicam a qualquer alteração neste repositório. Para implementar ou reorganizar o aplicativo, consulte também `.agents/skills/rotasaude-mobile/SKILL.md`.

## Escopo e referências

- O produto neste repositório é o aplicativo Flutter/Dart para Android e iOS. API, banco de dados, sistemas das unidades e cálculo do indicador são integrações externas; só implemente esses componentes mediante pedido explícito.
- Antes de editar, leia os arquivos envolvidos, confira `git status` e preserve alterações existentes. Consulte `README.md` para execução, `docs/arquitetura-mobile.md` para decisões técnicas e `assets/brand/README.md` para identidade visual.
- Faça a menor mudança coerente com o pedido. Evite reorganizações, dependências ou alterações em documentos N1 sem relação com a tarefa.

## Código e organização

- Mantenha `lib/main.dart` como entrada, `lib/app.dart` como raiz, `lib/screens/` para composição das telas e `lib/theme/` para cores e tema compartilhados.
- Crie widgets, modelos, serviços, repositórios ou pastas por funcionalidade quando existir uma responsabilidade concreta. Não crie camadas vazias nem use `utils/` como destino genérico.
- Separe apresentação de acesso a rede, persistência e regras de negócio quando esses recursos existirem. Para estado local simples, prefira `StatefulWidget` e `setState`.
- Siga null safety e use `final` e `const` quando cabíveis. Adote gerenciamento de estado, navegação ou código nativo adicional apenas diante de uma necessidade concreta.
- Procure uma solução existente antes de duplicar. Extraia um widget compartilhado quando a mesma intenção aparecer em três ou mais lugares, ou quando um contrato relevante de interação ou acessibilidade justificar a extração. Não crie abstrações genéricas para usos apenas visualmente parecidos.
- Centralize cores e estilos recorrentes no tema. Para a marca, use o JPG indicado em `assets/brand/README.md` como referência e preserve os SVGs de origem.

## Dependências e experiência

- Prefira recursos do Flutter/Dart e dependências já presentes. Ao adicionar um package necessário, registre a razão e mantenha `pubspec.yaml` e `pubspec.lock` coerentes.
- Em fluxos assíncronos, trate os estados de carregamento, vazio e erro pertinentes. Não apresente dados simulados como informação atual.
- Preserve áreas seguras, escala de texto, acessibilidade, alvos de toque e navegação de retorno nas telas afetadas.

## Documentação e validação

- Atualize `docs/arquitetura-mobile.md` quando a estrutura ou decisão técnica mudar; atualize `README.md` quando os comandos de uso mudarem.
- Para mudanças Dart, execute `dart format --output=none --set-exit-if-changed lib` e `flutter analyze`. Faça testes focados quando verificarem comportamento real; confira no Android físico os fluxos de UI ou plataforma quando o dispositivo estiver disponível.
- Ao entregar, informe os arquivos alterados, as verificações executadas e o que não pôde ser verificado. Build iOS exige macOS e Xcode.
