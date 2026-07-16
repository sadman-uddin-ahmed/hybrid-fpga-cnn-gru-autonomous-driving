# Golden fixed-point (integer) emulation for Conv1 -> ReLU -> MaxPool
# Export test vectors for FPGA simulation.
import os
import json
import numpy as np
import torch
from torchvision import transforms
from kitti_dataset import KITTICarPresentDataset, make_splits
# Paths
KITTI_IMAGE_DIR = r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework\Datasets\KITTI_Dataset_3D_Object_Detection\Data_Object_Image_Left\training\image_2"
KITTI_LABEL_DIR = r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework\Datasets\KITTI_Dataset_3D_Object_Detection\Training_Object_Label\training\label_2"
QDIR = os.path.join("exports", "quant", "W8_txt")
VEC_DIR = os.path.join("exports", "vectors")
W_PATH = os.path.join(QDIR, "conv1_w.txt")
B_PATH = os.path.join(QDIR, "conv1_b_int32_correct.txt")
META_PATH = os.path.join(QDIR, "fixedpoint_meta.json")
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
    print("=== Fixed-point Conv1 Vector Export ===", flush=True)
    # Check required files exist
    for p in [W_PATH, B_PATH, META_PATH]:
        if not os.path.exists(p):
            raise FileNotFoundError(f"Missing required file: {p}")
    os.makedirs(VEC_DIR, exist_ok=True)
    # Load fixed-point meta (scales)
    with open(META_PATH, "r", encoding="utf-8") as f:
        meta = json.load(f)
    a0_scale = float(meta["a0_scale"])           # input scale
    a1_scale = float(meta["a1_scale"])           # output scale after conv1 block (we will quantize to this)
    conv1_w_scale = float(meta["conv1_w_scale"]) # weight scale
    # Load conv1 weights and bias
    # conv1 weight shape in PyTorch: (out_ch=16, in_ch=3, kH=3, kW=3) => total 16*3*3*3 = 432
    w = read_txt_int(W_PATH, np.int8)
    if w.size != 16 * 3 * 3 * 3:
        raise RuntimeError(f"conv1_w.txt has {w.size} values, expected {16*3*3*3}")
    w = w.reshape(16, 3, 3, 3)
    # conv1 bias shape: (16,)
    b = read_txt_int(B_PATH, np.int32)
    if b.size != 16:
        raise RuntimeError(f"conv1_b_int32_correct.txt has {b.size} values, expected 16")
    # Prepare dataset (we will pick 1 sample from internal test split)
    transform = transforms.Compose([
        transforms.Resize((64, 64)),
        transforms.ToTensor(),
        transforms.Normalize((0.5,0.5,0.5),(0.5,0.5,0.5)),
    ])
    # Use internal test split
    _, _, test_ids = make_splits(KITTI_IMAGE_DIR, seed=0, train_ratio=0.8, val_ratio=0.1)
    test_ds = KITTICarPresentDataset(KITTI_IMAGE_DIR, KITTI_LABEL_DIR, test_ids, transform=transform)
    # Pick one sample (index 0). You can change to another index later.
    x_float, y = test_ds[0]  # x_float is torch tensor (3,64,64)
    x_float = x_float.numpy().astype(np.float32)
    # Quantize input image to int8 using a0_scale
    # x_int = round(x_float / a0_scale)
    x_int = np.round(x_float / a0_scale).astype(np.int32)
    x_int = clamp_int(x_int, -128, 127).astype(np.int8)  # store as int8
    # Fixed-point convolution:
    # acc = sum(x_int * w_int) + b_int32
    # Then ReLU: acc = max(acc, 0)
    # Note: This acc is in integer domain of (x_int*w_int) sums.
    # Then we need to scale to output int8 using a1_scale and (a0_scale * w_scale).
    # Because:
    #   x_float ≈ x_int * a0_scale
    #   w_float ≈ w_int * w_scale
    #   conv_float ≈ acc_int * (a0_scale * w_scale)
    # Then output int8:
    #   y_int8 = round(conv_float / a1_scale)
    #        = round(acc_int * (a0_scale*w_scale) / a1_scale)
    H, W_ = 64, 64
    out_ch = 16
    in_ch = 3
    k = 3
    pad = 1
    # Pad input (CHW)
    x_pad = np.pad(
        x_int.astype(np.int32),
        pad_width=((0, 0), (pad, pad), (pad, pad)),
        mode="constant",
        constant_values=0
    )
    # Output before pooling: (16,64,64)
    conv_out_int32 = np.zeros((out_ch, H, W_), dtype=np.int32)
    for oc in range(out_ch):
        for i in range(H):
            for j in range(W_):
                acc = int(b[oc])
                # 3x3 over 3 channels
                for ic in range(in_ch):
                    for ki in range(k):
                        for kj in range(k):
                            xi = x_pad[ic, i + ki, j + kj]
                            wi = int(w[oc, ic, ki, kj])
                            acc += int(xi) * wi
                # ReLU in accumulator domain
                if acc < 0:
                    acc = 0
                conv_out_int32[oc, i, j] = acc
    # MaxPool 2x2 stride 2 => (16,32,32)
    pooled_int32 = np.zeros((out_ch, 32, 32), dtype=np.int32)
    for oc in range(out_ch):
        for i in range(32):
            for j in range(32):
                block = conv_out_int32[oc, (2*i):(2*i+2), (2*j):(2*j+2)]
                pooled_int32[oc, i, j] = int(block.max())
    # Convert pooled accumulator integers -> output int8 using scaling
    scale_acc_to_out = (a0_scale * conv1_w_scale) / a1_scale
    out_int = np.round(pooled_int32.astype(np.float32) * scale_acc_to_out).astype(np.int32)
    out_int = clamp_int(out_int, -128, 127).astype(np.int8)
    # Export vectors as flattened one-int-per-line
    in_path = os.path.join(VEC_DIR, "in_img_int8.txt")
    out_path = os.path.join(VEC_DIR, "out_conv1_pool_int8_expected.txt")
    info_path = os.path.join(VEC_DIR, "vector_info.json")
    save_txt_1d(in_path, x_int.reshape(-1))
    save_txt_1d(out_path, out_int.reshape(-1))
    info = {
        "description": "Golden fixed-point vectors for Conv1->ReLU->MaxPool",
        "sample_index_in_internal_test_split": 0,
        "label_y": int(y),
        "input_layout": "CHW (3,64,64) flattened C-order one int per line",
        "output_layout": "CHW (16,32,32) flattened C-order one int per line",
        "scales_used": {
            "a0_scale": a0_scale,
            "conv1_w_scale": conv1_w_scale,
            "a1_scale": a1_scale,
            "scale_acc_to_out": float(scale_acc_to_out)
        },
        "files": {
            "input_int8_txt": in_path,
            "output_int8_expected_txt": out_path
        }
    }
    with open(info_path, "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)
    print("Saved vectors:", flush=True)
    print(f" - {in_path}", flush=True)
    print(f" - {out_path}", flush=True)
    print(f" - {info_path}", flush=True)
    print("=== Done ===", flush=True)
if __name__ == "__main__":
    run()