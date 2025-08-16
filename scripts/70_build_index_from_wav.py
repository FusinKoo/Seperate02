#!/usr/bin/env python
import argparse, os, sys


def check_deps():
    missing = []
    for m in ["transformers", "librosa", "soundfile", "faiss"]:
        try:
            __import__(m)
        except Exception:
            missing.append(m)
    if missing:
        pip = f"{os.getenv('SS_RVC_VENV', os.getenv('SS_BASE', '/workspace') + '/venvs/rvc')}/bin/pip"
        print(f"[ERR] missing deps: {', '.join(missing)}", file=sys.stderr)
        print(f"[ERR] run `{pip} install --no-cache-dir faiss-cpu transformers librosa soundfile`", file=sys.stderr)
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser(description="Build FAISS index from WAV")
    ap.add_argument("--wav", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    check_deps()
    import librosa, faiss, numpy as np, torch
    from transformers import HubertModel, HubertProcessor

    wav, _ = librosa.load(args.wav, sr=16000, mono=True)
    processor = HubertProcessor.from_pretrained("facebook/hubert-base-ls960")
    model = HubertModel.from_pretrained("facebook/hubert-base-ls960", use_safetensors=True)
    with torch.no_grad():
        inp = processor(wav, sampling_rate=16000, return_tensors="pt")
        emb = model(**inp).last_hidden_state.squeeze(0).cpu().numpy().astype("float32")

    index = faiss.IndexFlatL2(emb.shape[1])
    index.add(emb)
    faiss.write_index(index, args.out)
    print(f"[OK] index saved to {args.out}")


if __name__ == "__main__":
    main()
