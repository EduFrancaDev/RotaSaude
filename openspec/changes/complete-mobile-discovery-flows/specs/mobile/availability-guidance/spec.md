## Purpose

Explicar os indicadores de disponibilidade exibidos no protótipo e evitar que cores ou números sejam interpretados como orientação clínica.

## ADDED Requirements

### Requirement: Indicadores têm texto e significado operacional
O aplicativo SHALL usar os rótulos “Alta disponibilidade”, “Disponibilidade moderada”, “Baixa disponibilidade” e “Situação crítica” quando houver indicador. Cada indicador SHALL trazer texto além de cor e a tela “Disponibilidade” SHALL explicar que o nível resume a situação operacional e pode mudar.

#### Scenario: Abrir explicação pelo mapa
- **WHEN** a pessoa toca no controle de informação da exploração
- **THEN** a tela “Disponibilidade” lista os quatro níveis com texto legível e permite voltar ao contexto anterior

#### Scenario: Leitura sem distinção de cores
- **WHEN** a pessoa usa leitor de tela ou não distingue as cores dos chips
- **THEN** cada nível continua identificável pelo nome e pela descrição acessível

### Requirement: Informação não substitui triagem
A tela SHALL declarar que as cores não representam classificação clínica dos pacientes e não substituem triagem profissional. Nenhuma tela SHALL classificar o usuário, prometer atendimento ou indicar uma unidade como escolha clinicamente correta.

#### Scenario: Consulta da legenda
- **WHEN** a pessoa lê a explicação de disponibilidade
- **THEN** encontra a ressalva clínica e a indicação de que os dados do protótipo são ilustrativos
