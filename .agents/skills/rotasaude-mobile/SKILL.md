---
name: rotasaude-mobile
description: Implementar, refatorar ou organizar o aplicativo Flutter/Dart do RotaSaúde com arquitetura simples, reutilização criteriosa e validação. Use para mudanças no código mobile e nos arquivos do projeto ligados a ele; não para backend nem para trabalhos isolados de branding ou documentação N1.
---

# RotaSaúde Mobile

Execute o pedido no escopo do aplicativo Flutter/Dart. Preserve o comportamento existente, as decisões já documentadas e as alterações não commitadas do usuário. Não amplie uma mudança mobile para backend, banco de dados ou infraestrutura.

## Entenda antes de editar

1. Leia `AGENTS.md` como regras permanentes do repositório; depois consulte `README.md`, `docs/arquitetura-mobile.md`, `pubspec.yaml` e os arquivos afetados. Consulte `docs/tecnologias.md` ou `docs/n1/` somente quando a tarefa depender da proposta ou dos requisitos N1.
2. Para mudanças visuais, leia `assets/brand/README.md` e use o JPG ali apontado como referência de cor. Preserve os SVGs originais e as variantes existentes.
3. Confira `git status` e procure implementações relacionadas em `lib/` antes de criar arquivos ou mover código. Trate alterações existentes como trabalho do usuário.
4. Defina o comportamento solicitado, os estados relevantes e as plataformas afetadas. Em reorganizações, identifique todos os imports, assets, links e comandos que a mudança alcança.

## Trabalhe com impeccable na interface

- Quando o pedido criar, alterar ou avaliar telas, fluxos, textos de interface, tema ou acessibilidade Flutter, use também a skill `impeccable`. Siga seu fluxo de contexto e o playbook adequado; para a interface do cidadão, use o modo **Operate** e as orientações para plataforma nativa. Em mudanças internas sem efeito na UI, use apenas esta skill.
- `impeccable` orienta as decisões de UX e o acabamento visual da superfície solicitada. Esta skill e `AGENTS.md` orientam a implementação Flutter, o escopo mobile, as dependências e a validação técnica. Busque qualidade dentro do pedido; não transforme um refinamento em redesenho nem crie camadas, packages ou funcionalidades fora do escopo para aplicar uma sugestão visual.
- O JPG indicado em `assets/brand/README.md` é a referência da marca, e `docs/arquitetura-mobile.md` registra as decisões técnicas. Se `PRODUCT.md` ou `DESIGN.md` existirem, use-os para contexto de produto e direção visual sem substituir essas referências. Resolva divergências pelo pedido atual e pelas fontes correspondentes, sem duplicar documentação.
- Valide a UI no Android físico quando disponível, seguindo as passagens visuais limitadas de `impeccable` e as verificações Dart/Flutter abaixo. Os comandos `live` e `detect` de `impeccable` são voltados à web e não se aplicam ao código Flutter nativo.

## Mantenha responsabilidades claras

- `lib/main.dart` inicia o app; `lib/app.dart` configura o widget raiz; `lib/screens/` compõe telas; `lib/theme/` concentra cores e tema.
- Crie `models/`, `services/`, `repositories/`, `widgets/` ou pastas por funcionalidade quando houver uma responsabilidade concreta. Não crie camadas vazias para completar uma árvore idealizada nem use `utils/` como destino genérico.
- Mantenha widgets de apresentação sem acesso direto a rede, persistência ou regras de negócio. Isole esse acesso quando a funcionalidade realmente existir.
- Prefira `StatefulWidget` e `setState` para estado local simples. Antes de introduzir gerenciamento de estado, navegação complexa ou uma nova arquitetura, demonstre o problema atual e o ganho da mudança.
- Use Dart com null safety, `final` e `const` quando cabíveis; não transporte padrões de React Native para o projeto artificialmente. Explique brevemente conceitos Flutter novos ao usuário quando ajudarem, usando comparações com React Native/TypeScript apenas como apoio.

## Aplique DRY sem abstração prematura

- Procure primeiro um widget, função, token ou capacidade nativa já existente. Reutilize quando a intenção e o comportamento coincidirem, não só a aparência.
- Extraia um componente compartilhado quando o mesmo padrão aparecer em três ou mais lugares com a mesma intenção, ou quando encapsular um contrato relevante de interação/acessibilidade. Um widget privado pode tornar uma tela mais clara antes disso, se tiver responsabilidade própria.
- Mantenha local a duplicação pequena e temporária. Não divida arquivos apenas por contagem de linhas nem crie APIs genéricas com muitas opções para atender dois usos distintos.
- Centralize decisões visuais recorrentes no tema e em tokens com nomes claros; evite cores e espaçamentos arbitrários repetidos nas telas.

## Escolha dependências e implemente com cuidado

- Antes de adicionar um package, verifique Flutter/Dart nativo e dependências já instaladas. Se ainda precisar de um package, confira documentação atual e pub.dev, justifique sua função e mantenha `pubspec.yaml` e `pubspec.lock` alinhados.
- Não adicione mapas, localização, HTTP, persistência ou renderização SVG antecipadamente. Código nativo Android/iOS exige uma necessidade que Flutter ou um plugin adequado não resolva.
- Para dados assíncronos, trate carregamento, sucesso, vazio, erro e dados desatualizados conforme o fluxo. Não apresente disponibilidade ou espera simulada como informação atual.
- Preserve áreas seguras, escala de texto, leitura por tecnologias assistivas, alvos de toque adequados e navegação de retorno nas telas afetadas.

## Valide e entregue

- Faça a menor mudança coerente. Atualize `docs/arquitetura-mobile.md` quando a estrutura ou uma decisão arquitetural mudar; atualize o `README.md` quando comandos de execução mudarem. Não mexa na documentação N1 para refletir detalhes transitórios do código.
- Execute `dart format --output=none --set-exit-if-changed lib` e `flutter analyze` para mudanças Dart. Rode testes focados quando houver comportamento que justifique teste; para mudanças de UI ou plataforma, confira o fluxo no Android físico quando disponível. Relate verificações que não puder executar, inclusive iOS neste ambiente Linux.
- Ao concluir, informe arquivos alterados, motivo das decisões de organização/reutilização, verificações realizadas e limitações restantes.
