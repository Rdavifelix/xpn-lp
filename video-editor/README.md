# video-editor — legendas + motion graphics no padrão da referência

Pipeline para editar vídeos verticais (1080×1920) com legendas palavra-a-palavra e
motion graphics (cards, notificações, mapa, números, CTA), reproduzindo o estilo dos
vídeos de referência. Veja `GUIA-DE-ESTILO.md` para a análise do padrão.

## Requisitos

- Node 22 + Playwright (Chromium) — `require('playwright')`
- ffmpeg / ffprobe
- Python 3 + `faster-whisper` (`pip install faster-whisper`) para a transcrição

## Fluxo

```bash
# 1. transcrição com tempo por palavra (modelo medium para melhor qualidade em PT-BR)
python3 transcribe.py bruto.mp4 projects/meu-video.words.json medium

# 2. (opcional) gera o arquivo de legendas para corrigir erros de transcrição
python3 chunk.py projects/meu-video.words.json projects/meu-video.captions.json

# 3. escreve o roteiro de cenas em projects/meu-video.json (veja projects/demo-ref02.json)

# 4. conferir um frame
node render.js projects/meu-video.json --still 12.5

# 5. renderizar (preview rápido a 10 fps, ou final a 30 fps)
node render.js projects/meu-video.json --fps 10 --out preview.mp4
node render.js projects/meu-video.json --out final.mp4
```

Opções do `render.js`: `--start`/`--end` (trecho em segundos), `--fps`, `--workers` (páginas em paralelo), `--still t` (salva um PNG).

## Formato do projeto (`projects/*.json`)

```jsonc
{
  "source": "bruto.mp4",             // vídeo bruto (qualquer resolução 9:16)
  "words": "x.words.json",           // saída do transcribe.py
  "focus": "50% 28%",                // ponto do rosto usado no recorte da moldura/círculo
  "keywords": ["Google", "top", "3"],// palavras que ficam azuis na legenda
  "scenes": [
    { "s": 0, "e": 3.3, "layout": "full", "components": [ { "type": "chip", "text": "Home Service nos EUA", "t": 0.8 } ] },
    { "s": 3.3, "e": 8.4, "layout": "card", "component": { "type": "ranking", "...": "..." } }
  ]
}
```

- `layout`: `full` (vídeo cheio), `card` (fundo claro + card em cima + vídeo em moldura), `circle` (card de mapa + avatar redondo), `stat` (sem vídeo).
- Tempos `t` dentro dos componentes são relativos ao início da cena.
- Componentes: `chip`, `ranking`, `list`, `notifications`, `map` (itens `zone`, `pin`, `tag`, `banner`, `dots`, `pulse`), `profile`, `phone`, `serp`, `donut`, `agenda`, `bars`, `logos`, `stat`, `cta`, `title`. Os parâmetros de cada um estão em `template.html` (função `C.<tipo>`).
- Legendas: se `projects/<nome>.captions.json` existir ele é usado (edite para corrigir a transcrição); senão é gerado automaticamente a partir de `words`. Para forçar/impedir destaque em uma palavra, adicione `"k": true/false` nela.
