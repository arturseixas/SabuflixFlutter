# Sabuflix

Cliente oficial e multiplataforma do Sabuflix, construído em Flutter. O app reúne descoberta de filmes e séries, perfis locais, progresso de reprodução, Minha Lista, playlists, histórico e downloads.

## Desenvolvimento

Requisitos:

- Flutter estável com suporte a Web
- Dart 3

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
