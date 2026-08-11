# Sabuflix na TV

O aplicativo agora tem duas interfaces no mesmo código: a de toque (celular,
tablet, desktop) e a de **10 pés**, feita para ser usada de longe, com controle
remoto. A troca é automática — quem decide é o `TvPlatform`, que pergunta ao
sistema o que ele é.

| Plataforma | Como roda | Formato | Estado |
|---|---|---|---|
| **Google — Android TV / Google TV** | Aplicativo nativo Flutter | `.apk` | Suporte completo, inclusive downloads |
| **Samsung — Tizen** | Aplicativo web empacotado | `.wgt` | Streaming completo (sem downloads) |
| **LG — webOS** | Aplicativo web empacotado | `.ipk` | Streaming completo (sem downloads) |
| Amazon Fire TV | Aplicativo nativo (mesmo APK) | `.apk` | Funciona como Android TV |
| Outras TVs (Hisense/Vidaa, Philips, Foxxum, Zeasn, HbbTV) | Navegador da TV | URL hospedada | Funciona; detecção por *user agent* |
| Chromecast, set-top boxes Android | Mesmo APK | `.apk` | Funciona |

Versões mínimas testadas de fábrica pelo motor do Flutter (CanvasKit precisa de
WebAssembly): **Tizen 5.5+ (TVs de 2019 em diante)** e **webOS 5+ (2020 em
diante)**. Em Tizen 5.0 e webOS 4 costuma funcionar, mas mais devagar.

---

## Como a TV é reconhecida

1. **Android TV / Google TV** — o app pergunta ao Android pelo canal
   `sabuflix/tv`: `UiModeManager` em modo televisão, ou os recursos de sistema
   `leanback`. É a mesma checagem que as bibliotecas leanback do Google fazem.
2. **Tizen e webOS** — o app procura o objeto que a própria TV injeta na
   página (`window.tizen`, `window.webOS`) e, se não achar, olha o *user agent*.
3. **Qualquer outra TV** — lista de marcadores de *user agent*
   (`smart-tv`, `hbbtv`, `vidaa`, `crkey`, `bravia`, …).

Nada disso é infalível, então existe a saída manual: **Ajustes → Interface →
Sempre TV**. A escolha fica salva no aparelho. Também dá para fixar no momento
da compilação:

```bash
flutter build apk --release --dart-define=SABUFLIX_TV=on    # sempre TV
flutter build apk --release --dart-define=SABUFLIX_TV=off   # nunca TV
```

---

## Controle remoto

| Botão | O que faz |
|---|---|
| Direcionais | Navegam entre capas, prateleiras e o menu lateral |
| OK / Enter | Abre o título em foco; durante o vídeo, mostra os controles e pausa |
| Voltar | Sai da tela; no menu lateral da tela inicial, pede confirmação para sair do app |
| Play / Pause | Controla a reprodução de qualquer lugar do player |
| Avançar / Retroceder | Pulam 30 segundos |
| ← / → durante o vídeo | Pulam 10 segundos (com os controles escondidos) |

Nas TVs Samsung e LG esses botões chegam como códigos proprietários
(Tizen `10009` = Return, webOS `461` = Back, `415`/`19`/`413`… para o
transporte). O `web/index.html` traduz todos para eventos de teclado padrão
antes de o Flutter vê-los — é por isso que o mesmo código Dart atende os três
ecossistemas.

---

## Compilando

### Android TV / Google TV

```bash
flutter build apk --release --no-tree-shake-icons
```

O `AndroidManifest.xml` já declara o que a Play Store exige de um app de TV:
`LEANBACK_LAUNCHER` (para aparecer na tela inicial da TV), `leanback` como
recurso opcional e — o detalhe que mais derruba app de TV — `touchscreen` como
**não obrigatório**. O banner da gaveta de apps está em
`android/app/src/main/res/drawable-xhdpi/tv_banner.png`.

Instalando numa TV pela rede:

```bash
adb connect 192.168.0.10:5555
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Samsung Tizen e LG webOS

```bash
./tools/build_tv.sh
```

O script compila o Flutter web com `--no-web-resources-cdn` (sem isso o motor
tenta baixar o CanvasKit do `gstatic.com` na hora de abrir, o que um aplicativo
empacotado carregado de `file://` não consegue fazer — a TV fica na tela preta),
ajusta o `<base href>` para carregamento local e monta as duas pastas de
aplicativo em `dist/`:

- `dist/sabuflix-tizen-webapp.zip` — árvore pronta para o Tizen Studio
- `dist/sabuflix-webos-app.zip` — árvore pronta para o `ares-package`
- `dist/com.sabuflix.app_1.0.0_all.ipk` — instalador de webOS, quando o
  `ares-cli` está instalado (`npm install -g @webos-tools/cli`)

#### Empacotar e instalar no webOS

```bash
npm install -g @webos-tools/cli
ares-package dist/webos -o dist
ares-setup-device                        # cadastre a TV (modo desenvolvedor ligado)
ares-install dist/com.sabuflix.app_1.0.0_all.ipk -d minhaTV
ares-launch com.sabuflix.app -d minhaTV
```

O modo desenvolvedor se liga pelo app **Developer Mode**, baixado na loja da
própria LG.

#### Empacotar e instalar no Tizen

O empacotador da Samsung exige um certificado, então essa parte é feita com o
Tizen Studio instalado:

```bash
tizen certificate -a Sabuflix -f sabuflix -p SUA_SENHA      # uma vez
tizen security-profiles add -n sabuflix -a ~/SamsungCertificate/sabuflix/author.p12 -p SUA_SENHA
unzip dist/sabuflix-tizen-webapp.zip -d /tmp/sabuflix-tizen
tizen build-web -- /tmp/sabuflix-tizen
tizen package -t wgt -s sabuflix -- /tmp/sabuflix-tizen/.buildResult
tizen install -n Sabuflix.wgt -t UE65TU8000 -- /tmp/sabuflix-tizen/.buildResult
```

Na TV, o modo desenvolvedor fica em **Apps → 12345 → Developer mode**, onde
também se informa o IP do computador.

### Qualquer outra TV (navegador)

```bash
flutter build web --release
```

Suba `build/web` em qualquer servidor HTTPS e abra o endereço no navegador da
TV. A interface de 10 pés liga sozinha nas TVs reconhecidas; nas demais, use
**Ajustes → Sempre TV**.

---

## O que muda na interface de TV

- Menu lateral focável no lugar da dock flutuante, que se expande quando recebe
  o foco.
- Margem de *overscan* (4% na horizontal, 4,5% na vertical) em todas as telas,
  porque a TV corta as bordas da imagem.
- Capas, títulos e textos maiores, derivados do tamanho real da tela.
- Todo elemento clicável vira um alvo de foco com anel branco e ampliação —
  visível do sofá, não um realce sutil.
- A prateleira rola sozinha para manter em vista o item focado.
- Os menus que eram folhas deslizantes viram painéis centralizados; o seletor
  de temporada, que era um *dropdown*, vira uma fileira de botões.
- Sem *pull-to-refresh*, sem *overscroll* elástico e sem `BackdropFilter` nas
  listas — o borrão em tempo real é a forma mais rápida de derrubar os quadros
  por segundo de uma TV.
- A tela fica acesa durante a reprodução (Android).

## Limitações conhecidas

- **Downloads não existem em Tizen e webOS.** As duas rodam o app como página
  web, sem acesso a um sistema de arquivos que caiba um filme. A aba some
  sozinha nessas plataformas (`TvPlatform.supportsDownloads`).
- **Streams por HTTP puro** funcionam no Android TV (`usesCleartextTraffic`) e
  nos pacotes de TV carregados de `file://`; num site HTTPS o navegador bloqueia
  conteúdo misto.
- **CORS**: no pacote Tizen o `config.xml` já libera qualquer origem; servindo a
  versão web por HTTPS, as fontes de vídeo precisam responder com CORS ou passar
  por um proxy.
- **A tipografia vem do Google Fonts em tempo de execução** (pacote
  `google_fonts`, família Manrope). Numa TV sem acesso a `fonts.gstatic.com` o
  motor CanvasKit não encontra nenhuma fonte e a interface aparece sem textos —
  só os ícones. Se a rede de destino bloqueia o Google, embuta a fonte no
  aplicativo: baixe o Manrope, coloque os arquivos em `assets/fonts/`, declare a
  família `Manrope` na seção `flutter: fonts:` do `pubspec.yaml` e o
  `google_fonts` passa a usar o arquivo local em vez da rede.
