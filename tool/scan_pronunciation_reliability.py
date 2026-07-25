"""Per-word reliability across the whole vocabulary.

For every word we hold native audio for in BOTH voices:
  match  = how closely the model's transcript of the female clip matches the
           expected spelling  (can it hear this word at all?)
  noise  = disagreement between the two native voices
           (how often it will contradict itself on correct speech)
A word is only safe to score if both are low.
"""
import argparse, json, glob, os, sys, subprocess, tempfile
import numpy as np, onnxruntime as ort, wave
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from audio_utterances import key_for

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_ap = argparse.ArgumentParser(description=__doc__)
_ap.add_argument('--models', required=True,
                 help='directory holding model_int8.onnx and vocab.json')
_ap.add_argument('--out', default=os.path.join(ROOT, 'assets', 'curriculum',
                                               'pronunciation_reliable_words.json'))
_ap.add_argument('--max-error', type=float, default=0.20)
_args = _ap.parse_args()
W = _args.models

def per(ref,hyp):
    if not ref: return 0.0 if not hyp else 1.0
    prev=list(range(len(hyp)+1))
    for i,r in enumerate(ref,1):
        cur=[i]
        for j,h in enumerate(hyp,1): cur.append(min(prev[j]+1,cur[j-1]+1,prev[j-1]+(r!=h)))
        prev=cur
    return prev[len(hyp)]/len(ref)

vocab=json.load(open(f'{W}/vocab.json')); inv={v:k for k,v in vocab.items()}
PAD=vocab.get('<pad>',0)
def decode(ids):
    out,prev=[],-1
    for i in ids:
        i=int(i)
        if i!=prev and i!=PAD:
            t=inv.get(i,'')
            if t not in ('<s>','</s>','<unk>','<pad>'): out.append(' ' if t=='|' else t)
        prev=i
    return ''.join(out).strip()

so=ort.SessionOptions(); so.log_severity_level=3
s=ort.InferenceSession(f'{W}/model_int8.onnx',so,providers=['CPUExecutionProvider'])
inp=s.get_inputs()[0].name

def wav_from_mp3(mp3, tmp):
    subprocess.run(['ffmpeg','-y','-i',mp3,'-ar','16000','-ac','1',tmp],capture_output=True)
    if not os.path.exists(tmp) or os.path.getsize(tmp)==0: return None
    with wave.open(tmp,'rb') as w:
        a=np.frombuffer(w.readframes(w.getnframes()),dtype=np.int16).astype(np.float32)/32768.0
    if a.size==0: return None
    return (a-a.mean())/(a.std()+1e-7)

words={}
for p in glob.glob(f'{ROOT}/assets/vocabulary/*.json'):
    for r in json.loads(open(p).read()):
        w=(r.get('word_cz') or '').strip()
        if w: words[w]=r.get('ipa','')
words=sorted(words)
print(f"scanning {len(words)} vocabulary words...", flush=True)

rows=[]
tmpf=tempfile.mktemp(suffix='.wav'); tmpm=tempfile.mktemp(suffix='.wav')
for n,w in enumerate(words,1):
    k=key_for(w)
    fm=f'{ROOT}/assets/audio/female_{k}.mp3'; mm=f'{ROOT}/assets/audio/male_{k}.mp3'
    if not (os.path.exists(fm) and os.path.exists(mm)): continue
    af=wav_from_mp3(fm,tmpf); am=wav_from_mp3(mm,tmpm)
    if af is None or am is None: continue
    tf=decode(s.run(None,{inp:af[None,:].astype(np.float32)})[0].argmax(-1)[0])
    tm=decode(s.run(None,{inp:am[None,:].astype(np.float32)})[0].argmax(-1)[0])
    rows.append({'word':w,'f':tf,'m':tm,
                 'match':per(list(w.lower()),list(tf.lower())),
                 'noise':per(list(tf.lower()),list(tm.lower()))})
    if n%150==0: print(f"  {n}/{len(words)} ...", flush=True)

safe = sorted(r['word'] for r in rows
              if r['match'] <= _args.max_error and r['noise'] <= _args.max_error)
json.dump({'generated_from': 'arampacha/wav2vec2-large-xlsr-czech (int8)',
           'max_error': _args.max_error,
           'measured': len(rows), 'reliable': len(safe), 'words': safe},
          open(_args.out, 'w'), ensure_ascii=False, indent=1)
print(f"\nmeasured {len(rows)} words; {len(safe)} reliable "
      f"({100*len(safe)/max(1,len(rows)):.0f}%) -> {_args.out}")
