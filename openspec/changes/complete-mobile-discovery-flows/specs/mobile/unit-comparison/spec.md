## Purpose

Permitir comparar alternativas em um mesmo quadro com tempos de espera, deslocamento, distância, serviços e disponibilidade claramente identificados.

## ADDED Requirements

### Requirement: Comparação usa o contexto da exploração
A aba “Comparar” SHALL exibir as unidades da área e dos critérios ativos, com nome, indicador textual, espera, distância e serviços quando disponíveis. O meio “Carro” ou “Ônibus” SHALL determinar qual tempo de deslocamento aparece em cada cartão. Cada métrica SHALL manter seu rótulo correto e a unidade de medida.

#### Scenario: Alternar para ônibus
- **WHEN** a pessoa troca de “Carro” para “Ônibus”
- **THEN** somente a métrica de deslocamento muda para os tempos demonstrativos de ônibus das mesmas unidades, enquanto espera, distância e serviços permanecem coerentes

#### Scenario: Alternar de volta para carro
- **WHEN** a pessoa retorna para “Carro”
- **THEN** os tempos demonstrativos de carro reaparecem sem alterar a unidade selecionada

### Requirement: Dados ausentes não geram comparação enganosa
Uma métrica não disponível SHALL aparecer como “Indisponível” ou equivalente, nunca como zero. O cartão SHALL manter distinção entre dados cadastrais e operacionais e SHALL mostrar aviso de caráter ilustrativo das estimativas.

#### Scenario: Unidade sem espera e transporte
- **WHEN** uma unidade não possui espera nem tempo para o meio escolhido
- **THEN** o cartão informa esses campos indisponíveis e não a posiciona como melhor opção por ausência de dados

### Requirement: Comparação leva à unidade certa
O aplicativo SHALL oferecer acesso aos detalhes da unidade comparada, preservando meio de transporte e área da consulta para a próxima decisão.

#### Scenario: Abrir detalhes a partir da comparação
- **WHEN** a pessoa seleciona um cartão de comparação
- **THEN** os detalhes abrem para a unidade daquele cartão e o retorno mantém o meio de transporte escolhido
