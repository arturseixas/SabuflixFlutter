# Sabuflix

Cliente oficial e multiplataforma do Sabuflix, construído em Flutter. O app reúne descoberta de filmes e séries, perfis locais, progresso de reprodução, Minha Lista, playlists, histórico e downloads.

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

## Validação e publicação

`flutter analyze` e `flutter test` verificam código, persistência, downloads e layouts. A CI também compila a versão web; releases ficam como rascunho até os builds Windows e Android terminarem.

Android release exige assinatura própria, sem fallback para debug. Configure `android/key.properties` (ignorado pelo Git) com `storeFile`, `storePassword`, `keyAlias` e `keyPassword`, conforme a [documentação Flutter](https://docs.flutter.dev/deployment/android#sign-the-app). Na CI, configure os secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS` e `ANDROID_KEY_PASSWORD`. Preserve a chave existente para permitir atualizações dos aplicativos já distribuídos.

Antes da distribuição, valide em aparelhos reais: reprodução de uma fonte autorizada, áudio/legendas, busca, troca de perfis, retomada, download interrompido e modo offline. Downloads locais são oferecidos no Android e Windows; a versão web informa essa disponibilidade. CORS, formatos e disponibilidade de vídeo dependem da fonte.

`TMDB_API_KEY` e `PENGUPLAY_MANIFEST_URL` são configurações de build. Valores de `dart-define` ficam no cliente distribuído: não use credenciais de servidor confidenciais. A fonte Manrope é distribuída localmente com licença em `assets/fonts/OFL.txt`.
