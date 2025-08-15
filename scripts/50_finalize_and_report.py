#!/usr/bin/env python
import os, sys, json, argparse, hashlib, time

TARGET_LUFS_INST = -20.0
TARGET_LUFS_LEAD = -18.5
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
    ap = argparse.ArgumentParser(
        description='Finalize outputs, normalize and report metrics.',
        epilog='Env: SS_WORK, SS_OUT, SS_MODELS_DIR'
    )
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
    sf.write(inst_out, inst_f, OUT_SR, subtype='PCM_24')
    sf.write(lead_out, lead_f, OUT_SR, subtype='PCM_24')

    final_inst_lufs = measure_lufs(inst_f, OUT_SR, pyln)
    final_lead_lufs = measure_lufs(lead_f, OUT_SR, pyln)
    final_inst_peak = 20 * np.log10(max(np.max(np.abs(inst_f)), 1e-12))
    final_lead_peak = 20 * np.log10(max(np.max(np.abs(lead_f)), 1e-12))

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
        'final_inst': {'lufs': final_inst_lufs, 'peak_dbfs': final_inst_peak},
        'final_vocal': {'lufs': final_lead_lufs, 'peak_dbfs': final_lead_peak},
        'sr': OUT_SR,
        'length': {'instrumental': int(ref_len), 'lead': int(lead_len)},
        'length_drift_ratio': float(drift)
    }

    ok = True
    if abs(final_inst_lufs - TARGET_LUFS_INST) > 0.2:
        print(f'[ERR] instrumental LUFS {final_inst_lufs:.2f} out of tolerance', file=sys.stderr)
        ok = False
    if abs(final_lead_lufs - TARGET_LUFS_LEAD) > 0.2:
        print(f'[ERR] vocal LUFS {final_lead_lufs:.2f} out of tolerance', file=sys.stderr)
        ok = False
    if final_inst_peak > -3.0 or final_lead_peak > -3.0:
        print(f'[ERR] peak above -3 dBFS (inst={final_inst_peak:.2f}, vocal={final_lead_peak:.2f})', file=sys.stderr)
        ok = False
    report['pass'] = bool(ok and drift <= 0.005)

    with open(f"{outd}/quality_report.json", 'w') as f:
        json.dump(report, f, indent=2)
    if not report['pass']:
        if drift > 0.005:
            print(f'[ERR] Length drift too large: {report["length_drift_ratio"]}', file=sys.stderr)
        return 1

    providers = os.getenv('SS_ORT_PROVIDERS')
    if providers:
        providers = providers.split(',')
    else:
        providers = ort.get_available_providers()

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
        'providers_snapshot': providers,
        'models': models,
        'steps_time_sec': steps_time,
        'elapsed_sec': time.time() - t0
    }
    with open(f"{outd}/trace.json", 'w') as f:
        json.dump(trace, f, indent=2)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
