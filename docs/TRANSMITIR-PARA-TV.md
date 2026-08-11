# Transmitir para a TV

O Sabuflix não vira um aplicativo de TV: ele manda o vídeo para a televisão que
já está na sua rede. Quem baixa e reproduz é a própria TV — o celular só serve
de controle remoto, pode ser bloqueado, e a qualidade é a que a TV aguenta, sem
recodificar nada no meio do caminho.

Toque no ícone **⧉ (Transmitir)** no canto superior do player.

## O que funciona

| Aparelho | Protocolo | Observação |
|---|---|---|
| Chromecast, Google TV, TVs com Chromecast integrado (Sony, Philips, TCL…) | Google Cast | Descoberta por mDNS (`_googlecast._tcp`) |
| Samsung (Tizen) | DLNA / UPnP | Ligado de fábrica na maioria dos modelos |
| LG (webOS) | DLNA / UPnP | Idem |
| Sony, Philips, Panasonic, Hisense, AOC, consoles e receivers | DLNA / UPnP | Qualquer aparelho que anuncie um *MediaRenderer* |
| Qualquer TV, via espelhamento do sistema | Miracast / Smart View / Screen Share | Item "Espelhar a tela inteira" na mesma lista |

As duas buscas rodam ao mesmo tempo, porque os mundos não se sobrepõem: o
Chromecast se anuncia por mDNS e o resto responde a uma busca SSDP. A lista sai
unificada e sem repetição.

## Como usar

1. Comece a assistir normalmente (o player precisa estar aberto).
2. Toque no ícone de transmitir.
3. Escolha a TV na lista.
4. O vídeo abre na TV a partir do ponto em que você estava, e o celular vira
   controle remoto: play/pause, ±10 segundos e progresso.

Saindo do player, a transmissão continua — aparece uma barra
**"Reproduzindo em <TV>"** acima do menu, de onde dá para pausar, parar ou
voltar ao controle completo. Ao parar, a reprodução volta para o aparelho no
ponto em que a TV estava.

## Espelhar a tela inteira

Espelhamento de tela é um serviço do sistema operacional — nenhum aplicativo
consegue iniciar por conta própria. Por isso o item **"Espelhar a tela inteira"**
abre o painel do próprio Android (Smart View na Samsung, Screen Share na LG,
Transmitir no Android puro).

Prefira a transmissão sempre que der: o espelhamento manda a tela inteira
recomprimida pelo Wi-Fi, gasta bateria, mostra as notificações que chegarem e
tem atraso perceptível.

## Quando a TV não aparece

- **Mesma rede.** Celular e TV precisam estar no mesmo Wi-Fi. Rede de visitantes
  e o isolamento entre 2,4 GHz e 5 GHz de alguns roteadores bloqueiam a
  descoberta.
- **TV ligada de verdade**, não em espera — muitos modelos só respondem à busca
  com a tela ligada.
- **Toque em "procurar de novo"**: SSDP e mDNS são pacotes UDP, que se perdem
  com facilidade no Wi-Fi; a busca é repetida três vezes, mas às vezes a TV
  responde só na segunda tentativa.
- **VPN ligada no celular** costuma impedir o tráfego multicast da rede local.

## Limitações conhecidas

- **Vídeos baixados não são transmitidos.** O arquivo fica no armazenamento
  privado do aplicativo, endereço que a TV não tem como acessar. Abra uma fonte
  online para enviar à TV.
- **Legendas e faixas de áudio alternativas** são escolhidas pela própria TV,
  não pelo aplicativo — o que vai para ela é o vídeo, e cada aparelho lida com
  as faixas do seu jeito.
- **Fontes HTTP puro** funcionam; algumas TVs recusam certificados HTTPS
  irregulares da fonte, e nesse caso o vídeo não abre lá mesmo abrindo aqui.

## Onde está o código

| Arquivo | O que faz |
|---|---|
| `lib/services/cast/dlna_client.dart` | Busca SSDP, leitura da descrição do aparelho e comandos AVTransport |
| `lib/services/cast/chromecast_client.dart` | Descoberta mDNS e protocolo Google Cast v2 |
| `lib/services/cast/cast_channel.dart` | Quadros protobuf do Cast (codificação manual, sem gerador) |
| `lib/services/cast/cast_service.dart` | Junta as duas buscas numa lista só |
| `lib/providers/cast_provider.dart` | Estado da transmissão e comandos |
| `lib/widgets/cast_sheet.dart` | Lista de aparelhos + espelhamento do sistema |
| `lib/widgets/casting_panel.dart`, `lib/widgets/cast_bar.dart` | Controle remoto e barra persistente |
| `lib/services/screen_mirror.dart` | Painel de espelhamento do sistema e trava de multicast |

Os protocolos têm testes em `test/cast_test.dart` (quadros, envelopes SOAP,
metadados DIDL, formatos de tempo e leitura das respostas dos aparelhos).
