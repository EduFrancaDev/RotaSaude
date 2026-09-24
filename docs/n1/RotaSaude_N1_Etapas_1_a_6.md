# RotaSaúde — Projeto N1

## Visão Geral do Projeto

O **RotaSaúde** é uma aplicação mobile voltada à orientação do cidadão no acesso às unidades públicas de saúde. A proposta é integrar dados operacionais das instituições de saúde com recursos de geolocalização e mobilidade para permitir que a população consulte, de forma simples e atualizada, quais unidades estão próximas, qual é a situação atual de atendimento, quais serviços estão disponíveis e quanto tempo será necessário para chegar até cada local.

A aplicação não substitui sistemas hospitalares, profissionais de saúde ou processos de triagem. Seu papel é atuar como uma **camada de informação e apoio à decisão**, transformando dados operacionais das unidades em informações compreensíveis para o cidadão.

O conceito central do projeto é:

> **Informação em saúde + disponibilidade das unidades + geolocalização + mobilidade**

---

# 1. Nome e Identidade Visual

## 1.1 Nome do projeto

# RotaSaúde

O nome **RotaSaúde** foi escolhido por representar diretamente os dois principais elementos da solução:

- **Rota:** localização, deslocamento, distância, trânsito e transporte público;
- **Saúde:** acesso aos serviços públicos de atendimento e informações sobre a disponibilidade das instituições.

O objetivo é utilizar um nome simples, de fácil compreensão e memorização, permitindo que o usuário identifique rapidamente a finalidade do aplicativo.

## 1.2 Conceito da marca

A identidade visual do RotaSaúde deverá transmitir:

- confiança;
- acessibilidade;
- tecnologia;
- saúde;
- mobilidade;
- informação em tempo próximo ao real;
- simplicidade de utilização.

A interface deverá ser construída para um público amplo, incluindo usuários com pouca familiaridade com tecnologia. Por isso, serão priorizados elementos visuais simples, textos objetivos, ícones reconhecíveis e informações de destaque.

## 1.3 Slogan

> **RotaSaúde — Informação para escolher melhor onde buscar atendimento.**

Como alternativa curta:

> **Saúde mais perto de você.**

## 1.4 Paleta de cores

| Utilização | Cor | Hexadecimal |
|---|---|---|
| Cor principal | Azul Saúde | `#1677C8` |
| Cor secundária | Verde-água | `#14B8A6` |
| Azul escuro | Azul Profundo | `#0F3D5E` |
| Fundo principal | Branco | `#FFFFFF` |
| Fundo secundário | Cinza Claro | `#F4F7F9` |
| Texto principal | Grafite | `#1E293B` |
| Texto secundário | Cinza | `#64748B` |

### Cores de disponibilidade das unidades

As cores utilizadas para representar a situação das instituições serão diferentes das cores tradicionais utilizadas em classificações clínicas de risco, evitando confusão para o usuário.

| Situação da unidade | Cor | Hexadecimal |
|---|---|---|
| Alta disponibilidade | Azul Claro | `#38BDF8` |
| Disponibilidade moderada | Verde-água | `#14B8A6` |
| Baixa disponibilidade | Laranja | `#F97316` |
| Situação crítica | Roxo | `#7C3AED` |

> Essas cores representam exclusivamente a situação operacional da unidade e não correspondem à classificação clínica dos pacientes.

## 1.5 Direção visual do logotipo

O logotipo poderá combinar três conceitos:

**Localização + Saúde + Mobilidade**

Uma proposta é utilizar um marcador de localização contendo um símbolo simplificado relacionado à saúde. O objetivo é que o ícone consiga transmitir visualmente a ideia de:

> **“Localizar uma unidade de saúde.”**

---

# 2. Problema e Levantamento de Requisitos

## 2.1 Problema que o aplicativo pretende resolver

O RotaSaúde pretende enfrentar um problema relacionado ao acesso e à distribuição da demanda entre unidades públicas de saúde: a dificuldade do cidadão em saber, antes de se deslocar, **qual unidade próxima apresenta melhores condições de atendimento naquele momento**.

Atualmente, quando uma pessoa precisa buscar atendimento em uma unidade pública de urgência ou pronto atendimento, normalmente considera fatores como proximidade, conhecimento prévio da unidade ou indicação de terceiros. Entretanto, o cidadão geralmente não possui acesso fácil e centralizado a informações como:

- quantidade de pacientes aguardando atendimento;
- nível atual de demanda;
- estimativa de tempo de espera;
- tipos de atendimento disponíveis;
- distância até a unidade;
- tempo estimado de deslocamento;
- condições de trânsito;
- opções de transporte público.

Como consequência, unidades próximas podem apresentar níveis de demanda muito diferentes sem que o cidadão tenha informações suficientes para comparar as alternativas.

O problema central pode ser resumido da seguinte forma:

> **O cidadão não possui uma ferramenta centralizada capaz de apresentar, de maneira simples e atualizada, a disponibilidade das unidades públicas de saúde próximas e relacionar essas informações com localização, serviços disponíveis e condições de deslocamento.**

## 2.2 Por que esse problema é importante?

A situação das unidades públicas de saúde é dinâmica. Uma instituição pode apresentar variações de demanda ao longo do dia de acordo com fatores como:

- entrada de novos pacientes;
- classificação de risco;
- quantidade de pessoas aguardando;
- quantidade de pessoas já em atendimento;
- velocidade dos atendimentos;
- disponibilidade operacional da unidade;
- ocorrência de casos de maior complexidade.

Por isso, utilizar apenas o tamanho da fila não representa necessariamente a situação real da instituição.

A falta de informação pode fazer com que um cidadão:

- desloque-se até uma unidade com demanda muito elevada;
- encontre longos períodos de espera;
- procure uma instituição que não oferece o atendimento necessário;
- percorra uma distância desnecessária;
- deixe de considerar outra unidade próxima com melhores condições naquele momento.

Além do impacto para o cidadão, a disponibilização dessas informações pode contribuir para uma **distribuição mais equilibrada da procura entre unidades próximas**.

Exemplo:

| Unidade | Distância | Deslocamento | Espera estimada | Demanda |
|---|---:|---:|---:|---|
| Unidade A | 3 km | 8 min | 75 min | Alta |
| Unidade B | 6 km | 16 min | 20 min | Baixa |
| Unidade C | 5 km | 14 min | 40 min | Moderada |

Sem essas informações, o cidadão pode escolher automaticamente a Unidade A por ser a mais próxima. Com o RotaSaúde, ele poderá comparar diferentes alternativas.

> O aplicativo não pretende resolver sozinho a superlotação hospitalar. Esse problema possui causas estruturais relacionadas à infraestrutura, recursos humanos, capacidade assistencial e gestão. O RotaSaúde pretende atuar especificamente na **informação e distribuição da demanda**.

## 2.3 Funcionamento geral da solução

```text
Sistemas das instituições públicas de saúde
                    ↓
             API de integração
                    ↓
             Plataforma RotaSaúde
                    ↓
     Processamento e padronização dos dados
                    ↓
              Aplicativo mobile
                    ↓
                  Cidadão
```

As instituições continuarão utilizando seus próprios sistemas internos. O RotaSaúde funcionará como uma camada de integração capaz de receber dados operacionais, padronizá-los e transformá-los em informações compreensíveis para o usuário.

## 2.4 Indicador de disponibilidade

O aplicativo não deverá utilizar apenas a quantidade de pessoas em espera para representar a situação da unidade.

O **Indicador de Disponibilidade** poderá considerar:

- quantidade de pacientes aguardando;
- classificação de risco dos pacientes já triados;
- quantidade de pacientes em atendimento;
- média ou ritmo de atendimentos recentes;
- capacidade operacional da unidade.

A partir desses dados, a instituição poderá ser apresentada como:

- **Alta disponibilidade**
- **Disponibilidade moderada**
- **Baixa disponibilidade**
- **Situação crítica**

## 2.5 Levantamento de requisitos

### 2.5.1 Requisitos funcionais

#### RF01 — Obter localização do usuário
O aplicativo deverá utilizar a localização do dispositivo, mediante autorização, para identificar a posição atual do usuário.

#### RF02 — Localizar unidades públicas próximas
O sistema deverá identificar unidades públicas de saúde próximas à localização atual.

#### RF03 — Exibir unidades em mapa
O mapa deverá apresentar:

- localização do usuário;
- localização das unidades;
- distância aproximada;
- indicador visual de disponibilidade.

#### RF04 — Exibir nível de disponibilidade
Cada unidade deverá possuir um indicador atualizado da situação atual.

#### RF05 — Calcular o nível de demanda
O sistema deverá calcular o nível de disponibilidade considerando múltiplos dados operacionais.

#### RF06 — Exibir informações detalhadas
Ao selecionar uma unidade, o usuário deverá visualizar:

- nome;
- endereço;
- distância;
- disponibilidade;
- pacientes aguardando;
- estimativa de espera;
- tipos de atendimento;
- horário da última atualização.

#### RF07 — Consultar tipos de atendimento
O usuário deverá conseguir verificar quais serviços cada unidade oferece.

#### RF08 — Selecionar meio de transporte
O usuário poderá escolher inicialmente entre:

1. veículo particular;
2. transporte público.

#### RF09 — Calcular rota por veículo particular
O sistema deverá apresentar rota, distância, tempo estimado e condições de trânsito.

#### RF10 — Calcular rota por transporte público
O sistema deverá apresentar:

- ponto mais próximo;
- caminhada até o ponto;
- linha ou linhas;
- possíveis integrações;
- ponto de desembarque;
- caminhada final;
- tempo total estimado.

#### RF11 — Atualizar informações das unidades
As informações deverão ser atualizadas periodicamente a partir dos sistemas das instituições.

#### RF12 — Informar última atualização
O aplicativo deverá mostrar quando os dados foram atualizados pela última vez.

#### RF13 — Indicar dados indisponíveis
Caso uma instituição deixe de atualizar seus dados, o sistema não deverá apresentar informações antigas como atuais.

#### RF14 — Permitir comparação entre unidades
O usuário deverá conseguir comparar unidades considerando disponibilidade, espera, distância, deslocamento e serviços.

### 2.5.2 Requisitos não funcionais

#### RNF01 — Facilidade de uso
A interface deverá ser simples e intuitiva.

#### RNF02 — Acessibilidade
A aplicação deverá utilizar:

- textos legíveis;
- contraste adequado;
- ícones acompanhados de texto;
- botões adequados;
- navegação simples.

As informações de disponibilidade não deverão depender apenas de cores.

#### RNF03 — Atualização próxima ao tempo real
As informações deverão ser atualizadas com frequência suficiente para representar o cenário atual.

#### RNF04 — Desempenho
As principais consultas deverão ocorrer rapidamente.

#### RNF05 — Disponibilidade
A plataforma deverá ser projetada para funcionar continuamente.

#### RNF06 — Segurança
A comunicação entre aplicativo, servidor e sistemas integrados deverá utilizar mecanismos seguros.

#### RNF07 — Privacidade
A localização do usuário deverá ser utilizada somente mediante autorização e não deverá ser armazenada permanentemente sem necessidade.

#### RNF08 — Escalabilidade
A arquitetura deverá permitir a inclusão de novas instituições sem mudanças significativas na aplicação.

#### RNF09 — Interoperabilidade
A plataforma deverá ser capaz de integrar sistemas diferentes utilizados pelas instituições.

### 2.5.3 Requisitos de integração

#### RI01 — Integração com sistemas das instituições
As unidades deverão disponibilizar os dados necessários por meio de APIs, adaptadores ou outro mecanismo de integração.

#### RI02 — Padronização dos dados
As informações provenientes de sistemas diferentes deverão ser convertidas para um modelo padrão do RotaSaúde.

#### RI03 — Integração com mapas
A aplicação deverá utilizar um serviço capaz de fornecer:

- mapas;
- geolocalização;
- distância;
- cálculo de rotas;
- tempo estimado de deslocamento.

#### RI04 — Integração com dados de trânsito
O cálculo por veículo particular deverá considerar trânsito quando disponível.

#### RI05 — Integração com transporte público
O sistema deverá utilizar uma fonte capaz de fornecer:

- linhas;
- pontos;
- trajetos;
- integrações;
- estimativa de viagem.

### 2.5.4 Requisitos de dados

A plataforma deverá trabalhar com três grupos principais de dados:

- **dados cadastrais das unidades**, como identificação, localização, horário e serviços oferecidos;
- **dados operacionais agregados**, como quantidade de pacientes em espera, classificações de risco em formato estatístico, ritmo de atendimento e disponibilidade;
- **dados temporários de navegação do usuário**, como localização atual, unidade escolhida e meio de transporte.

O RotaSaúde não necessitará acessar prontuários ou informações clínicas individualizadas para cumprir suas funcionalidades principais. O detalhamento dos dados, sua origem e as operações de cadastro, consulta e alteração estão descritos na **Etapa 9 — Dados**.

### 2.5.5 Regras de negócio

#### RN01 — Dados agregados
O aplicativo não deverá exibir nome, CPF, prontuário, diagnóstico ou outras informações capazes de identificar pacientes.

#### RN02 — Gravidade influencia o indicador
A classificação de risco poderá possuir pesos diferentes no cálculo da pressão assistencial.

#### RN03 — Ritmo de atendimento influencia o indicador
O sistema deverá considerar a velocidade recente de atendimento da unidade.

#### RN04 — Informação desatualizada não será apresentada como atual
Dados antigos deverão ser identificados como indisponíveis ou desatualizados.

#### RN05 — O aplicativo não realiza diagnóstico
O RotaSaúde não realizará diagnóstico, triagem clínica ou indicação médica obrigatória. Seu papel será informativo e logístico.

---

# 3. Público-Alvo

## 3.1 Quem utilizará o aplicativo?

O RotaSaúde será destinado principalmente a **cidadãos que utilizam ou podem precisar utilizar a rede pública de saúde** e necessitam de informações para decidir qual unidade procurar.

O público inclui:

- adultos buscando atendimento para si;
- pais ou responsáveis procurando atendimento para crianças ou adolescentes;
- familiares buscando uma unidade para outra pessoa;
- idosos;
- estudantes;
- trabalhadores;
- pessoas que utilizam transporte público;
- pessoas que utilizam veículo particular;
- moradores que não conhecem todas as unidades da região;
- cidadãos temporariamente fora de sua região habitual.

## 3.2 Perfil do usuário

Como o RotaSaúde pretende atender a população em geral, não existe um único perfil de usuário.

| Característica | Perfil esperado |
|---|---|
| Idade | Ampla faixa etária |
| Escolaridade | Variada |
| Familiaridade com tecnologia | Baixa, média ou alta |
| Dispositivo | Smartphone com acesso à internet |
| Transporte | Veículo particular ou transporte público |
| Objetivo | Encontrar uma unidade adequada para buscar atendimento |
| Necessidade | Informação rápida, simples e atualizada |

## 3.3 Necessidades principais do usuário

O usuário precisa:

- localizar unidades próximas;
- compreender rapidamente a situação atual de cada uma;
- verificar se o atendimento procurado está disponível;
- estimar o tempo de deslocamento;
- comparar alternativas;
- visualizar rota;
- compreender as informações sem conhecimento técnico de gestão hospitalar.

## 3.4 Perfis de utilização

### Usuário com veículo particular
Valoriza principalmente:

- distância;
- trânsito;
- tempo de deslocamento;
- espera estimada;
- disponibilidade.

### Usuário de transporte público
Precisa considerar:

- ponto de ônibus;
- caminhada;
- linhas;
- integrações;
- ponto de desembarque;
- tempo total de viagem.

### Usuário com pouca familiaridade com tecnologia
Necessita de:

- linguagem simples;
- poucos passos;
- botões claros;
- ícones reconhecíveis;
- informações principais em destaque.

### Usuário com necessidades de acessibilidade
A aplicação deverá utilizar recursos visuais e textuais combinados, evitando que informações importantes dependam apenas de cor.

## 3.5 Persona de referência

### Carlos — Persona do RotaSaúde

**Idade:** 34 anos  
**Localização:** Goiânia — GO  
**Transporte:** carro em alguns dias e transporte público em outros  
**Familiaridade com tecnologia:** intermediária  
**Dispositivo:** smartphone Android  

Carlos precisa buscar atendimento e possui diferentes unidades próximas, mas não sabe:

- qual está mais cheia;
- quanto tempo poderá esperar;
- qual oferece o atendimento necessário;
- se vale a pena procurar uma unidade mais distante.

O RotaSaúde permite que ele compare disponibilidade, distância, espera e deslocamento antes de sair.

## 3.6 Princípio de inclusão

> **A tecnologia não deve criar uma nova barreira para o acesso à informação.**

Por isso, o RotaSaúde deverá priorizar:

- simplicidade;
- acessibilidade;
- rapidez;
- clareza;
- linguagem não técnica.

---

# 4. ODS da ONU

## 4.1 ODS escolhida

O RotaSaúde está diretamente relacionado ao:

# ODS 3 — Saúde e Bem-Estar

O objetivo da ODS 3 é assegurar uma vida saudável e promover o bem-estar para todas e todos, em todas as idades.

O projeto se relaciona com essa ODS porque busca utilizar tecnologia e informação para facilitar o acesso do cidadão aos serviços públicos de saúde.

## 4.2 Problema relacionado à ODS

A existência de unidades públicas não significa, por si só, que o cidadão consiga acessá-las de maneira eficiente.

As principais barreiras abordadas pelo projeto são:

- falta de informação atualizada;
- dificuldade de localizar unidades adequadas;
- falta de conhecimento sobre os serviços oferecidos;
- dificuldade de comparar espera e deslocamento;
- concentração de demanda em determinadas unidades.

O problema pode ser resumido como:

> **A dificuldade do cidadão em acessar informações atualizadas e centralizadas sobre disponibilidade, demanda, serviços e condições de deslocamento até as unidades públicas de saúde.**

## 4.3 Como o RotaSaúde contribui para a ODS 3

A contribuição ocorre em quatro frentes principais:

### Facilitação do acesso
Permite localizar rapidamente unidades próximas e identificar quais serviços são oferecidos.

### Transparência
Apresenta informações atualizadas sobre a situação das instituições.

### Distribuição da demanda
Permite que o cidadão conheça alternativas além da unidade mais próxima ou mais conhecida.

### Planejamento do deslocamento
Considera distância, trânsito, transporte público e tempo estimado de viagem.

## 4.4 Meta específica relacionada

O projeto possui relação especialmente com a:

### Meta 3.8 — Cobertura Universal de Saúde

Essa meta está relacionada à ampliação do acesso a serviços essenciais de saúde de qualidade.

O RotaSaúde contribui principalmente reduzindo **barreiras informacionais e logísticas** no acesso à rede já existente.

A aplicação não cria novas unidades, profissionais ou serviços, mas melhora a forma como o cidadão identifica e acessa as alternativas disponíveis.

## 4.5 Relação entre ODS, problema e solução

| Elemento | Relação com o projeto |
|---|---|
| ODS | ODS 3 — Saúde e Bem-Estar |
| Meta principal | Meta 3.8 — Acesso a serviços essenciais de saúde |
| Problema | Falta de informações centralizadas e atualizadas |
| Público afetado | Cidadãos que utilizam a rede pública |
| Barreira | Informação, localização e deslocamento |
| Solução | Aplicativo com disponibilidade, serviços, mapa e rotas |
| Impacto | Melhor orientação e potencial distribuição mais equilibrada da demanda |

## 4.6 Impacto esperado

O impacto esperado inclui:

- facilitar o acesso às unidades;
- melhorar a transparência;
- reduzir deslocamentos desnecessários;
- aumentar a autonomia do cidadão;
- permitir melhor planejamento;
- contribuir para uma distribuição mais equilibrada da procura.

---

# 5. Proposta de Solução

## 5.1 Visão geral

O RotaSaúde será uma aplicação mobile integrada aos sistemas das instituições públicas de saúde.

Sua proposta é transformar dados operacionais em informações simples que permitam ao cidadão responder:

> **Quais unidades estão próximas, qual é a situação atual de cada uma, que atendimento oferecem e quanto tempo levo para chegar até elas?**

## 5.2 Fluxo da solução

```text
Dados das instituições
        ↓
Integração por API
        ↓
Padronização dos dados
        ↓
Cálculo do indicador de disponibilidade
        ↓
Apresentação no mapa
        ↓
Consulta detalhada da unidade
        ↓
Escolha do meio de transporte
        ↓
Rota até o atendimento
```

## 5.3 Mapa como interface principal

A tela principal será baseada em um mapa mostrando:

- posição atual do usuário;
- unidades próximas;
- distância;
- nível de disponibilidade.

Exemplo:

```text
               UNIDADE A
          Baixa disponibilidade
                  🟠

                   │
                   │ 4,5 km
                   │
            📍 LOCALIZAÇÃO
               DO USUÁRIO

          /                    \
         /                      \
        ▼                        ▼

   UNIDADE B                UNIDADE C
Alta disponibilidade   Disponibilidade moderada
      🔵                        🟢
```

## 5.4 Detalhes da unidade

Ao selecionar uma unidade, o cidadão visualizará informações como:

```text
UPA Exemplo

Disponibilidade:
ALTA

Pacientes aguardando:
18

Espera estimada:
25 minutos

Distância:
5,8 km

Atualizado:
há 2 minutos

Atendimentos:
✓ Clínica Geral
✓ Pediatria
✓ Ortopedia
```

## 5.5 Planejamento do deslocamento

### Veículo particular

O aplicativo deverá apresentar:

- rota;
- distância;
- tempo estimado;
- condições de trânsito.

### Transporte público

O aplicativo deverá apresentar:

```text
Sua localização
       ↓
Caminhada até o ponto
       ↓
Linha de ônibus
       ↓
Possível integração
       ↓
Ponto de desembarque
       ↓
Caminhada final
       ↓
Unidade de saúde
```

## 5.6 Diferencial da solução

O principal diferencial do RotaSaúde não está em uma função isolada, mas na **integração de diferentes informações em uma única experiência**.

A solução combina:

> **Saúde + Geolocalização + Disponibilidade + Mobilidade + Dados atualizados**

Os principais diferenciais são:

- integração entre saúde e mobilidade;
- indicador de disponibilidade baseado em múltiplos fatores;
- atualização frequente das informações;
- comparação entre diferentes unidades;
- inclusão de transporte público;
- interface simples;
- arquitetura preparada para diferentes instituições;
- possibilidade de expansão para novas regiões.

## 5.7 Limites da solução

O RotaSaúde não deverá:

- realizar diagnóstico;
- classificar clinicamente o cidadão;
- substituir triagem profissional;
- garantir tempo exato de atendimento;
- obrigar o usuário a escolher determinada unidade.

Seu papel será fornecer **informações de apoio à decisão**.

---

# 6. Principais Funcionalidades

Para a primeira versão do projeto foram definidas **8 funcionalidades principais**.

## 6.1 Mapa com unidades públicas próximas

O aplicativo deverá utilizar a localização atual do usuário para apresentar unidades públicas de saúde próximas em um mapa interativo.

O usuário poderá visualizar:

- sua localização;
- unidades próximas;
- distância;
- nível de disponibilidade.

## 6.2 Indicador de disponibilidade

Cada unidade terá um indicador baseado em:

- pacientes aguardando;
- classificação de risco;
- pacientes em atendimento;
- ritmo recente de atendimento;
- capacidade operacional.

Os níveis poderão ser:

- Alta disponibilidade;
- Disponibilidade moderada;
- Baixa disponibilidade;
- Situação crítica.

## 6.3 Consulta detalhada da unidade

Ao selecionar uma unidade, o usuário poderá visualizar:

- nome;
- endereço;
- telefone;
- horário de funcionamento;
- distância;
- demanda;
- espera estimada;
- tipos de atendimento;
- última atualização.

## 6.4 Consulta dos tipos de atendimento

O aplicativo deverá informar quais serviços são oferecidos por cada unidade, como:

- clínica geral;
- pediatria;
- ortopedia;
- atendimento adulto;
- atendimento infantil;
- outros serviços disponíveis.

## 6.5 Estimativa de tempo de espera

O sistema deverá apresentar uma estimativa baseada nos dados operacionais recebidos.

Exemplo:

```text
Espera estimada:
aproximadamente 30 minutos
```

O aplicativo deverá informar que esse valor é apenas uma estimativa e poderá mudar.

## 6.6 Rota por veículo particular

O usuário poderá consultar:

- trajeto;
- distância;
- tempo estimado;
- trânsito atual.

Exemplo:

```text
Veículo particular

Distância: 6,4 km
Tempo estimado: 14 min
Trânsito: Moderado
```

## 6.7 Rota por transporte público

O aplicativo deverá apresentar:

- ponto mais próximo;
- caminhada;
- linha;
- integrações;
- desembarque;
- caminhada final;
- tempo total estimado.

## 6.8 Comparação entre unidades

O usuário deverá conseguir comparar unidades considerando:

- disponibilidade;
- espera;
- distância;
- tempo de deslocamento;
- serviços oferecidos;
- meio de transporte.

Exemplo:

| Unidade | Disponibilidade | Espera | Carro | Transporte público |
|---|---|---:|---:|---:|
| Unidade A | Baixa | 65 min | 8 min | 20 min |
| Unidade B | Alta | 20 min | 17 min | 29 min |
| Unidade C | Moderada | 40 min | 13 min | 24 min |

---

---

# 9. Dados

## 9.1 Visão geral dos dados

O **RotaSaúde** precisará armazenar e processar dados relacionados às unidades públicas de saúde, ao funcionamento operacional dessas instituições e às informações necessárias para calcular disponibilidade e deslocamento.

A proposta seguirá o princípio de **minimização de dados**: utilizar apenas as informações necessárias para o funcionamento da aplicação.

O sistema não precisará receber ou armazenar prontuários, diagnósticos ou dados que identifiquem individualmente os pacientes. Para representar a situação das unidades serão utilizados **dados agregados e operacionais**.

---

## 9.2 Dados das unidades de saúde

Cada instituição integrada à plataforma deverá possuir um cadastro com informações relativamente estáveis, como:

- identificador único da unidade;
- nome da instituição;
- endereço;
- latitude e longitude;
- telefone;
- horário de funcionamento;
- tipos de atendimento disponíveis;
- status de funcionamento;
- data e horário da última atualização cadastral.

Esses dados serão cadastrados quando uma nova instituição entrar na plataforma e poderão ser alterados quando houver mudança de endereço, horário, telefone ou serviços oferecidos.

---

## 9.3 Dados operacionais das instituições

Os sistemas das unidades fornecerão periodicamente informações agregadas sobre o cenário atual de atendimento.

Entre os dados necessários poderão estar:

- quantidade de pacientes aguardando triagem;
- quantidade de pacientes aguardando atendimento;
- quantidade de pacientes já triados;
- quantidade de pacientes por classificação de risco;
- quantidade de pacientes atualmente em atendimento;
- quantidade de atendimentos concluídos em determinado intervalo;
- média ou ritmo de atendimentos da última hora;
- capacidade operacional informada pela instituição;
- data e horário da última atualização.

Essas informações alimentarão o cálculo do **Indicador de Disponibilidade da Unidade** e da estimativa de espera.

Exemplo de informação recebida de maneira agregada:

```text
Pacientes aguardando: 24

Classificação:
Azul: 5
Verde: 10
Amarelo: 6
Laranja: 3
Vermelho: 0

Pacientes em atendimento: 12
Atendimentos na última hora: 18
```

Nenhuma dessas informações precisa identificar quem são os pacientes.

---

## 9.4 Dados calculados pelo RotaSaúde

A própria plataforma produzirá dados derivados das informações recebidas.

Entre eles:

- Indicador de Disponibilidade;
- nível atual de disponibilidade;
- estimativa de tempo de espera;
- horário do último cálculo;
- status de atualização da unidade.

Exemplo:

```text
Disponibilidade: MODERADA
Espera estimada: 35 minutos
Última atualização: 14:32
```

Para o MVP, a aplicação poderá trabalhar principalmente com a situação atual de cada instituição. Um histórico limitado poderá ser mantido quando necessário para cálculo de médias e análise do ritmo de atendimento.

---

## 9.5 Dados de localização e deslocamento do usuário

Para localizar unidades e calcular rotas, o aplicativo utilizará temporariamente:

- latitude e longitude atuais do usuário;
- unidade selecionada;
- meio de transporte escolhido;
- distância calculada;
- tempo estimado de deslocamento;
- rota calculada.

O fluxo será:

```text
Localização atual
       ↓
Unidade selecionada
       ↓
Meio de transporte
       ↓
Cálculo da rota
       ↓
Distância e tempo estimado
```

A localização deverá ser utilizada somente mediante autorização do usuário e não precisará ser armazenada permanentemente para o funcionamento das funcionalidades principais.

---

## 9.6 Cadastro do cidadão

Para o MVP, **não será obrigatório criar uma conta** para consultar as informações do RotaSaúde.

O cidadão poderá utilizar o aplicativo para:

- visualizar unidades próximas;
- consultar disponibilidade;
- consultar tipos de atendimento;
- comparar unidades;
- calcular rotas.

Essa decisão reduz a quantidade de dados pessoais necessários para utilizar a plataforma.

Funcionalidades futuras poderão incluir conta, unidades favoritas ou preferências, mas elas não serão essenciais para a primeira versão.

---

## 9.7 Dados que não serão utilizados

O RotaSaúde não precisará armazenar ou disponibilizar dados individualizados dos pacientes, como:

- nome;
- CPF;
- telefone;
- endereço residencial;
- prontuário;
- diagnóstico;
- medicamentos;
- exames;
- histórico clínico.

A plataforma utilizará apenas informações estatísticas necessárias para representar a situação operacional da unidade.

---

## 9.8 Dados cadastrados, consultados e alterados

### Dados cadastrados

Serão cadastrados principalmente dados relativamente estáveis das instituições:

- unidade de saúde;
- endereço e coordenadas;
- telefone;
- horário de funcionamento;
- tipos de atendimento;
- capacidade operacional quando aplicável;
- parâmetros necessários para integração.

### Dados consultados pelo cidadão

O aplicativo permitirá consultar:

- unidades próximas;
- nome e endereço;
- disponibilidade atual;
- quantidade agregada de pacientes em espera;
- estimativa de tempo de espera;
- tipos de atendimento;
- horário de funcionamento;
- distância;
- tempo de deslocamento;
- rota;
- horário da última atualização.

### Dados alterados ou atualizados

Existirão dois tipos principais de atualização:

**Administrativa:**

- endereço;
- telefone;
- horário de funcionamento;
- tipos de atendimento;
- demais informações cadastrais.

**Automática, por integração:**

- pacientes aguardando;
- distribuição das classificações de risco;
- pacientes em atendimento;
- ritmo recente de atendimentos;
- disponibilidade calculada;
- estimativa de espera;
- horário da última atualização.

---

## 9.9 Resumo dos dados

| Categoria | Exemplos | Origem | Operações principais |
|---|---|---|---|
| Dados da unidade | Nome, endereço, telefone, horário | Administração/Instituição | Cadastrar, consultar e alterar |
| Localização da unidade | Latitude e longitude | Administração/Instituição | Cadastrar, consultar e alterar |
| Serviços | Clínica, pediatria, ortopedia etc. | Instituição | Cadastrar, consultar e alterar |
| Dados operacionais | Fila, triagem, atendimentos recentes | Sistema da unidade | Receber e atualizar |
| Disponibilidade | Nível calculado | RotaSaúde | Calcular e consultar |
| Espera estimada | Tempo aproximado | RotaSaúde | Calcular e consultar |
| Localização do usuário | Latitude e longitude atuais | Smartphone | Utilizar temporariamente |
| Rota | Distância, trajeto e duração | Serviço de mapas | Consultar |
| Dados pessoais dos pacientes | Não utilizados | — | Não armazenar |

O fluxo principal dos dados será:

```text
SISTEMA DA UNIDADE
        ↓
Dados operacionais agregados
        ↓
API de integração
        ↓
RotaSaúde
        ↓
Processamento e cálculo
        ↓
Informação simplificada
        ↓
CIDADÃO
```

---

# 10. Recursos do Celular

## 10.1 Recursos utilizados

O RotaSaúde utilizará recursos do smartphone principalmente para identificar a localização do cidadão, acessar informações atualizadas e calcular o deslocamento até as unidades.

Os recursos centrais serão:

- localização/GPS;
- internet;
- serviço de mapas e rotas;
- recursos de acessibilidade do sistema operacional.

Notificações poderão ser adicionadas como recurso complementar. Câmera, microfone, arquivos e biometria não serão necessários para o MVP.

---

## 10.2 Localização e GPS — utilizados

A localização será um dos recursos essenciais da aplicação.

Ela permitirá:

- identificar a posição atual do cidadão;
- localizar instituições próximas;
- calcular a distância;
- encontrar pontos de transporte público;
- calcular rotas;
- estimar o tempo de deslocamento.

```text
Localização do celular
        ↓
Posição do usuário
        ↓
Unidades próximas
        ↓
Distância e rota
```

O acesso dependerá da autorização do usuário.

---

## 10.3 Internet — utilizada

A conexão com a internet será necessária para que o aplicativo consulte informações atualizadas.

Ela será utilizada para:

- comunicação com a API do RotaSaúde;
- consulta dos dados das unidades;
- carregamento do mapa;
- cálculo de rotas;
- informações de trânsito;
- informações de transporte público;
- atualização do indicador de disponibilidade.

Sem conexão, a aplicação não poderá garantir informações atuais sobre disponibilidade, trânsito ou transporte público.

---

## 10.4 Mapas e rotas — utilizados

O serviço de mapas será fundamental para a experiência do RotaSaúde e trabalhará em conjunto com localização e internet.

Ele será responsável por:

- exibir a posição do usuário;
- mostrar as instituições no mapa;
- calcular distâncias;
- traçar rotas;
- estimar duração do deslocamento;
- considerar condições de trânsito;
- apresentar trajetos de transporte público quando disponíveis.

Embora o mapa seja fornecido por um serviço externo e não seja um sensor físico do celular, ele será um recurso essencial da aplicação.

---

## 10.5 Notificações — opcionais

As notificações poderão ser utilizadas posteriormente para avisos relacionados a uma unidade selecionada, por exemplo:

- alteração significativa de disponibilidade;
- indisponibilidade temporária de dados;
- mudanças relevantes nas informações da instituição.

Exemplo:

```text
RotaSaúde
A disponibilidade da unidade selecionada mudou de
"Moderada" para "Baixa".
```

As notificações não serão obrigatórias para o MVP e somente serão utilizadas mediante autorização do usuário.

---

## 10.6 Câmera — não utilizada no MVP

A câmera não é necessária para as funcionalidades principais. O RotaSaúde não precisará tirar fotografias, escanear documentos ou registrar imagens do usuário.

---

## 10.7 Microfone — não utilizado no MVP

O aplicativo não utilizará gravação de áudio, chamadas por voz ou reconhecimento de fala. Portanto, não precisará acessar o microfone.

---

## 10.8 Arquivos — não utilizados no MVP

O aplicativo não precisará acessar fotos, documentos ou arquivos pessoais armazenados no dispositivo para executar suas funcionalidades principais.

---

## 10.9 Biometria — não utilizada no MVP

Como a primeira versão não exigirá cadastro obrigatório, também não será necessária autenticação por impressão digital ou reconhecimento facial.

A biometria poderá ser avaliada futuramente caso sejam criadas funcionalidades de conta que justifiquem autenticação adicional.

---

## 10.10 Recursos de acessibilidade — utilizados

A interface deverá ser compatível com recursos de acessibilidade dos sistemas Android e iOS, como:

- leitores de tela;
- aumento do tamanho da fonte;
- contraste;
- descrição textual de elementos;
- navegação assistida.

Informações importantes não deverão depender exclusivamente de cor.

Por exemplo, o aplicativo deverá apresentar:

> **🟠 Baixa disponibilidade**

em vez de exibir apenas um marcador laranja sem texto explicativo.

---

## 10.11 Resumo dos recursos do celular

| Recurso | Utilização | Essencial para o MVP? |
|---|---|---|
| Localização/GPS | Identificar posição e unidades próximas | Sim |
| Internet | Consultar APIs e dados atualizados | Sim |
| Mapas e rotas | Exibir unidades e calcular deslocamentos | Sim |
| Recursos de acessibilidade | Tornar a interface utilizável por um público amplo | Sim |
| Notificações | Alertas sobre alterações relevantes | Não, opcional |
| Câmera | Não utilizada | Não |
| Microfone | Não utilizado | Não |
| Arquivos | Não utilizados | Não |
| Biometria | Não utilizada | Não |

O princípio adotado será:

> **O aplicativo solicitará acesso apenas aos recursos necessários para executar suas funcionalidades.**

O fluxo de utilização dos recursos pode ser resumido como:

```text
USUÁRIO ABRE O RotaSaúde
          ↓
Autoriza a localização
          ↓
Aplicativo identifica sua posição
          ↓
Usa internet para consultar unidades
          ↓
Exibe instituições no mapa
          ↓
Usuário seleciona uma unidade
          ↓
Escolhe o meio de transporte
          ↓
Serviço de mapas calcula rota e duração
          ↓
Usuário visualiza o deslocamento
```

---

# Síntese das Etapas Desenvolvidas

O RotaSaúde nasce de um problema simples: **o cidadão precisa de atendimento, mas não possui informação suficiente para comparar as unidades públicas disponíveis antes de iniciar o deslocamento**.

A solução integra dados operacionais agregados das instituições com geolocalização e mobilidade para transformar informações complexas em uma experiência simples.

O usuário poderá abrir o aplicativo e responder rapidamente:

- Onde estou?
- Quais unidades estão próximas?
- Qual é a situação atual de cada uma?
- Qual oferece o atendimento de que preciso?
- Quanto tempo posso esperar?
- Quanto tempo levo para chegar?
- Posso chegar de carro ou transporte público?

O projeto se relaciona diretamente à **ODS 3 — Saúde e Bem-Estar**, especialmente à **Meta 3.8**, por buscar reduzir barreiras informacionais e logísticas no acesso aos serviços públicos de saúde.

O diferencial do RotaSaúde está em reunir, em uma única ferramenta:

> **Disponibilidade da unidade + tipos de atendimento + localização + tempo de espera + trânsito + transporte público**

Para isso, a plataforma utilizará dados cadastrais das instituições, informações operacionais agregadas e a localização temporária do usuário, sem necessidade de acessar prontuários ou dados pessoais dos pacientes.

No smartphone, os recursos essenciais serão **localização/GPS, internet e mapas**, mantendo câmera, microfone, arquivos e biometria fora do escopo do MVP.

A proposta não é substituir a decisão médica ou a gestão das instituições, mas oferecer ao cidadão uma visão mais clara da rede pública disponível e permitir uma escolha mais informada.

