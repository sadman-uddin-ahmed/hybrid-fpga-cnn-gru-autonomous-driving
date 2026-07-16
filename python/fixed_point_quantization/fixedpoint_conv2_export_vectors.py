# Golden fixed-point (integer) emulation for Conv2 -> ReLU -> MaxPool
# Use Conv1 pooled output as Conv2 input.
import os
import json
import numpy as np
QDIR = os.path.join("exports", "quant", "W8_txt")
VEC_DIR = os.path.join("exports", "vectors")
# Conv2 parameters
IN_CH = 16
OUT_CH = 32
K = 3
PAD = 1
# Input comes from Conv1 pooled output (already golden)
CONV2_IN_FROM_CONV1_OUT = os.path.join(VEC_DIR, "out_conv1_pool_int8_expected.txt")
# Conv2 weight/bias
W2_PATH = os.path.join(QDIR, "conv2_w.txt")
B2_PATH = os.path.join(QDIR, "conv2_b_int32_correct.txt")
# Scales
META_PATH = os.path.join(QDIR, "fixedpoint_meta.json")
ACTS_PATH = os.path.join(QDIR, "act_scales.json")
def read_txt_int(path: str, dtype):
    with open(path, "r", encoding="utf-8") as f:
        vals = [int(line.strip()) for line in f if line.strip() != ""]
    return np.array(vals, dtype=dtype)
def save_txt_1d(path: str, arr: np.ndarray):
    with open(path, "w", encoding="utf-8") as f:
        for v in arr.reshape(-1):
            f.write(f"{int(v)}\n")
def clamp_int(x: np.ndarray, lo: int, hi: int) -> np.ndarray:
    return np.clip(x, lo, hi)
def run():
    print("=== Fixed-point Conv2 Vector Export ===", flush=True)
    # Check required files
    for p in [CONV2_IN_FROM_CONV1_OUT, W2_PATH, B2_PATH, META_PATH, ACTS_PATH]:
        if not os.path.exists(p):
            raise FileNotFoundError(f"Missing required file: {p}")
    os.makedirs(VEC_DIR, exist_ok=True)
    # Load scales
    with open(META_PATH, "r", encoding="utf-8") as f:
        meta = json.load(f)
    conv2_w_scale = float(meta["conv2_w_scale"])
    a1_scale = float(meta["a1_scale"])  # Conv2 input scale (because input is Conv1 output int8)
    with open(ACTS_PATH, "r", encoding="utf-8") as f:
        acts = json.load(f)
    a2_scale = float(acts["a2_scale"])  # Conv2 output scale after pool
    # Load Conv2 weights (int8) and bias (int32)
    w2 = read_txt_int(W2_PATH, np.int8)
    expected_w2_count = OUT_CH * IN_CH * K * K  # 32*16*3*3 = 4608
    if w2.size != expected_w2_count:
        raise RuntimeError(f"conv2_w.txt has {w2.size} values, expected {expected_w2_count}")
    w2 = w2.reshape(OUT_CH, IN_CH, K, K)
    b2 = read_txt_int(B2_PATH, np.int32)
    if b2.size != OUT_CH:
        raise RuntimeError(f"conv2_b_int32_correct.txt has {b2.size} values, expected {OUT_CH}")
    # Load Conv2 input = Conv1 pooled output (int8), shape (16,32,32)
    x_in = read_txt_int(CONV2_IN_FROM_CONV1_OUT, np.int8)
    expected_in_count = IN_CH * 32 * 32  # 16*32*32 = 16384
    if x_in.size != expected_in_count:
        raise RuntimeError(f"Conv2 input file has {x_in.size} values, expected {expected_in_count}")
    x_in = x_in.reshape(IN_CH, 32, 32).astype(np.int8)
    # Also save the Conv2 input explicitly (useful for your Verilog TB)
    in_conv2_path = os.path.join(VEC_DIR, "in_conv2_int8.txt")
    save_txt_1d(in_conv2_path, x_in.reshape(-1))
    # Fixed-point Conv2:
    # acc_int = sum(x_int * w_int) + b_int32
    # ReLU in acc domain
    # Pool 2x2 stride 2
    # Then scale to output int8:
    # conv_float ≈ acc_int * (a1_scale * conv2_w_scale)
    # y_int8 = round(conv_float / a2_scale)
    #     = round(acc_int * (a1_scale*conv2_w_scale) / a2_scale)
    H, W_ = 32, 32
    # Pad input (CHW)
    x_pad = np.pad(
        x_in.astype(np.int32),
        pad_width=((0, 0), (PAD, PAD), (PAD, PAD)),
        mode="constant",
        constant_values=0
    )
    # Output before pooling: (32,32,32) in accumulator int32
    conv_out_int32 = np.zeros((OUT_CH, H, W_), dtype=np.int32)
    for oc in range(OUT_CH):
        for i in range(H):
            for j in range(W_):
                acc = int(b2[oc])
                for ic in range(IN_CH):
                    for ki in range(K):
                        for kj in range(K):
                            xi = x_pad[ic, i + ki, j + kj]
                            wi = int(w2[oc, ic, ki, kj])
                            acc += int(xi) * wi
                if acc < 0:
                    acc = 0
                conv_out_int32[oc, i, j] = acc
    # MaxPool 2x2 stride 2 => output (32,16,16)
    pooled_int32 = np.zeros((OUT_CH, 16, 16), dtype=np.int32)
    for oc in range(OUT_CH):
        for i in range(16):
            for j in range(16):
                block = conv_out_int32[oc, (2*i):(2*i+2), (2*j):(2*j+2)]
                pooled_int32[oc, i, j] = int(block.max())
    # Scale accumulator -> output int8
    scale_acc_to_out = (a1_scale * conv2_w_scale) / a2_scale
    out_int = np.round(pooled_int32.astype(np.float32) * scale_acc_to_out).astype(np.int32)
    out_int = clamp_int(out_int, -128, 127).astype(np.int8)
    # Export expected output
    out_path = os.path.join(VEC_DIR, "out_conv2_pool_int8_expected.txt")
    save_txt_1d(out_path, out_int.reshape(-1))
    info = {
        "description": "Golden fixed-point vectors for Conv2->ReLU->MaxPool",
        "input_source": "out_conv1_pool_int8_expected.txt (golden Conv1 output)",
        "input_layout": "CHW (16,32,32) flattened C-order one int per line",
        "output_layout": "CHW (32,16,16) flattened C-order one int per line",
        "scales_used": {
            "a1_scale": a1_scale,
            "conv2_w_scale": conv2_w_scale,
            "a2_scale": a2_scale,
            "scale_acc_to_out": float(scale_acc_to_out)
        },
        "files": {
            "input_int8_txt": in_conv2_path,
            "output_int8_expected_txt": out_path
        }
    }
    info_path = os.path.join(VEC_DIR, "vector_info_conv2.json")
    with open(info_path, "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)
    print("Saved vectors:", flush=True)
    print(f" - {in_conv2_path}", flush=True)
    print(f" - {out_path}", flush=True)
    print(f" - {info_path}", flush=True)
    print("=== Done ===", flush=True)
if __name__ == "__main__":
    run()