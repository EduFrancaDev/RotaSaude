# Arquitetura inicial do aplicativo

## Escopo

Este repositório implementa somente o aplicativo Flutter/Dart. Sistemas das unidades, API, banco de dados e cálculo do indicador pertencem a integrações externas. O app poderá consumir uma API no futuro, mas não implementa o backend.

O projeto foi criado com Flutter 3.47.5 e Dart 3.13.4 para **Android e iOS**. O identificador de pacote é `com.edufrancadev.rotasaude`. No Linux, é possível desenvolver e executar a versão Android; o build iOS depende de macOS e Xcode.

## Código atual

```text
lib/
├── main.dart                 entrada do processo e runApp
├── app.dart                  MaterialApp e configuração principal
├── screens/
│   ├── home_screen.dart      apresentação inicial e símbolo pulsante
│   └── location_screen.dart  escolha manual de cidade
└── theme/
    ├── app_colors.dart       cores da marca
    └── app_theme.dart        tema Material 3
```

`main.dart` equivale ao ponto de entrada da aplicação. `RotaSaudeApp` é o widget raiz, semelhante ao componente raiz de um app React Native. `HomeScreen` é uma tela composta por widgets Flutter. O `ThemeData` centraliza cores e estilos compartilhados, em vez de espalhar valores por todas as telas.

A tela inicial segue o esboço de apresentação: símbolo circular, mensagem e botão **Começar**. O halo pulsa com `AnimationController` do Flutter e fica estático quando o sistema solicita redução de movimento. A composição usa `SafeArea` e rolagem para caber em telas menores e com fonte ampliada. O botão abre `LocationScreen`, onde a cidade pode ser informada manualmente. Essa escolha fica apenas na memória da tela; a consulta às unidades ainda não foi integrada, e a interface informa essa limitação sem inventar dados de saúde. Não há serviço, repositório ou pacote adicional para esse fluxo.

## Identidade visual

As cores usadas em `AppColors` seguem o [JPG de referência da marca](../assets/brand/originais/rota-saude-jpg-colorido-fonte-da-verdade.jpeg): azul `#0D74C8`, verde água `#06A8AB` e azul escuro `#12466A`. Os valores são aproximações obtidas de um JPG comprimido. Os [SVGs da marca](../assets/brand/README.md) estão preservados como arquivos vetoriais. A base não adiciona um package apenas para renderizar SVG na tela inicial.

## Evolução prevista

1. Criar telas e widgets conforme os fluxos forem definidos, começando por localização manual e listagem de unidades.
2. Adicionar modelos Dart quando existir um formato de dados acordado para unidade, disponibilidade e serviços.
3. Adicionar serviços e repositórios somente quando houver uma fonte de dados real ou demonstrativa que precise ser isolada da interface.
4. Usar `StatefulWidget` e `setState` para estado local simples. Avaliar outra solução apenas quando o fluxo mostrar uma necessidade concreta.
5. Adicionar packages de localização, mapas, HTTP ou rotas quando a respectiva funcionalidade entrar em implementação.

## Desenvolvimento no celular

Com o dispositivo Android autorizado na depuração USB:

```bash
flutter doctor
flutter devices
flutter run -d <ID_DO_DISPOSITIVO>
```

No terminal do `flutter run`, `r` aplica Hot Reload, `R` reinicia o estado com Hot Restart e `q` encerra. Use `flutter analyze` após alterações de código. O `flutter doctor` pode apontar ferramentas de desktop Linux ausentes; elas não são necessárias para executar o app no Android.

## Organização dos materiais

- `docs/n1/`: apresentação e requisitos acadêmicos da N1.
- `assets/brand/originais/`: JPG de referência e SVG preto de origem.
- `assets/brand/svg/`: versões vetoriais da marca.
- `assets/brand/gerar_svg.py`: gerador reproduzível das versões SVG a partir do vetor original.

O `pubspec.lock` é mantido no repositório para fixar as dependências resolvidas do aplicativo. Artefatos de build, caches e arquivos locais do Android/iOS são ignorados pelo Git.
