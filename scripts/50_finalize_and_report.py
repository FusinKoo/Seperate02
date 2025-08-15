#!/usr/bin/env python
import os, sys, json, argparse, hashlib, time

# allow tuning targets via environment variables
TARGET_LUFS_INST = float(os.getenv('SS_TARGET_LUFS_INST', '-20.0'))
TARGET_LUFS_LEAD = float(os.getenv('SS_TARGET_LUFS_LEAD', '-18.5'))
PEAK_CEIL = 10 ** (-3.0/20)
OUT_SR = 48000

SS_WORK = os.getenv('SS_WORK', '/vol/work')
SS_OUT = os.getenv('SS_OUT', '/vol/out')
SS_MODELS_DIR = os.getenv('SS_MODELS_DIR', '/vol/models')


def sha256(path: str):
    if os.path.isfile(path):
        h = hashlib.sha256()
        with open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(8192), b''):
                h.update(chunk)
        return h.hexdigest()
    return None


def model_info(path: str):
    return {
        'path': path,
        'exists': os.path.isfile(path),
        'sha256_12': (sha256(path) or '')[:12]
    }


def read_audio_mono(path, sf, np):
    x, sr = sf.read(path, always_2d=True)
    if x.ndim == 2 and x.shape[1] > 1:
        x = np.mean(x, axis=1, keepdims=True)
    return x.astype(np.float32), sr


def measure_lufs(x, sr, pyln):
    meter = pyln.Meter(sr)
    return float(meter.integrated_loudness(x.squeeze()))


def gain_to_target_lufs(x, sr, target, pyln, np):
    curr = measure_lufs(x, sr, pyln)
    g = 10 ** ((target - curr)/20)
    return g, curr


def peak_limit_pair(a, b, np):
    peak = max(float(np.max(np.abs(a))), float(np.max(np.abs(b))))
    if peak <= PEAK_CEIL:
        return a, b, False, peak
    g = PEAK_CEIL / peak
    return a*g, b*g, True, peak


def main(argv=None):
    ap = argparse.ArgumentParser(description='Finalize outputs, normalize and report metrics.')
    ap.add_argument('--slug', required=True)
    args = ap.parse_args(argv)

    try:
        import numpy as np, soundfile as sf, pyloudnorm as pyln, resampy, onnxruntime as ort
    except Exception as e:
        print('[ERR] missing dependency:', e, file=sys.stderr)
        print('[ERR] run `pip install -r requirements-locked.txt`', file=sys.stderr)
        return 1

    t0 = time.time()
    slug = args.slug
    base = f"{SS_WORK}/{slug}"
    outd = f"{SS_OUT}/{slug}"
    os.makedirs(outd, exist_ok=True)

    rvc_tag = os.getenv('SS_RVC_MODEL_TAG', 'G_8200')

    inst_in = f"{base}/01_accompaniment.wav"
    lead_in = f"{outd}/04_vocal_converted.wav"
    inst_out = f"{outd}/{slug}.instrumental.UVR-MDX-NET-Inst_HQ_3.wav"
    lead_out = f"{outd}/{slug}.lead_converted.{rvc_tag}.wav"

    inst, sr_i = read_audio_mono(inst_in, sf, np)
    lead, sr_l = read_audio_mono(lead_in, sf, np)

    if sr_i != OUT_SR:
        inst = resampy.resample(inst.squeeze(), sr_i, OUT_SR).reshape(-1, 1)
        sr_i = OUT_SR
    if sr_l != OUT_SR:
        lead = resampy.resample(lead.squeeze(), sr_l, OUT_SR).reshape(-1, 1)
        sr_l = OUT_SR

    g_i, lufs_i = gain_to_target_lufs(inst, sr_i, TARGET_LUFS_INST, pyln, np)
    g_l, lufs_l = gain_to_target_lufs(lead, sr_l, TARGET_LUFS_LEAD, pyln, np)
    inst_s = inst * g_i
    lead_s = lead * g_l

    inst_f, lead_f, limited, peak_before = peak_limit_pair(inst_s, lead_s, np)

    # metrics after limiting
    final_peak = max(float(np.max(np.abs(inst_f))), float(np.max(np.abs(lead_f))))
    lufs_i_f = measure_lufs(inst_f, OUT_SR, pyln)
    lufs_l_f = measure_lufs(lead_f, OUT_SR, pyln)

    sf.write(inst_out, inst_f, OUT_SR, subtype='PCM_24')
    sf.write(lead_out, lead_f, OUT_SR, subtype='PCM_24')

    ref_len = len(inst_f)
    lead_len = len(lead_f)
    drift = abs(lead_len - ref_len) / max(1, ref_len)

    tol = 0.2
    lufs_ok = (abs(lufs_i_f - TARGET_LUFS_INST) <= tol and
               abs(lufs_l_f - TARGET_LUFS_LEAD) <= tol)
    peak_ok = final_peak <= PEAK_CEIL

    report = {
        'slug': slug,
        'targets': {'instrumental': TARGET_LUFS_INST, 'lead': TARGET_LUFS_LEAD},
        'peak_ceil_db': -3.0,
        'lufs_before': {'instrumental': lufs_i, 'lead': lufs_l},
        'gains': {'instrumental': float(g_i), 'lead': float(g_l)},
        'peak_before': peak_before,
        'peak_limited': bool(limited),
        'final_lufs': {'instrumental': lufs_i_f, 'lead': lufs_l_f},
        'final_peak': final_peak,
        'sr': OUT_SR,
        'length': {'instrumental': int(ref_len), 'lead': int(lead_len)},
        'length_drift_ratio': float(drift),
        'pass': (drift <= 0.005 and lufs_ok and peak_ok)
    }
    with open(f"{outd}/quality_report.json", 'w') as f:
        json.dump(report, f, indent=2)
    if not report['pass']:
        if drift > 0.005:
            print(f'[ERR] Length drift too large: {report["length_drift_ratio"]}', file=sys.stderr)
        if not lufs_ok:
            print(f'[ERR] LUFS out of tolerance: inst {lufs_i_f:.2f}, lead {lufs_l_f:.2f}', file=sys.stderr)
        if not peak_ok:
            print(f'[ERR] Peak above ceiling: {final_peak:.4f} > {PEAK_CEIL:.4f}', file=sys.stderr)
        return 1

    providers = os.getenv('SS_ORT_PROVIDERS')
    if providers:
        providers = providers.split(',')
    else:
        providers = ort.get_available_providers()
    try:
        import subprocess
        git_branch = subprocess.check_output(['git', 'rev-parse', '--abbrev-ref', 'HEAD'], text=True).strip()
        git_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
        is_dirty = subprocess.call(['git', 'diff', '--quiet']) != 0
    except Exception:
        git_branch = git_head = None
        is_dirty = None
    try:
        gpu = subprocess.check_output(['nvidia-smi', '--query-gpu=name', '--format=csv,noheader'], text=True).strip().splitlines()
    except Exception:
        gpu = None

    models = {
        'uvr_sep': model_info(os.path.join(SS_MODELS_DIR, 'UVR', 'UVR-MDX-NET-Inst_HQ_3.onnx')),
        'uvr_main': model_info(os.path.join(SS_MODELS_DIR, 'UVR', 'Kim_Vocal_2.onnx')),
        'uvr_reverb': model_info(os.path.join(SS_MODELS_DIR, 'UVR', 'Reverb_HQ_By_FoxJoy.onnx')),
        'rvc_pth': model_info(os.getenv('SS_RVC_PTH', '')),
        'rvc_index': model_info(os.getenv('SS_RVC_INDEX', ''))
    }

    steps_file = os.path.join(SS_WORK, slug, 'steps_time.json')
    steps_time = {}
    if os.path.isfile(steps_file):
        with open(steps_file) as f:
            steps_time = json.load(f)

    trace = {
        'slug': slug,
        'paths': {
            'inst_in': inst_in,
            'lead_in': lead_in,
            'inst_out': inst_out,
            'lead_out': lead_out
        },
        'env': {k: os.getenv(k) for k in ['SS_MODELS_DIR', 'SS_ORT_PROVIDERS']},
        'ort_providers': providers,
        'models': models,
        'steps_time_sec': steps_time,
        'elapsed_sec': time.time() - t0,
        'git_branch': git_branch,
        'git_head': git_head,
        'git_is_dirty': is_dirty,
        'gpu': gpu
    }
    with open(f"{outd}/trace.json", 'w') as f:
        json.dump(trace, f, indent=2)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
