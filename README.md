# Sabuflix

Catálogo de filmes e séries em Flutter, com perfis, listas, downloads offline e
player próprio — rodando em celular, desktop e **televisão**.

## Plataformas

| | Como instalar |
|---|---|
| **Android TV / Google TV** | `flutter build apk --release --no-tree-shake-icons` |
| **Samsung (Tizen)** | `./tools/build_tv.sh` → `dist/sabuflix-tizen-webapp.zip` |
| **LG (webOS)** | `./tools/build_tv.sh` → `dist/*.ipk` |
| Android e iOS | `flutter build apk` / `flutter build ipa` |
| Windows, macOS e Linux | `flutter build windows` / `macos` / `linux` |
| Navegador (inclusive TVs Hisense, Philips, Foxxum, Zeasn) | `flutter build web --release` |

A interface muda sozinha conforme o aparelho: dock flutuante e alvos de toque no
celular, menu lateral e navegação por controle remoto na TV. Os detalhes de
build, instalação, teclas do controle e limitações de cada plataforma estão em
**[docs/TV.md](docs/TV.md)**.

## Rodando localmente

```bash
flutter pub get
flutter run
```

Para testar a interface de TV em qualquer máquina:

```bash
flutter run --dart-define=SABUFLIX_TV=on
```

(ou, dentro do app, **Ajustes → Interface → Sempre TV**)
