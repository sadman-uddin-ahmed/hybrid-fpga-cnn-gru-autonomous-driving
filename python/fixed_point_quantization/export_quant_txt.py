# Export quantized weights (int8) and biases (int32) to .txt files for FPGA.
import os
import json
import numpy as np
import torch
import torch.nn as nn
# CHECKPOINT
CKPT_PATH = "kitti_smallcnn.pt"
# OUTPUT FOLDER
OUT_DIR = os.path.join("exports", "quant", "W8_txt")
class SmallCNN(nn.Module):
    """
    EXACT SAME MODEL as baseline_cnn.py (Sequential called 'net').
    """
    def __init__(self, num_classes=2):
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(3, 16, 3, padding=1),   # net[0] conv1
            nn.ReLU(),                        # net[1]
            nn.MaxPool2d(2),                  # net[2]

            nn.Conv2d(16, 32, 3, padding=1),  # net[3] conv2
            nn.ReLU(),                        # net[4]
            nn.MaxPool2d(2),                  # net[5]

            nn.Flatten(),                     # net[6]

            nn.Linear(32 * 16 * 16, 128),     # net[7] fc1 (not needed for FPGA conv extractor, but exists)
            nn.ReLU(),                        # net[8]

            nn.Linear(128, num_classes),      # net[9] fc2 (not needed for FPGA conv extractor, but exists)
        )
    def forward(self, x):
        return self.net(x)
def quantize_int8_symmetric(w_float: np.ndarray):
    """
    Symmetric int8 quantization:
      q = round(w / scale), clamp to [-128, 127]
      scale = max_abs / 127  (so values map into int8 range)
    Returns:
      w_int8: np.int8 array
      scale: float (so w_float ≈ w_int8 * scale)
    """
    max_abs = np.max(np.abs(w_float))
    if max_abs == 0.0:
        scale = 1.0
        w_int8 = np.zeros_like(w_float, dtype=np.int8)
        return w_int8, scale
    scale = max_abs / 127.0
    w_q = np.round(w_float / scale)
    w_q = np.clip(w_q, -128, 127).astype(np.int8)
    return w_q, float(scale)
def quantize_bias_int32(b_float: np.ndarray, w_scale: float, a_scale: float = 1.0):
    """
    Bias should be quantized into accumulator scale.
    If your integer MAC accumulates:
      acc_int = sum(x_int * w_int)
    then bias_int must be in the same "integer domain".
    Here we export a SIMPLE bias quant:
      bias_int32 = round(b_float / (w_scale * a_scale))
    NOTE:
    - Right now we set a_scale=1.0 because we have not fixed activation scaling yet.
    - This is OK for export + later you can recompute bias properly once A-scale is defined.
    """
    denom = (w_scale * a_scale)
    if denom == 0.0:
        denom = 1.0
    b_int = np.round(b_float / denom).astype(np.int32)
    return b_int
def save_txt_1d(path: str, arr_1d: np.ndarray):
    """
    Saves a 1D array as one integer per line (decimal).
    """
    with open(path, "w", encoding="utf-8") as f:
        for v in arr_1d.reshape(-1):
            f.write(f"{int(v)}\n")
def run():
    print("=== Export quantized weights to TXT (W8) ===")
    if not os.path.exists(CKPT_PATH):
        raise FileNotFoundError(f"Checkpoint not found: {CKPT_PATH}")
    os.makedirs(OUT_DIR, exist_ok=True)
    # Load model and checkpoint
    model = SmallCNN(num_classes=2)
    state = torch.load(CKPT_PATH, map_location="cpu")
    model.load_state_dict(state)
    model.eval()
    # Extract layers we care about for FPGA feature extractor
    conv1: nn.Conv2d = model.net[0]
    conv2: nn.Conv2d = model.net[3]
    # Convert weights/biases to numpy float32
    conv1_w = conv1.weight.detach().cpu().numpy().astype(np.float32)  # shape: (out_ch, in_ch, kH, kW)
    conv1_b = conv1.bias.detach().cpu().numpy().astype(np.float32)    # shape: (out_ch,)
    conv2_w = conv2.weight.detach().cpu().numpy().astype(np.float32)
    conv2_b = conv2.bias.detach().cpu().numpy().astype(np.float32)
    # Quantize weights to int8
    conv1_w_int8, conv1_w_scale = quantize_int8_symmetric(conv1_w)
    conv2_w_int8, conv2_w_scale = quantize_int8_symmetric(conv2_w)
    # Quantize biases to int32 (provisional; refine after activation scaling is fixed)
    conv1_b_int32 = quantize_bias_int32(conv1_b, w_scale=conv1_w_scale, a_scale=1.0)
    conv2_b_int32 = quantize_bias_int32(conv2_b, w_scale=conv2_w_scale, a_scale=1.0)
    # Save TXT (flattened)
    # IMPORTANT ORDER NOTE:
    # PyTorch weight order is: (out_channels, in_channels, kH, kW)
    # We flatten in C-order, so Verilog must read in the same order.
    save_txt_1d(os.path.join(OUT_DIR, "conv1_w.txt"), conv1_w_int8.reshape(-1))
    save_txt_1d(os.path.join(OUT_DIR, "conv1_b.txt"), conv1_b_int32.reshape(-1))
    save_txt_1d(os.path.join(OUT_DIR, "conv2_w.txt"), conv2_w_int8.reshape(-1))
    save_txt_1d(os.path.join(OUT_DIR, "conv2_b.txt"), conv2_b_int32.reshape(-1))
    # Save scales (so you know how to interpret int8)
    scales = {
        "format": "symmetric_int8_weights",
        "conv1_w_scale": conv1_w_scale,
        "conv2_w_scale": conv2_w_scale,
        "bias_note": "bias_int32 = round(b_float / (w_scale * a_scale)), currently a_scale=1.0 (provisional)",
        "weight_layout": "flattened PyTorch order: (out_ch, in_ch, kH, kW) in C-order",
    }
    with open(os.path.join(OUT_DIR, "scales.json"), "w", encoding="utf-8") as f:
        json.dump(scales, f, indent=2)
    # Small README for you (helps later when writing Verilog)
    readme = os.path.join(OUT_DIR, "README.txt")
    with open(readme, "w", encoding="utf-8") as f:
        f.write("Exported KITTI baseline CNN conv weights for FPGA.\n")
        f.write("Files:\n")
        f.write("  conv1_w.txt : int8 weights flattened\n")
        f.write("  conv1_b.txt : int32 bias (provisional scaling)\n")
        f.write("  conv2_w.txt : int8 weights flattened\n")
        f.write("  conv2_b.txt : int32 bias (provisional scaling)\n")
        f.write("  scales.json : weight scales and layout notes\n\n")
        f.write("Weight tensor layout (PyTorch): (out_ch, in_ch, kH, kW)\n")
        f.write("Flattened in C-order. Verilog must read in same order.\n")
    print(f"Saved TXT weights to: {OUT_DIR}")
    print("Files created:")
    print(" - conv1_w.txt, conv1_b.txt, conv2_w.txt, conv2_b.txt, scales.json, README.txt")
    print("=== Done ===")
if __name__ == "__main__":
    run()