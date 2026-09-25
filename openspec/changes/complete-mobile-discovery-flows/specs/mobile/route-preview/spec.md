## Purpose

Mostrar uma prévia demonstrativa do deslocamento até a unidade escolhida por carro ou ônibus, sem simular navegação ou tráfego em tempo real.

## ADDED Requirements

### Requirement: Prévia de carro é específica da unidade
A tela “Rota até a unidade” SHALL mostrar destino, meio “Carro”, duração, distância, descrição do trajeto e condição de trânsito apenas quando esses valores existirem no conjunto demonstrativo. O desenho do trajeto SHALL ser identificado como ilustrativo e SHALL NOT fingir representar o caminho calculado a partir da posição real do aparelho.

#### Scenario: Abrir rota de carro
- **WHEN** a pessoa pede opções de rota de uma unidade com prévia de carro
- **THEN** vê a unidade correta, duração e distância demonstrativas, a descrição do percurso e uma ação para ver ônibus

### Requirement: Prévia de ônibus mostra etapas ordenadas
A prévia de “Ônibus” SHALL mostrar duração total e as etapas demonstrativas de caminhada inicial, linha, desembarque e caminhada final, incluindo integração apenas quando existir no dado. A tela SHALL declarar que horários e trajetos são ilustrativos e permitir voltar à prévia de carro.

#### Scenario: Troca para ônibus
- **WHEN** a pessoa seleciona “Ônibus”
- **THEN** o destino permanece o mesmo e surgem tempo total e etapas correspondentes àquela unidade

#### Scenario: Retorno para carro
- **WHEN** a pessoa toca “Ver rota de carro”
- **THEN** a prévia de carro da mesma unidade reaparece

### Requirement: Rota ausente é explícita
O aplicativo SHALL informar quando uma prévia não existe para a unidade ou para o meio escolhido e SHALL NOT fabricar um caminho a partir de distância em linha reta.

#### Scenario: Prévia não cadastrada
- **WHEN** a pessoa seleciona um meio sem dados de rota demonstrativa
- **THEN** vê “Rota indisponível no protótipo” e pode escolher outro meio ou voltar aos detalhes
