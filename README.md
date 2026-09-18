# Sabuflix

Cliente oficial e multiplataforma do Sabuflix, construído em Flutter. O app reúne descoberta de filmes e séries, perfis locais (com PIN e modo infantil), progresso de reprodução por episódio, Minha Lista, playlists, histórico, downloads e transmissão para a TV.

## Recursos

- **Início** com carrossel de destaques, Top 10, prateleiras por gênero, "Porque você assistiu", produções brasileiras, em cartaz, em breve e filtro Início / Filmes / Séries.
- **Detalhes** com logo do título, sinopse, criadores e direção, elenco, onde assistir oficialmente no Brasil (JustWatch via TMDB), coleção, recomendados e semelhantes. Séries têm lista de episódios com progresso, marcação de assistidos e "continuar do próximo episódio".
- **Player** com próximo episódio automático, seletor de episódios, áudio e legendas (legendas externas OpenSubtitles com seleção automática por idioma), velocidade, ajuste de tela, tamanho de legenda, timer para dormir, bloqueio de controles, gestos de toque duplo e volume, atalhos de teclado e de controle remoto, Picture-in-Picture e botão de transmissão.
- **Transmitir para a TV** sem SDKs nativos: descoberta SSDP + controle UPnP AVTransport para TVs com DLNA (Samsung, LG, Sony, Philips, TCL, Hisense e outras) e descoberta mDNS + protocolo Cast v2 para Chromecast, Google TV e Android TV. Inclui controle remoto, mini-barra durante a transmissão, TVs salvas e adição manual por IP. O progresso na TV alimenta "Continuar assistindo".
- **Fontes** consultadas em paralelo e classificadas pela qualidade e áudio preferidos, com reprodução rápida opcional.
- **Busca** por título, gênero, tipo, ordenação e ano, com rolagem infinita.
- **Ajustes** de reprodução, aparência, catálogo, downloads, backup e restauração de dados do perfil.
- **Android TV / Google TV**: aparece no launcher (leanback) e navega por controle remoto.

## Desenvolvimento

Requisitos:

- Flutter 3.44.8 (mesma versão da CI), com suporte ao alvo desejado
- Dart 3.12.2 (incluído no Flutter)

```bash
flutter pub get
flutter run -d chrome
```

Para gerar a versão web de produção:

```bash
flutter build web --release
```

Os arquivos prontos para publicação ficam em `build/web`.

## Serviços

Os metadados usam a API gratuita do [The Movie Database (TMDB)](https://www.themoviedb.org/). Uma chave pode ser fornecida no build sem alterar o código:

```bash
flutter build web --release --dart-define=TMDB_API_KEY=sua_chave
```

O Sabuflix é um cliente de mídia e não hospeda nem distribui conteúdo. Use somente fontes e mídias que você tem autorização para acessar.

### Transmissão para a TV

A TV precisa estar na mesma rede Wi-Fi. No Android, o app pede `CHANGE_WIFI_MULTICAST_STATE` para receber as respostas de descoberta; no iOS e macOS, o acesso à rede local é declarado no `Info.plist`/entitlements. A versão web não descobre TVs (navegadores não expõem sockets), então use o botão de transmissão do próprio Chrome ou um dos apps nativos. Em `lib/services/cast/` estão os protocolos; os testes em `test/services/cast/` cobrem o codec Cast, SSDP, DLNA e mDNS sem rede.

## Validação e publicação

`flutter analyze` e `flutter test` verificam código, persistência, downloads, casting, resolução de fontes e layouts. A CI também compila a versão web; releases ficam como rascunho até os builds Windows e Android terminarem.

Android release exige assinatura própria, sem fallback para debug. Configure `android/key.properties` (ignorado pelo Git) com `storeFile`, `storePassword`, `keyAlias` e `keyPassword`, conforme a [documentação Flutter](https://docs.flutter.dev/deployment/android#sign-the-app). Na CI, configure os secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS` e `ANDROID_KEY_PASSWORD`. Preserve a chave existente para permitir atualizações dos aplicativos já distribuídos.

Antes da distribuição, valide em aparelhos reais: reprodução de uma fonte autorizada, áudio/legendas, próximo episódio, busca, troca de perfis (inclusive com PIN), retomada, transmissão para uma TV DLNA e para um Chromecast, download interrompido e modo offline. Downloads locais são oferecidos no Android e Windows; a versão web informa essa disponibilidade. CORS, formatos e disponibilidade de vídeo dependem da fonte.

`TMDB_API_KEY` e `PENGUPLAY_MANIFEST_URL` são configurações de build. Valores de `dart-define` ficam no cliente distribuído: não use credenciais de servidor confidenciais. A fonte Manrope é distribuída localmente com licença em `assets/fonts/OFL.txt`. A versão exibida no app vem de `lib/app_info.dart`; mantenha `pubspec.yaml` e `windows/installer.iss` alinhados.
