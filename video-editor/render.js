#!/usr/bin/env node
// Renderiza um projeto (JSON) sobre o vídeo bruto: legendas palavra-a-palavra + motion graphics.
// Uso: node render.js projeto.json [--out saida.mp4] [--fps 30] [--start 0] [--end 10] [--still 4.2] [--workers 3]
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn, execFileSync } = require('child_process');
const { chromium } = require('playwright');

const args = process.argv.slice(2);
const opt = (k, d) => { const i = args.indexOf('--' + k); return i >= 0 ? args[i + 1] : d; };
const projectPath = path.resolve(args[0]);
const projDir = path.dirname(projectPath);
const project = JSON.parse(fs.readFileSync(projectPath, 'utf8'));
const res = p => path.isAbsolute(p) ? p : path.resolve(projDir, p);
const src = res(project.source);
const fps = +opt('fps', 30);
const workers = +opt('workers', 3);
const still = opt('still', null);
const dur = +execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', src]).toString();
const start = +opt('start', 0);
const end = Math.min(+opt('end', dur), dur);
const out = path.resolve(opt('out', path.join(projDir, path.basename(projectPath, '.json') + '.mp4')));

// ---- legendas: usa captions.json se existir, senão agrupa as palavras ----
function chunkWords(words) {
  const MAXW = 4, MAXC = 22, GAP = .6, chunks = []; let cur = [];
  const flush = () => { if (cur.length) { chunks.push({ words: cur.map(w => ({ w: w.w, s: w.s, e: w.e })) }); cur = []; } };
  for (const w of words) {
    if (cur.length) {
      const chars = cur.reduce((a, x) => a + x.w.length + 1, 0) + w.w.length;
      const gap = w.s - cur[cur.length - 1].e, ends = '.,!?:;'.includes(cur[cur.length - 1].w.slice(-1));
      if (cur.length >= MAXW || chars > MAXC || gap > GAP || ends) flush();
    }
    cur.push(w);
  }
  flush();
  chunks.forEach((c, i) => {
    c.s = c.words[0].s; const last = c.words[c.words.length - 1].e;
    const nxt = chunks[i + 1] ? chunks[i + 1].words[0].s : null;
    c.e = nxt !== null && nxt - last < 1 ? nxt : +(last + .4).toFixed(3);
  });
  return chunks;
}
if (!project.captions) {
  const capFile = project.captionsFile ? res(project.captionsFile) : path.join(projDir, path.basename(projectPath, '.json') + '.captions.json');
  if (fs.existsSync(capFile)) project.captions = JSON.parse(fs.readFileSync(capFile, 'utf8'));
  else if (project.words) {
    project.captions = chunkWords(JSON.parse(fs.readFileSync(res(project.words), 'utf8')).words);
    fs.writeFileSync(capFile, JSON.stringify(project.captions, null, 1));
    console.log('legendas geradas em', capFile, '(edite para corrigir a transcrição)');
  } else project.captions = [];
}
// pontuação some das legendas (como na referência)
for (const c of project.captions) for (const w of c.words) w.w = w.w.replace(/[.,!?;:]+$/g, '');
// cena final estende até o fim do vídeo
const scenes = project.scenes;
scenes[scenes.length - 1].e = Math.max(scenes[scenes.length - 1].e, dur + 1);

(async () => {
  const tmp = fs.mkdtempSync(path.join(process.env.SCRATCH || os.tmpdir(), 'vframes-'));
  const n = still !== null ? 1 : Math.round((end - start) * fps);
  console.log(`extraindo ${n} frames (${fps} fps) de ${src}`);
  if (still !== null) {
    execFileSync('ffmpeg', ['-v', 'error', '-ss', String(still), '-i', src, '-frames:v', '1', '-vf', 'scale=1080:1920', '-q:v', '2', path.join(tmp, '00001.jpg')]);
  } else {
    execFileSync('ffmpeg', ['-v', 'error', '-ss', String(start), '-t', String(end - start), '-i', src, '-vf', `fps=${fps},scale=1080:1920`, '-q:v', '2', '-start_number', '1', path.join(tmp, '%05d.jpg')]);
  }
  const browser = await chromium.launch();
  const pages = [];
  for (let i = 0; i < (still !== null ? 1 : workers); i++) {
    const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
    page.on('pageerror', e => console.error('erro na página:', e.message));
    await page.goto('file://' + path.join(__dirname, 'template.html'));
    await page.evaluate(p => window.setProject(p), project);
    pages.push(page);
  }
  const frameAt = i => path.join(tmp, String(i + 1).padStart(5, '0') + '.jpg');

  if (still !== null) {
    await pages[0].evaluate(([t, f]) => window.renderFrame(t, f), [+still, 'file://' + frameAt(0)]);
    const png = out.replace(/\.mp4$/, '') + `_${(+still).toFixed(2)}.png`;
    await pages[0].screenshot({ path: png, type: 'png' });
    console.log('frame salvo em', png);
    await browser.close(); fs.rmSync(tmp, { recursive: true, force: true }); return;
  }

  const ff = spawn('ffmpeg', ['-y', '-v', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-i', 'pipe:0',
    '-ss', String(start), '-t', String(end - start), '-i', src,
    '-map', '0:v', '-map', '1:a?', '-c:v', 'libx264', '-crf', '18', '-preset', 'fast', '-pix_fmt', 'yuv420p', '-r', String(fps),
    '-c:a', 'aac', '-b:a', '160k', '-shortest', out], { stdio: ['pipe', 'inherit', 'inherit'] });

  const buffers = new Map(); let next = 0, done = 0; const t0 = Date.now();
  const write = buf => new Promise(r => ff.stdin.write(buf, r));
  async function flush() { while (buffers.has(next)) { const b = buffers.get(next); buffers.delete(next); await write(b); next++; } }
  let cursor = 0;
  await Promise.all(pages.map(async page => {
    while (cursor < n) {
      const i = cursor++;
      const t = start + i / fps;
      await page.evaluate(([t, f]) => window.renderFrame(t, f), [t, 'file://' + frameAt(i)]);
      buffers.set(i, await page.screenshot({ type: 'jpeg', quality: 93 }));
      done++;
      if (done % 150 === 0) console.log(`${done}/${n} frames  (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
      await flush();
    }
  }));
  await flush();
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  await browser.close();
  fs.rmSync(tmp, { recursive: true, force: true });
  console.log('pronto:', out, `(${((Date.now() - t0) / 1000).toFixed(0)}s)`);
})().catch(e => { console.error(e); process.exit(1); });
