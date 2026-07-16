# Quantization Sensitivity Analysis
# NOTE:
# This is an emulation in Python. It is not exported to FPGA yet.
import os
import time
import csv
from typing import Tuple
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import transforms
from kitti_dataset import KITTICarPresentDataset, make_splits
# KITTI PATHS
KITTI_IMAGE_DIR = r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework\Datasets\KITTI_Dataset_3D_Object_Detection\Data_Object_Image_Left\training\image_2"
KITTI_LABEL_DIR = r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework\Datasets\KITTI_Dataset_3D_Object_Detection\Training_Object_Label\training\label_2"
# CHECKPOINT
CKPT_PATH = "kitti_smallcnn.pt"
class SmallCNN(nn.Module):
    """
    EXACT SAME MODEL as baseline_cnn.py (Sequential called 'net').
    """
    def __init__(self, num_classes=2):
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(3, 16, 3, padding=1),   # net[0]
            nn.ReLU(),                        # net[1]
            nn.MaxPool2d(2),                  # net[2]
            nn.Conv2d(16, 32, 3, padding=1),  # net[3]
            nn.ReLU(),                        # net[4]
            nn.MaxPool2d(2),                  # net[5]
            nn.Flatten(),                     # net[6]
            nn.Linear(32 * 16 * 16, 128),     # net[7]
            nn.ReLU(),                        # net[8]
            nn.Linear(128, num_classes),      # net[9]
        )
    def forward(self, x):
        return self.net(x)
def accuracy_from_logits(logits: torch.Tensor, y: torch.Tensor) -> float:
    preds = torch.argmax(logits, dim=1)
    return (preds == y).float().mean().item()
# Fake quant helper (symmetric, per-tensor)
def quantize_tensor_symmetric(x: torch.Tensor, bits: int) -> torch.Tensor:
    """
    Fake quantization:
    - compute scale from max(|x|)
    - quantize to signed integer range
    - dequantize back to float tensor
    """
    if bits >= 32:
        return x
    qmax = (2 ** (bits - 1)) - 1
    qmin = - (2 ** (bits - 1))
    max_abs = x.abs().max()
    if max_abs == 0:
        return x
    scale = max_abs / qmax
    x_int = torch.round(x / scale).clamp(qmin, qmax)
    x_deq = x_int * scale
    return x_deq
def quantized_forward(model: SmallCNN, x: torch.Tensor, w_bits: int, a_bits: int) -> torch.Tensor:
    """
    Forward pass with fake quant:
    - quantize weights for each Conv/Linear
    - quantize activations after pool/relu blocks
    """
    # Grab layers by index (Sequential)
    conv1 = model.net[0]
    conv2 = model.net[3]
    fc1 = model.net[7]
    fc2 = model.net[9]
    # Conv1 Block
    w = quantize_tensor_symmetric(conv1.weight, w_bits)
    b = conv1.bias  # keep bias float for now (simple)
    x = torch.nn.functional.conv2d(x, w, b, stride=1, padding=1)
    x = torch.relu(x)
    x = torch.nn.functional.max_pool2d(x, 2)
    x = quantize_tensor_symmetric(x, a_bits)
    # Conv2 Block
    w = quantize_tensor_symmetric(conv2.weight, w_bits)
    b = conv2.bias
    x = torch.nn.functional.conv2d(x, w, b, stride=1, padding=1)
    x = torch.relu(x)
    x = torch.nn.functional.max_pool2d(x, 2)
    x = quantize_tensor_symmetric(x, a_bits)
    # FC1
    x = x.flatten(1)
    w = quantize_tensor_symmetric(fc1.weight, w_bits)
    b = fc1.bias
    x = torch.nn.functional.linear(x, w, b)
    x = torch.relu(x)
    x = quantize_tensor_symmetric(x, a_bits)
    # FC2
    w = quantize_tensor_symmetric(fc2.weight, w_bits)
    b = fc2.bias
    x = torch.nn.functional.linear(x, w, b)
    return x
def eval_float(model: SmallCNN, loader: DataLoader) -> Tuple[float, float]:
    model.eval()
    t0 = time.perf_counter()
    acc_sum = 0.0
    with torch.no_grad():
        for x, y in loader:
            logits = model(x)
            acc_sum += accuracy_from_logits(logits, y)
    t1 = time.perf_counter()
    return acc_sum / len(loader), (t1 - t0)
def eval_fake_quant(model: SmallCNN, loader: DataLoader, w_bits: int, a_bits: int) -> Tuple[float, float]:
    model.eval()
    t0 = time.perf_counter()
    acc_sum = 0.0
    with torch.no_grad():
        for x, y in loader:
            logits = quantized_forward(model, x, w_bits=w_bits, a_bits=a_bits)
            acc_sum += accuracy_from_logits(logits, y)
    t1 = time.perf_counter()
    return acc_sum / len(loader), (t1 - t0)
def run():
    print("=== Quantization Sensitivity Eval (KITTI) ===", flush=True)
    if not os.path.exists(CKPT_PATH):
        raise FileNotFoundError(f"Checkpoint not found: {CKPT_PATH}")
    transform = transforms.Compose([
        transforms.Resize((64, 64)),
        transforms.ToTensor(),
        transforms.Normalize((0.5,0.5,0.5),(0.5,0.5,0.5)),
    ])
    # Same internal test split used before
    _, _, test_ids = make_splits(KITTI_IMAGE_DIR, seed=0, train_ratio=0.8, val_ratio=0.1)
    test_ds = KITTICarPresentDataset(KITTI_IMAGE_DIR, KITTI_LABEL_DIR, test_ids, transform=transform)
    test_loader = DataLoader(test_ds, batch_size=64, shuffle=False, num_workers=0)
    # Load model (now keys match)
    model = SmallCNN(num_classes=2)
    model.load_state_dict(torch.load(CKPT_PATH, map_location="cpu"))
    # Float baseline
    float_acc, float_time = eval_float(model, test_loader)
    print(f"FLOAT: acc={float_acc:.4f} | eval_time={float_time:.1f}s", flush=True)
    # Quant settings
    settings = [(8, 8), (8, 6), (6, 6), (4, 4)]
    rows = []
    for w_bits, a_bits in settings:
        q_acc, q_time = eval_fake_quant(model, test_loader, w_bits=w_bits, a_bits=a_bits)
        print(f"W{w_bits}A{a_bits}: acc={q_acc:.4f} | eval_time={q_time:.1f}s", flush=True)
        rows.append((w_bits, a_bits, q_acc, q_time))
    # Save results to CSV
    out_csv = "quant_sensitivity.csv"
    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["setting", "w_bits", "a_bits", "accuracy", "eval_time_s"])
        writer.writerow(["FLOAT", "", "", float_acc, float_time])
        for w_bits, a_bits, acc, t in rows:
            writer.writerow([f"W{w_bits}A{a_bits}", w_bits, a_bits, acc, t])
    print(f"Saved: {out_csv}", flush=True)
    print("=== Done ===", flush=True)
if __name__ == "__main__":
    run()