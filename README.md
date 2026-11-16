# RotaSaúde

Aplicativo mobile em Flutter e Dart para ajudar o cidadão a consultar unidades públicas de saúde, comparar informações e planejar o deslocamento. O repositório contém a base do aplicativo para Android e iOS. Backend, banco de dados e infraestrutura ficam fora do escopo deste código; o app consome a API Django de leitura (`/api/v1/units/`, `/api/v1/units/{id}/`, `/api/v1/services/`).

## Executar no Android conectado

É necessário ter o Flutter SDK e o Android SDK configurados. Neste computador, o Flutter está em `~/develop/flutter` e seu `bin` foi adicionado ao `PATH` do Zsh.

```bash
flutter pub get
flutter devices
flutter run -d <ID_DO_DISPOSITIVO>
```

### Conectar ao backend Django

A URL base da API é definida na compilação e não leva credenciais:

```bash
flutter run -d <ID_DO_DISPOSITIVO> --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Sem `--dart-define`, o app usa `http://127.0.0.1:8000`. Com o backend no ar (`docker compose up` e `seed_demo_units`, veja o README do backend):

- **Aparelho físico ou emulador via USB**: `adb reverse tcp:8000 tcp:8000` e use `127.0.0.1:8000`. Funciona sem alterar `ALLOWED_HOSTS` do Django.
- **Emulador Android sem `adb reverse`**: `--dart-define=API_BASE_URL=http://10.0.2.2:8000` e inclua `10.0.2.2` em `DJANGO_ALLOWED_HOSTS` no `.env` do backend.
- **Aparelho na mesma rede**: `--dart-define=API_BASE_URL=http://<IP_DO_PC>:8000`, `API_BIND=0.0.0.0` e o IP em `DJANGO_ALLOWED_HOSTS`.

Builds de debug aceitam HTTP; release exige HTTPS. Leituras operacionais com mais de 30 minutos são tratadas como desatualizadas; para alterar a janela, use `--dart-define=OPERATIONAL_MAX_AGE_MINUTES=<minutos>`.

Durante o `flutter run`, pressione `r` para Hot Reload, `R` para Hot Restart e `q` para encerrar. O identificador do aplicativo é `com.edufrancadev.rotasaude`. O projeto iOS foi gerado, mas seu build exige macOS e Xcode.

## Estrutura e documentação

- [Arquitetura mobile e decisões iniciais](docs/arquitetura-mobile.md)
- [Tecnologias e proposta N1](docs/tecnologias.md)
- [Identidade visual e arquivos SVG](assets/brand/README.md)
- [Apresentação visual N1](docs/n1/RotaSaude_N1_apresentacao_visual_final.pdf)
- [Projeto N1: etapas e requisitos](docs/n1/RotaSaude_N1_Etapas_1_a_6.md)

## Verificações

```bash
dart format --output=none --set-exit-if-changed lib
flutter analyze
flutter test
```

A tela inicial pede localização somente após o toque em **Usar minha localização**. Com a permissão e o serviço do aparelho disponíveis, o app abre a exploração de unidades em mapa, lista e comparação. A escolha manual altera a área consultada sem substituir a permissão obrigatória do aparelho. As unidades vêm da API, filtradas pela cidade (Goiânia e Aparecida de Goiânia são as áreas sugeridas). Dados marcados como demonstrativos pela API (`is_demo`) exibem aviso de ilustração. Esperas e disponibilidade só aparecem como atuais quando a leitura é recente; caso contrário, o app indica **dados desatualizados** ou **dados operacionais indisponíveis**. As distâncias em mapa, lista, comparação e detalhes são **aproximadas em linha reta** (calculadas no aparelho). O **percurso de carro** é obtido via `GET /api/v1/routes/` (OSRM no backend) na tela de rota.
