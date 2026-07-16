import time
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import transforms
from kitti_dataset import KITTICarPresentDataset, make_splits
# KITTI PATHS 
KITTI_IMAGE_DIR = r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework\Datasets\KITTI_Dataset_3D_Object_Detection\Data_Object_Image_Left\training\image_2"
KITTI_LABEL_DIR = r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework\Datasets\KITTI_Dataset_3D_Object_Detection\Training_Object_Label\training\label_2"
class SmallCNN(nn.Module):
    """
    Very small CNN:
      Input:  (3, 64, 64)
      Output: 2 classes (0/1)
    """
    def __init__(self, num_classes=2):
        super().__init__()
        self.net = nn.Sequential(
            # 64x64
            nn.Conv2d(3, 16, 3, padding=1),
            nn.ReLU(),
            nn.MaxPool2d(2),  # -> 32x32

            nn.Conv2d(16, 32, 3, padding=1),
            nn.ReLU(),
            nn.MaxPool2d(2),  # -> 16x16

            nn.Flatten(),  # 32*16*16
            nn.Linear(32 * 16 * 16, 128),
            nn.ReLU(),
            nn.Linear(128, num_classes)
        )
    def forward(self, x):
        return self.net(x)
def accuracy_from_logits(logits: torch.Tensor, y: torch.Tensor) -> float:
    """
    logits shape: (B, 2)
    y shape: (B,)
    """
    preds = torch.argmax(logits, dim=1)
    return (preds == y).float().mean().item()
def run():
    print("Script started...", flush=True)
    # Use CPU (simple and consistent)
    device = torch.device("cpu")
    print(f"Using device: {device}", flush=True)
    # Transform: resize small for speed and FPGA friendliness later
    transform = transforms.Compose([
        transforms.Resize((64, 64)),
        transforms.ToTensor(),
        transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5)),
    ])
    # Create train/val/test splits from training set
    print("Creating train/val/test splits from KITTI training images...", flush=True)
    train_ids, val_ids, test_ids = make_splits(KITTI_IMAGE_DIR, seed=0, train_ratio=0.8, val_ratio=0.1)
    print(f"Total images found: {len(train_ids) + len(val_ids) + len(test_ids)}", flush=True)
    print(f"Train: {len(train_ids)} | Val: {len(val_ids)} | Test: {len(test_ids)}", flush=True)
    # Create datasets
    print("Building PyTorch datasets...", flush=True)
    train_ds = KITTICarPresentDataset(KITTI_IMAGE_DIR, KITTI_LABEL_DIR, train_ids, transform=transform)
    val_ds   = KITTICarPresentDataset(KITTI_IMAGE_DIR, KITTI_LABEL_DIR, val_ids, transform=transform)
    test_ds  = KITTICarPresentDataset(KITTI_IMAGE_DIR, KITTI_LABEL_DIR, test_ids, transform=transform)
    # DataLoaders: num_workers=0 is safest on Windows
    train_loader = DataLoader(train_ds, batch_size=64, shuffle=True,  num_workers=0)
    val_loader   = DataLoader(val_ds,   batch_size=64, shuffle=False, num_workers=0)
    test_loader  = DataLoader(test_ds,  batch_size=64, shuffle=False, num_workers=0)
    # Quick sanity check: load 1 batch to ensure everything works
    print("Sanity check: loading the first training batch...", flush=True)
    t0 = time.perf_counter()
    x0, y0 = next(iter(train_loader))
    dt = time.perf_counter() - t0
    print(f"First batch loaded in {dt:.2f} seconds", flush=True)
    print(f"x batch shape: {tuple(x0.shape)}  (should be: (B,3,64,64))", flush=True)
    print(f"y batch shape: {tuple(y0.shape)}  example labels: {y0[:10].tolist()}", flush=True)
    # Model, optimizer, loss
    model = SmallCNN(num_classes=2).to(device)
    opt = optim.Adam(model.parameters(), lr=1e-3)
    loss_fn = nn.CrossEntropyLoss()
    # Training
    epochs = 3
    print("Starting training...", flush=True)
    for epoch in range(epochs):
        epoch_t0 = time.perf_counter()
        model.train()
        train_acc_sum = 0.0
        train_loss_sum = 0.0
        for x, y in train_loader:
            x, y = x.to(device), y.to(device)
            opt.zero_grad()
            logits = model(x)
            loss = loss_fn(logits, y)
            loss.backward()
            opt.step()
            train_loss_sum += loss.item()
            train_acc_sum += accuracy_from_logits(logits, y)
        train_acc = train_acc_sum / len(train_loader)
        train_loss = train_loss_sum / len(train_loader)
        # Validation
        model.eval()
        val_acc_sum = 0.0
        val_loss_sum = 0.0
        with torch.no_grad():
            for x, y in val_loader:
                x, y = x.to(device), y.to(device)
                logits = model(x)
                loss = loss_fn(logits, y)
                val_loss_sum += loss.item()
                val_acc_sum += accuracy_from_logits(logits, y)
        val_acc = val_acc_sum / len(val_loader)
        val_loss = val_loss_sum / len(val_loader)
        epoch_dt = time.perf_counter() - epoch_t0
        print(
            f"Epoch {epoch+1}/{epochs} | "
            f"train_loss={train_loss:.3f} train_acc={train_acc:.3f} | "
            f"val_loss={val_loss:.3f} val_acc={val_acc:.3f} | "
            f"time={epoch_dt:.1f}s",
            flush=True
        )
    # Save model
    out_path = "kitti_smallcnn.pt"
    torch.save(model.state_dict(), out_path)
    print(f"Saved: {out_path}", flush=True)
    # Final internal test accuracy
    model.eval()
    test_acc_sum = 0.0
    with torch.no_grad():
        for x, y in test_loader:
            x, y = x.to(device), y.to(device)
            logits = model(x)
            test_acc_sum += accuracy_from_logits(logits, y)
    test_acc = test_acc_sum / len(test_loader)
    print(f"Final internal test_acc={test_acc:.3f}", flush=True)
if __name__ == "__main__":
    # If something crashes, you will at least see "Script started..."
    run()