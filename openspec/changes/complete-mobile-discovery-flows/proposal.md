## Why

O aplicativo já abre um mapa a partir da localização do aparelho, mas ainda não permite escolher uma unidade, comparar alternativas ou planejar o deslocamento. As telas de referência fornecidas para este pedido definem os fluxos que faltam para transformar essa base em um protótipo navegável e avaliável do RotaSaúde.

## What Changes

- Completar a exploração de unidades em mapa e lista, com busca, filtro de atendimento, ordenação e seleção sincronizada.
- Adicionar detalhes de unidade com dados disponíveis e uma apresentação honesta quando dados operacionais estiverem indisponíveis.
- Adicionar comparação por carro e ônibus, prévias de rota dos dois meios e explicação dos indicadores de disponibilidade.
- Adicionar escolha manual de cidade como alteração da área de consulta, mantendo a permissão e o serviço de localização do aparelho obrigatórios para entrar e continuar no app.
- Usar um conjunto local e determinístico de dados **explicitamente ilustrativos** para o protótipo. Nenhum valor de espera, disponibilidade, trânsito, ônibus ou trajeto será apresentado como dado atual ou calculado em tempo real.
- Preservar a entrada, a política atual de permissão, o mapa OpenStreetMap e a identidade visual da marca, adaptando as referências à interface Flutter nativa.

## Capabilities

### New Capabilities

- `mobile/location-context`: localização obrigatória e escolha manual da área de consulta.
- `mobile/unit-discovery`: mapa, lista, busca, filtros, ordenação e seleção de unidades.
- `mobile/unit-details`: detalhes cadastrais, operacionais e estado de dados indisponíveis.
- `mobile/unit-comparison`: comparação entre unidades por meio de transporte.
- `mobile/route-preview`: prévias ilustrativas de rota por carro e ônibus.
- `mobile/availability-guidance`: significado dos indicadores e avisos de segurança informacional.

### Modified Capabilities

Nenhuma. Ainda não há specs principais em `openspec/specs/`.

## Impact

- Flutter/Dart em `lib/app.dart`, `lib/screens/`, `lib/theme/` e novos modelos, dados locais ou widgets apenas onde houver responsabilidade concreta.
- Testes de widget e fluxo para navegação, estado compartilhado, filtros, alternância de transporte, permissão e ausência de dados.
- Documentação mobile atualizada ao implementar. Sem backend, API, banco de dados, cálculo clínico/operacional de disponibilidade, roteamento real ou nova coleta de dados pessoais.
- A implementação pode ser dividida entre agentes após um contrato comum de dados e navegação; a integração final precisa ser feita por um agente responsável.
