# Identidade visual do RotaSaúde

## Fontes e método

- **Referência visual:** [JPG colorido](originais/rota-saude-jpg-colorido-fonte-da-verdade.jpeg). Ele define a composição e as cores.
- **Contornos vetoriais:** [SVG preto](originais/rota-saude-vetor-black.svg). Seus caminhos foram alinhados à posição e à escala da marca principal no JPG.
- **Entrega:** 30 arquivos SVG independentes, com fundo transparente, sem imagem incorporada e sem dependência de fontes instaladas. O ícone corresponde ao símbolo principal acima do nome, sem o quadrado claro do exemplo de ícone de aplicativo na parte inferior do JPG.

Os códigos de cor abaixo foram estimados por amostragem de áreas internas do JPG. Como o JPG tem compressão, eles são referências práticas da paleta, não valores originais de um arquivo de design.

## Paleta extraída

| Cor | HEX | Uso na marca |
| --- | --- | --- |
| Azul principal | `#0D74C8` | Símbolo e “Saúde” na versão original |
| Verde água | `#06A8AB` | Cruz e trecho final do símbolo na versão original |
| Azul escuro | `#12466A` | “Rota” |
| Azul escuro do slogan | `#15344F` | Slogan |
| Preto | `#000000` | Versão monocromática |
| Branco | `#FFFFFF` | Versão monocromática para fundo escuro |

A versão **colorida original** mantém o azul no corpo do símbolo, o verde água na cruz e no trecho final, “Rota” em azul escuro e “Saúde” em azul. A versão **colorida com cores secundárias** alterna azul e verde água no símbolo e usa verde água em “Saúde”, sem acrescentar cores à paleta. As versões azul e verde usam uma única cor da paleta em todos os elementos.

## Arquivos SVG

| Composição | Original | Cores secundárias | Preto | Branco | Azul | Verde |
| --- | --- | --- | --- | --- | --- | --- |
| Ícone | [SVG](svg/icone/colorida-original.svg) | [SVG](svg/icone/colorida-cores-secundarias.svg) | [SVG](svg/icone/preto.svg) | [SVG](svg/icone/branco.svg) | [SVG](svg/icone/azul.svg) | [SVG](svg/icone/verde.svg) |
| Logo completa: ícone, nome e slogan | [SVG](svg/logo-completa/colorida-original.svg) | [SVG](svg/logo-completa/colorida-cores-secundarias.svg) | [SVG](svg/logo-completa/preto.svg) | [SVG](svg/logo-completa/branco.svg) | [SVG](svg/logo-completa/azul.svg) | [SVG](svg/logo-completa/verde.svg) |
| Somente nome | [SVG](svg/somente-nome/colorida-original.svg) | [SVG](svg/somente-nome/colorida-cores-secundarias.svg) | [SVG](svg/somente-nome/preto.svg) | [SVG](svg/somente-nome/branco.svg) | [SVG](svg/somente-nome/azul.svg) | [SVG](svg/somente-nome/verde.svg) |
| Ícone e nome, sem slogan | [SVG](svg/icone-nome/colorida-original.svg) | [SVG](svg/icone-nome/colorida-cores-secundarias.svg) | [SVG](svg/icone-nome/preto.svg) | [SVG](svg/icone-nome/branco.svg) | [SVG](svg/icone-nome/azul.svg) | [SVG](svg/icone-nome/verde.svg) |
| Somente slogan | [SVG](svg/somente-slogan/colorida-original.svg) | [SVG](svg/somente-slogan/colorida-cores-secundarias.svg) | [SVG](svg/somente-slogan/preto.svg) | [SVG](svg/somente-slogan/branco.svg) | [SVG](svg/somente-slogan/azul.svg) | [SVG](svg/somente-slogan/verde.svg) |

Para refazer os arquivos a partir do SVG preto, execute `python3 assets/brand/gerar_svg.py` na raiz do projeto. O gerador usa Inkscape para separar os caminhos do ícone.
