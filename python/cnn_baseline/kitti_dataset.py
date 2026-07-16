# Loads KITTI training images + KITTI label_2 text files.
import os
from typing import List, Tuple
import torch
from torch.utils.data import Dataset
from PIL import Image
def list_ids_from_images(image_dir: str) -> List[str]:
    """
    Returns list of sample IDs from filenames in image_dir.
    Example: 000000.png -> "000000"
    """
    if not os.path.isdir(image_dir):
        raise FileNotFoundError(f"Image directory not found: {image_dir}")
    ids = []
    for fn in os.listdir(image_dir):
        if fn.lower().endswith(".png"):
            ids.append(os.path.splitext(fn)[0])
    ids.sort()
    if len(ids) == 0:
        raise RuntimeError(f"No .png files found in: {image_dir}")
    return ids
def has_car(label_path: str) -> int:
    """
    Reads one KITTI label file.
    Returns 1 if any object class == 'Car', else 0.
    """
    if not os.path.exists(label_path):
        # For safety: if label missing, treat as "no car"
        return 0
    with open(label_path, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split()
            if not parts:
                continue
            cls = parts[0]
            if cls == "Car":
                return 1
    return 0
class KITTICarPresentDataset(Dataset):
    """
    PyTorch Dataset:
      __len__  -> number of samples
      __getitem__ -> returns (image_tensor, label_int)
    """
    def __init__(self, image_dir: str, label_dir: str, ids: List[str], transform=None):
        if not os.path.isdir(image_dir):
            raise FileNotFoundError(f"Image directory not found: {image_dir}")
        if not os.path.isdir(label_dir):
            raise FileNotFoundError(f"Label directory not found: {label_dir}")
        self.image_dir = image_dir
        self.label_dir = label_dir
        self.ids = ids
        self.transform = transform
    def __len__(self):
        return len(self.ids)
    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, int]:
        sample_id = self.ids[idx]
        img_path = os.path.join(self.image_dir, sample_id + ".png")
        lbl_path = os.path.join(self.label_dir, sample_id + ".txt")
        if not os.path.exists(img_path):
            raise FileNotFoundError(f"Missing image file: {img_path}")
        img = Image.open(img_path).convert("RGB")
        y = has_car(lbl_path)
        if self.transform is not None:
            img = self.transform(img)
        return img, y
def make_splits(image_dir: str, seed: int = 0, train_ratio: float = 0.8, val_ratio: float = 0.1):
    """
    Creates internal splits from KITTI training images (because official test has no labels).
    Returns train_ids, val_ids, test_ids.
    """
    ids = list_ids_from_images(image_dir)
    # Repeatable shuffle
    g = torch.Generator().manual_seed(seed)
    perm = torch.randperm(len(ids), generator=g).tolist()
    ids = [ids[i] for i in perm]
    n = len(ids)
    n_train = int(n * train_ratio)
    n_val = int(n * val_ratio)
    train_ids = ids[:n_train]
    val_ids = ids[n_train:n_train + n_val]
    test_ids = ids[n_train + n_val:]
    return train_ids, val_ids, test_ids