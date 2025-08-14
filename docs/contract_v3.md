# 契约 v3 摘要（Seperate02）

**输出与命名**  
- 最终产物：
  - `<slug>.instrumental.UVR-MDX-NET-Inst_HQ_3.wav`
  - `<slug>.lead_converted.G_8200.wav`
  - `quality_report.json` / `trace.json`
- 写盘：WAV 48kHz / 24‑bit PCM。

**UVR 三段参数（audio-separator 0.35.x）**  
- 伴奏分离：`--mdx_segment_size 10 --mdx_overlap 5 --normalization 1.0 --amplification 0`
- 主人声提取：`--mdx_segment_size 8 --mdx_overlap 4 --normalization 1.0 --amplification 0`
- 去混响降噪：`--mdx_segment_size 8 --mdx_overlap 4 --normalization 1.0 --amplification 0`

**RVC 参数（v2）**  
`-me rmvpe -ir 0.75 -pr 0.33 -rmr 0.0 -rsr 48000`（缺 `rvc` 可执行时回退 `python -m rvc`）。

**质量护栏**  
- LUFS：Inst = −20.0，Lead = −18.5（±0.2 回整）；
- 峰值 ≤ −3.0 dBFS；
- 漂移 ≤ 0.5%；
- `trace.json` 记录 providers、模型 SHA、steps_time 等。

**GDrive 自动化**  
- `rclone`：`--checksum --fast-list --tpslimit 4 --checkers 4 --transfers 2`（可由 `.env` 覆盖）。
- 失败：上传 `<slug>.reason.txt`，可携带 `quality_report.json` 与 `run.log` 尾部。
