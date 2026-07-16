# Re-export conv biases correctly for fixed-point inference.
import os
import json
import numpy as np
import torch
import torch.nn as nn
CKPT_PATH = "kitti_smallcnn.pt"
QDIR = os.path.join("exports", "quant", "W8_txt")
SCALES_JSON = os.path.join(QDIR, "scales.json")
ACTS_JSON = os.path.join(QDIR, "act_scales.json")
class SmallCNN(nn.Module):
    def __init__(self, num_classes=2):
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(3, 16, 3, padding=1),   # net[0] conv1
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(16, 32, 3, padding=1),  # net[3] conv2
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Flatten(),
            nn.Linear(32 * 16 * 16, 128),
            nn.ReLU(),
            nn.Linear(128, num_classes),
        )
    def forward(self, x):
        return self.net(x)
def save_txt_1d(path: str, arr_1d: np.ndarray):
    with open(path, "w", encoding="utf-8") as f:
        for v in arr_1d.reshape(-1):
            f.write(f"{int(v)}\n")
def bias_to_int32(b_float: np.ndarray, a_scale: float, w_scale: float) -> np.ndarray:
    denom = a_scale * w_scale
    if denom == 0.0:
        denom = 1.0
    return np.round(b_float / denom).astype(np.int32)
def run():
    print("=== Export Correct Bias Integers (int32) ===")
    if not os.path.exists(CKPT_PATH):
        raise FileNotFoundError(f"Missing checkpoint: {CKPT_PATH}")
    if not os.path.exists(SCALES_JSON):
        raise FileNotFoundError(f"Missing scales.json: {SCALES_JSON}")
    if not os.path.exists(ACTS_JSON):
        raise FileNotFoundError(f"Missing act_scales.json: {ACTS_JSON}")
    os.makedirs(QDIR, exist_ok=True)
    # Load scales
    with open(SCALES_JSON, "r", encoding="utf-8") as f:
        s = json.load(f)
    conv1_w_scale = float(s["conv1_w_scale"])
    conv2_w_scale = float(s["conv2_w_scale"])
    with open(ACTS_JSON, "r", encoding="utf-8") as f:
        a = json.load(f)
    a1_scale = float(a["a1_scale"])  # after conv1 block
    # a2_scale exists, but not needed for bias scaling (only needed for later activation quant)
    # a2_scale = float(a["a2_scale"])
    # Define input activation scale (a0)
    # Input after Normalize is roughly in [-1, 1], so map to int8 [-127,127]
    a0_scale = 1.0 / 127.0
    # Load model biases
    model = SmallCNN(num_classes=2)
    model.load_state_dict(torch.load(CKPT_PATH, map_location="cpu"))
    model.eval()
    conv1 = model.net[0]
    conv2 = model.net[3]
    conv1_b = conv1.bias.detach().cpu().numpy().astype(np.float32)  # (16,)
    conv2_b = conv2.bias.detach().cpu().numpy().astype(np.float32)  # (32,)
    # Convert biases to correct int32 domains
    conv1_b_int32 = bias_to_int32(conv1_b, a_scale=a0_scale, w_scale=conv1_w_scale)
    conv2_b_int32 = bias_to_int32(conv2_b, a_scale=a1_scale, w_scale=conv2_w_scale)
    # Save
    out1 = os.path.join(QDIR, "conv1_b_int32_correct.txt")
    out2 = os.path.join(QDIR, "conv2_b_int32_correct.txt")
    save_txt_1d(out1, conv1_b_int32)
    save_txt_1d(out2, conv2_b_int32)
    # Also store a0_scale so everything is documented
    out_meta = os.path.join(QDIR, "fixedpoint_meta.json")
    meta = {
        "a0_scale": a0_scale,
        "a1_scale": a1_scale,
        "conv1_w_scale": conv1_w_scale,
        "conv2_w_scale": conv2_w_scale,
        "bias_rule": "b_int32 = round(b_float / (a_scale * w_scale))",
        "conv1_bias_domain": "uses a0_scale * conv1_w_scale",
        "conv2_bias_domain": "uses a1_scale * conv2_w_scale (conv2 input is conv1 output)",
    }
    with open(out_meta, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    print("Saved:")
    print(f" - {out1}")
    print(f" - {out2}")
    print(f" - {out_meta}")
    print("=== Done ===")
if __name__ == "__main__":
    run()