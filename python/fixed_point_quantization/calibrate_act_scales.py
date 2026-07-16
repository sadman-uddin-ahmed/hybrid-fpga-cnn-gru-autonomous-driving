# Computes fixed activation scales for FPGA-friendly quantization.
import os
import json
import numpy as np
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
#WHERE TO SAVE
OUT_DIR = os.path.join("exports", "quant", "W8_txt")
OUT_JSON = os.path.join(OUT_DIR, "act_scales.json")
class SmallCNN(nn.Module):
    """
    Must match baseline_cnn.py exactly (Sequential named 'net').
    We'll manually tap intermediate outputs.
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
def compute_scale_from_maxabs(max_abs: float) -> float:
    """
    For symmetric int8:
      scale = max_abs / 127
    """
    if max_abs <= 0.0:
        return 1.0
    return float(max_abs / 127.0)
def run():
    print("=== Activation Scale Calibration (A1/A2) ===", flush=True)
    if not os.path.exists(CKPT_PATH):
        raise FileNotFoundError(f"Checkpoint not found: {CKPT_PATH}")
    os.makedirs(OUT_DIR, exist_ok=True)
    # Same preprocessing used in training
    transform = transforms.Compose([
        transforms.Resize((64, 64)),
        transforms.ToTensor(),
        transforms.Normalize((0.5,0.5,0.5),(0.5,0.5,0.5)),
    ])
    # Use TRAIN split as calibration data (common practice)
    train_ids, _, _ = make_splits(KITTI_IMAGE_DIR, seed=0, train_ratio=0.8, val_ratio=0.1)
    calib_ds = KITTICarPresentDataset(KITTI_IMAGE_DIR, KITTI_LABEL_DIR, train_ids, transform=transform)
    # Use a moderate batch size; CPU friendly
    calib_loader = DataLoader(calib_ds, batch_size=64, shuffle=False, num_workers=0)
    # Load model
    model = SmallCNN(num_classes=2)
    model.load_state_dict(torch.load(CKPT_PATH, map_location="cpu"))
    model.eval()
    # We'll measure max(|activation|) for:
    # A1: output after net[2]
    # A2: output after net[5]
    max_abs_a1 = 0.0
    max_abs_a2 = 0.0
    # To keep it quick, you can calibrate on a subset.
    # Set MAX_BATCHES = 0 to use all batches.
    MAX_BATCHES = 50  # change to 0 if you want full pass
    print("Running calibration forward passes...", flush=True)
    with torch.no_grad():
        for bi, (x, _) in enumerate(calib_loader):
            # Conv1 -> ReLU -> Pool
            x1 = model.net[0](x)
            x1 = model.net[1](x1)
            x1 = model.net[2](x1)
            # Update A1 max abs
            a1 = float(x1.abs().max().item())
            if a1 > max_abs_a1:
                max_abs_a1 = a1
            # Conv2 -> ReLU -> Pool
            x2 = model.net[3](x1)
            x2 = model.net[4](x2)
            x2 = model.net[5](x2)
            # Update A2 max abs
            a2 = float(x2.abs().max().item())
            if a2 > max_abs_a2:
                max_abs_a2 = a2
            if MAX_BATCHES > 0 and (bi + 1) >= MAX_BATCHES:
                break
            if (bi + 1) % 10 == 0:
                print(f"  processed batches: {bi+1}", flush=True)
    # Convert max-abs to scales
    a1_scale = compute_scale_from_maxabs(max_abs_a1)
    a2_scale = compute_scale_from_maxabs(max_abs_a2)
    # Save
    data = {
        "note": "Fixed symmetric int8 activation scales (scale = max_abs/127).",
        "calibration_batches_used": MAX_BATCHES,
        "a1_max_abs": max_abs_a1,
        "a2_max_abs": max_abs_a2,
        "a1_scale": a1_scale,
        "a2_scale": a2_scale,
        "where": {
            "a1": "after Conv1->ReLU->MaxPool (net[2])",
            "a2": "after Conv2->ReLU->MaxPool (net[5])"
        }
    }
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print("\n=== Calibration Results ===", flush=True)
    print(f"a1_max_abs = {max_abs_a1:.6f}  -> a1_scale = {a1_scale:.8f}", flush=True)
    print(f"a2_max_abs = {max_abs_a2:.6f}  -> a2_scale = {a2_scale:.8f}", flush=True)
    print(f"Saved: {OUT_JSON}", flush=True)
    print("=== Done ===", flush=True)
if __name__ == "__main__":
    run()