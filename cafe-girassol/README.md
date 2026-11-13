# Café Girassol

Jogo de cafeteria em pixel art, em português. Você reabre o café da sua avó, prepara bebidas com kits de café reais e conhece dez fregueses que voltam todo dia, cada um com uma história que aparece aos poucos.

## Jogar

Abra `index.html` em qualquer navegador (computador ou celular). Não precisa de servidor nem de instalação. O progresso fica salvo no próprio navegador; em Opções dá para gerar um código e levar o jogo para outro aparelho.

## O que tem

- 10 fregueses com histórias de 7 capítulos que se cruzam, um final com sarau e a carta da Vó Cida.
- 11 kits de preparo (coador de pano, leiteira, moka, prensa, espresso, V60, cold brew, AeroPress, Chemex, ibrik, sifão), cada um com seu gesto.
- 34 receitas para descobrir, 8 grãos de regiões brasileiras, quitandas.
- Fachada, nome e interior personalizáveis; presentes dos fregueses viram decoração.
- Ritmo diário sem punição: visitante novo por dia (21 no álbum), pedidos da rua, receita do dia, canteiros de girassol que crescem no tempo real, cartas, estações e festas do calendário brasileiro, marcos por dias de casa aberta (cumulativos, não zeram).

## Código

Tudo é desenhado e tocado em código (canvas 2D e Web Audio), sem imagens nem sons externos.

- `src/` contém os arquivos-fonte; `node build.js` junta tudo em `index.html` (e em `dist/artifact.html`, versão sem `<html>`/`<head>` para publicação).
- `src/data-story.js` tem todas as falas e histórias; `src/data-game.js`, receitas, kits, grãos, decoração e visitantes.
- `pesquisa/` guarda o relatório de design e as notas que embasaram o jogo.
