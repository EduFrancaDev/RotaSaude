# RotaSaúde

Aplicativo mobile em Flutter e Dart para ajudar o cidadão a consultar unidades públicas de saúde, comparar informações e planejar o deslocamento. O repositório contém a base do aplicativo para Android e iOS. Backend, banco de dados e infraestrutura ficam fora do escopo deste código.

## Executar no Android conectado

É necessário ter o Flutter SDK e o Android SDK configurados. Neste computador, o Flutter está em `~/develop/flutter` e seu `bin` foi adicionado ao `PATH` do Zsh.

```bash
flutter pub get
flutter devices
flutter run -d <ID_DO_DISPOSITIVO>
```

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
```

A tela inicial pede localização somente após o toque em **Usar minha localização**. Com a permissão e o serviço do aparelho disponíveis, o app abre a exploração de unidades em mapa, lista e comparação. A escolha manual altera a área consultada sem substituir a permissão obrigatória do aparelho. Goiânia e Aparecida de Goiânia são áreas demonstrativas: somente Goiânia tem unidades no catálogo local. Nomes com “Exemplo”, disponibilidade, esperas, distâncias e rotas são dados ilustrativos do protótipo, não informações atuais nem navegação em tempo real.
