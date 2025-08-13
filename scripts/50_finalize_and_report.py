#!/usr/bin/env python
import os, sys, json, argparse, hashlib, time
import numpy as np, soundfile as sf, pyloudnorm as pyln, resampy
import onnxruntime as ort

TARGET_LUFS_INST = -20.0
TARGET_LUFS_LEAD = -18.5
PEAK_CEIL = 10 ** (-3.0/20)
OUT_SR = 48000

SS_WORK = os.getenv('SS_WORK', '/vol/work')
SS_OUT = os.getenv('SS_OUT', '/vol/out')
SS_MODELS_DIR = os.getenv('SS_MODELS_DIR', '/vol/models')


def read_audio_mono(path):
    x, sr = sf.read(path, always_2d=True)
    if x.ndim == 2 and x.shape[1] > 1:
        x = np.mean(x, axis=1, keepdims=True)
    return x.astype(np.float32), sr

def measure_lufs(x, sr):
    meter = pyln.Meter(sr)
    return float(meter.integrated_loudness(x.squeeze()))

def gain_to_target_lufs(x, sr, target):
    curr = measure_lufs(x, sr)
    g = 10 ** ((target - curr)/20)
    return g, curr

def peak_limit_pair(a, b):
    peak = max(np.max(np.abs(a)), np.max(np.abs(b)))
    if peak <= PEAK_CEIL:
        return a, b, False, float(peak)
    g = PEAK_CEIL / peak
    return a*g, b*g, True, float(peak)

def sha256(path):
    if os.path.isfile(path):
        h = hashlib.sha256()
        with open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                h.update(chunk)
        return h.hexdigest()
    return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--slug', required=True)
    args = ap.parse_args()
    t0 = time.time()

    slug = args.slug
    base = f"{SS_WORK}/{slug}"
    outd = f"{SS_OUT}/{slug}"
    os.makedirs(outd, exist_ok=True)

    inst_in = f"{base}/01_accompaniment.wav"
    lead_in = f"{outd}/04_vocal_converted.wav"
    inst_out = f"{outd}/{slug}.instrumental.UVR-MDX-NET-Inst_HQ_3.wav"
    lead_out = f"{outd}/{slug}.lead_converted.wav"

    inst, sr_i = read_audio_mono(inst_in)
    lead, sr_l = read_audio_mono(lead_in)

    if sr_i != OUT_SR:
        inst = resampy.resample(inst.squeeze(), sr_i, OUT_SR).reshape(-1,1)
        sr_i = OUT_SR
    if sr_l != OUT_SR:
        lead = resampy.resample(lead.squeeze(), sr_l, OUT_SR).reshape(-1,1)
        sr_l = OUT_SR

    g_i, lufs_i = gain_to_target_lufs(inst, sr_i, TARGET_LUFS_INST)
    g_l, lufs_l = gain_to_target_lufs(lead, sr_l, TARGET_LUFS_LEAD)
    inst_s = inst * g_i
    lead_s = lead * g_l

    inst_f, lead_f, limited, peak_before = peak_limit_pair(inst_s, lead_s)

    sf.write(inst_out, inst_f, OUT_SR, subtype='PCM_24')
    sf.write(lead_out, lead_f, OUT_SR, subtype='PCM_24')

    ref_len = len(inst_f)
    lead_len = len(lead_f)
    drift = abs(lead_len - ref_len) / max(1, ref_len)

    report = {
        'slug': slug,
        'targets': {'instrumental': TARGET_LUFS_INST, 'lead': TARGET_LUFS_LEAD},
        'peak_ceil_db': -3.0,
        'lufs_before': {'instrumental': lufs_i, 'lead': lufs_l},
        'gains': {'instrumental': float(g_i), 'lead': float(g_l)},
        'peak_before': peak_before,
        'peak_limited': bool(limited),
        'sr': OUT_SR,
        'length': {'instrumental': int(ref_len), 'lead': int(lead_len)},
        'length_drift_ratio': float(drift),
        'pass': (drift <= 0.005)
    }
    with open(f"{outd}/quality_report.json", 'w') as f:
        json.dump(report, f, indent=2)
    if not report['pass']:
        raise SystemExit(f"Length drift too large: {report['length_drift_ratio']}")

    providers = ort.get_available_providers()
    models = {
        'uvr_sep': sha256(os.path.join(SS_MODELS_DIR,'UVR','UVR-MDX-NET-Inst_HQ_3.onnx')),
        'uvr_main': sha256(os.path.join(SS_MODELS_DIR,'UVR','Kim_Vocal_2.onnx')),
        'uvr_reverb': sha256(os.path.join(SS_MODELS_DIR,'UVR','Reverb_HQ_By_FoxJoy.onnx')),
        'rvc_pth': sha256(os.getenv('SS_RVC_PTH','')),
        'rvc_index': sha256(os.getenv('SS_RVC_INDEX',''))
    }
    trace = {
        'slug': slug,
        'paths': {'inst_in': inst_in, 'lead_in': lead_in, 'inst_out': inst_out, 'lead_out': lead_out},
        'env': {k: os.getenv(k) for k in ['SS_MODELS_DIR','SS_ORT_PROVIDERS']},
        'providers_snapshot': providers,
        'model_sha256': models,
        'elapsed_sec': time.time()-t0
    }
    with open(f"{outd}/trace.json", 'w') as f:
        json.dump(trace, f, indent=2)

if __name__ == '__main__':
    main()
