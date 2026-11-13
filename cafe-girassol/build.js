// Junta os arquivos de src/ em um único HTML.
//   index.html    -> página completa para abrir direto no navegador
//   artifact.html -> mesmo conteúdo sem <html>/<head>/<body>, para publicar como Artifact
const fs = require('fs'), path = require('path');
const src = f => fs.readFileSync(path.join(__dirname, 'src', f), 'utf8');
const JS = ['art-core.js', 'art-chars.js', 'art-scene.js', 'data-game.js', 'data-story.js', 'game-state.js', 'audio.js', 'game-main.js'];
const head = `<title>Café Girassol</title>
<meta name="description" content="Jogo de cafeteria em pixel art: dez fregueses, dez histórias e um café para chamar de seu.">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Pixelify+Sans:wght@400;700&display=swap">
<style>
${src('style.css')}
</style>`;
const body = src('body.html') + '\n<script>\n' + JS.map(src).join('\n') + '\n</script>\n';
fs.writeFileSync(path.join(__dirname, 'index.html'), `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
${head}
</head>
<body>
${body}</body>
</html>
`);
fs.writeFileSync(path.join(__dirname, 'dist', 'artifact.html'), head + '\n' + body);
console.log('ok', (fs.statSync(path.join(__dirname, 'index.html')).size / 1024).toFixed(1) + ' KB');
