import sys, json, subprocess
import numpy as np
from faster_whisper import WhisperModel
src, out = sys.argv[1], sys.argv[2]
size = sys.argv[3] if len(sys.argv) > 3 else "small"
raw = subprocess.run(["ffmpeg","-v","error","-i",src,"-vn","-ac","1","-ar","16000","-f","f32le","-"],capture_output=True,check=True).stdout
audio = np.frombuffer(raw, dtype=np.float32)
m = WhisperModel(size, device="cpu", compute_type="int8")
segs, info = m.transcribe(audio, language="pt", word_timestamps=True, vad_filter=True, beam_size=5)
words = []
for s in segs:
    for w in s.words:
        words.append({"w": w.word.strip(), "s": round(w.start, 3), "e": round(w.end, 3)})
json.dump({"duration": len(audio)/16000, "words": words}, open(out, "w"), ensure_ascii=False, indent=1)
print(len(words), "words;", " ".join(x["w"] for x in words))
