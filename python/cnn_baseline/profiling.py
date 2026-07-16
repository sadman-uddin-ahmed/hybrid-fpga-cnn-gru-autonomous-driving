# Baseline characterization for trained KITTI CNN.
import os
import time
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import transforms
from kitti_dataset import KITTICarPresentDataset, make_splits
# SAME KITTI PATHS AS TRAINING
KITTI_IMAGE_DIR = r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework\Datasets\KITTI_Dataset_3D_Object_Detection\Data_Object_Image_Left\training\image_2"
KITTI_LABEL_DIR = r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework\Datasets\KITTI_Dataset_3D_Object_Detection\Training_Object_Label\training\label_2"
# MODEL CHECKPOINT PATH
CKPT_PATH = "kitti_smallcnn.pt"
class SmallCNN(nn.Module):
    """
    Must match the architecture you trained.
    Input:  (3, 64, 64)
    Output: 2 classes
    """
    def __init__(self, num_classes=2):
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(3, 16, 3, padding=1),
            nn.ReLU(),
            nn.MaxPool2d(2),  # 64 -> 32
            nn.Conv2d(16, 32, 3, padding=1),
            nn.ReLU(),
            nn.MaxPool2d(2),  # 32 -> 16
            nn.Flatten(),
            nn.Linear(32 * 16 * 16, 128),
            nn.ReLU(),
            nn.Linear(128, num_classes),
        )
    def forward(self, x):
        return self.net(x)
def count_parameters(model: nn.Module) -> int:
    """Total number of trainable parameters."""
    return sum(p.numel() for p in model.parameters() if p.requires_grad)
def file_size_mb(path: str) -> float:
    """File size in MB."""
    return os.path.getsize(path) / (1024 * 1024)
def measure_cpu_latency_ms(model: nn.Module, loader: DataLoader, warmup_batches=10, timed_batches=50) -> float:
    """
    Measures average inference latency in milliseconds per image on CPU.
    - Warmup batches: run forward passes but do not time them.
    - Timed batches: time forward passes.
    """
    model.eval()
    # Warmup
    with torch.no_grad():
        for i, (x, _) in enumerate(loader):
            _ = model(x)
            if i + 1 >= warmup_batches:
                break
    # Timed runs
    total_images = 0
    t0 = time.perf_counter()
    with torch.no_grad():
        for i, (x, _) in enumerate(loader):
            _ = model(x)
            total_images += x.shape[0]
            if i + 1 >= timed_batches:
                break
    t1 = time.perf_counter()
    total_time_s = t1 - t0
    ms_per_image = (total_time_s * 1000.0) / max(1, total_images)
    return ms_per_image
def run():
    print("=== Baseline Profiling Started ===")
    # 1) Build the same transform used in training
    transform = transforms.Compose([
        transforms.Resize((64, 64)),
        transforms.ToTensor(),
        transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5)),
    ])
    # 2) Create internal split (same method as training)
    _, _, test_ids = make_splits(KITTI_IMAGE_DIR, seed=0, train_ratio=0.8, val_ratio=0.1)
    # 3) Create test dataset and loader
    test_ds = KITTICarPresentDataset(KITTI_IMAGE_DIR, KITTI_LABEL_DIR, test_ids, transform=transform)
    # batch_size affects throughput; we measure ms/image, so batch_size=64 is fine
    test_loader = DataLoader(test_ds, batch_size=64, shuffle=False, num_workers=0)
    # 4) Load model + checkpoint
    if not os.path.exists(CKPT_PATH):
        raise FileNotFoundError(f"Checkpoint not found: {CKPT_PATH}")
    model = SmallCNN(num_classes=2)
    state = torch.load(CKPT_PATH, map_location="cpu")
    model.load_state_dict(state)
    # 5) Parameter count
    params = count_parameters(model)
    # 6) Model file size
    size_mb = file_size_mb(CKPT_PATH)
    # 7) CPU latency
    ms_per_image = measure_cpu_latency_ms(model, test_loader, warmup_batches=10, timed_batches=50)
    print("\n=== Baseline Characterization Results ===")
    print(f"Checkpoint file: {CKPT_PATH}")
    print(f"Parameter count: {params:,}")
    print(f"Checkpoint size: {size_mb:.2f} MB")
    print(f"CPU inference:  {ms_per_image:.3f} ms/image (average)")
    # Save a very simple CSV (so you can use it later in dissertation tables)
    out_csv = "baseline_profile.csv"
    with open(out_csv, "w", encoding="utf-8") as f:
        f.write("model,params,checkpoint_mb,cpu_ms_per_image\n")
        f.write(f"kitti_smallcnn,{params},{size_mb:.6f},{ms_per_image:.6f}\n")
    print(f"\nSaved: {out_csv}")
    print("=== Baseline Profiling Finished ===")
if __name__ == "__main__":
    run()