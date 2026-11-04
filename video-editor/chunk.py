"""Agrupa palavras (com timestamps) em blocos de legenda de 2-4 palavras.
Uso: python3 chunk.py words.json captions.json
Edite o captions.json gerado para corrigir erros de transcrição antes de renderizar.
"""
import sys, json
words = json.load(open(sys.argv[1]))["words"]
MAX_WORDS, MAX_CHARS, GAP = 4, 22, 0.6
chunks, cur = [], []
def flush():
    global cur
    if cur:
        chunks.append({"words": [{"w": w["w"], "s": w["s"], "e": w["e"]} for w in cur]})
        cur = []
for i, w in enumerate(words):
    if cur:
        chars = sum(len(x["w"]) + 1 for x in cur) + len(w["w"])
        gap = w["s"] - cur[-1]["e"]
        ends = cur[-1]["w"][-1:] in ".,!?:;"
        if len(cur) >= MAX_WORDS or chars > MAX_CHARS or gap > GAP or ends:
            flush()
    cur.append(w)
flush()
for i, c in enumerate(chunks):
    c["s"] = c["words"][0]["s"]
    last = c["words"][-1]["e"]
    nxt = chunks[i + 1]["words"][0]["s"] if i + 1 < len(chunks) else None
    c["e"] = nxt if (nxt is not None and nxt - last < 1.0) else round(last + 0.4, 3)
json.dump(chunks, open(sys.argv[2], "w"), ensure_ascii=False, indent=1)
print(len(chunks), "blocos")
