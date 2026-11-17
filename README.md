# RotaSaúde

O RotaSaúde ajuda o cidadão a consultar unidades públicas de saúde, comparar informações e planejar o deslocamento. Este monorepo reúne o aplicativo Flutter para Android e iOS e a API Django com PostgreSQL.

- [`mobile/`](mobile/) contém o projeto Flutter, os projetos Android e iOS, os assets e os testes.
- [`backend/`](backend/) contém a API, as migrações, os testes e o Docker Compose.
- [`docs/`](docs/) guarda a documentação do projeto e [`openspec/`](openspec/) guarda as especificações.

## Subir a API local

A partir da raiz do repositório, em um terminal com Docker Compose disponível:

```bash
cd backend
[ -f .env ] || cp .env.example .env
docker compose up -d --build
```

A configuração padrão publica a API localmente em `http://127.0.0.1:8000`. Quando `/api/v1/health/` responder, cadastre as unidades de demonstração:

```bash
docker compose exec api python manage.py seed_demo_units
```

Confira os endpoints e as opções de configuração no [README do backend](backend/README.md).

## Executar no Android conectado

Com o Flutter SDK e o Android SDK configurados, execute em outro terminal a partir da raiz do repositório:

```bash
cd mobile
flutter pub get
flutter devices
adb -s <ID_DO_DISPOSITIVO> reverse tcp:8000 tcp:8000
flutter run -d <ID_DO_DISPOSITIVO>
```

### Conectar ao backend Django

Dentro de `mobile/`, passe a URL base da API no momento da compilação:

```bash
flutter run -d <ID_DO_DISPOSITIVO> --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Sem `--dart-define`, o app usa `http://127.0.0.1:8000`. Com a API no ar, escolha a configuração de acordo com o dispositivo:

- **Android físico via USB ou emulador com ADB**: execute `adb reverse tcp:8000 tcp:8000` e use `127.0.0.1:8000`.
- **Emulador Android sem `adb reverse`**: `--dart-define=API_BASE_URL=http://10.0.2.2:8000` e inclua `10.0.2.2` em `DJANGO_ALLOWED_HOSTS` no `.env` do backend.
- **Aparelho na mesma rede**: `--dart-define=API_BASE_URL=http://<IP_DO_PC>:8000`, `API_BIND=0.0.0.0` e o IP em `DJANGO_ALLOWED_HOSTS`.

Builds de debug aceitam HTTP; release exige HTTPS. Leituras operacionais com mais de 30 minutos são tratadas como desatualizadas; para alterar a janela, use `--dart-define=OPERATIONAL_MAX_AGE_MINUTES=<minutos>`.

Durante o `flutter run`, pressione `r` para Hot Reload, `R` para Hot Restart e `q` para encerrar. O identificador do aplicativo é `com.edufrancadev.rotasaude`. O projeto iOS foi gerado, mas seu build exige macOS e Xcode.

## Estrutura e documentação

- [Arquitetura mobile e decisões iniciais](docs/arquitetura-mobile.md)
- [Backend MVP: execução, endpoints e testes](backend/README.md)
- [Tecnologias e proposta N1](docs/tecnologias.md)
- [Identidade visual e arquivos SVG](mobile/assets/brand/README.md)
- [Apresentação visual N1](docs/n1/RotaSaude_N1_apresentacao_visual_final.pdf)
- [Projeto N1: etapas e requisitos](docs/n1/RotaSaude_N1_Etapas_1_a_6.md)

## Verificações do mobile

Execute os comandos em `mobile/`.

```bash
dart format --output=none --set-exit-if-changed lib
flutter analyze
flutter test
```

A tela inicial pede localização somente após o toque em **Usar minha localização**. **Escolher cidade** abre a Lista sem GPS. A cidade define as unidades consultadas. A origem de distâncias e rotas pode ser definida mais tarde com o GPS ou um ponto no mapa. As unidades vêm da API, filtradas pela cidade (Goiânia e Aparecida de Goiânia são as áreas sugeridas). Dados marcados como demonstrativos pela API (`is_demo`) exibem aviso de ilustração. Esperas e disponibilidade só aparecem como atuais quando a leitura é recente; caso contrário, o app indica **dados desatualizados** ou **dados operacionais indisponíveis**. As distâncias em mapa, lista, comparação e detalhes são **aproximadas em linha reta** (calculadas no aparelho). O **percurso de carro** é obtido via `GET /api/v1/routes/` (OSRM no backend) na tela de rota.
