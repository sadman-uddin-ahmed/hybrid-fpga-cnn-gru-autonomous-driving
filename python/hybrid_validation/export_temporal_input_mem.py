from pathlib import Path
import json
import sys
import torch
from PIL import Image
from torchvision import transforms
# Exact project paths
ML_PYTHON_FOLDER = Path(
    r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework"
    r"\Codes\ML_Python"
)
HYBRID_GRU_FOLDER = ML_PYTHON_FOLDER / "Hybrid_GRU"
IMAGE_DIRECTORY = Path(
    r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework"
    r"\Datasets\KITTI_Dataset_3D_Object_Detection"
    r"\Data_Object_Image_Left\training\image_2"
)
FIXEDPOINT_META_FILE = Path(
    r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework"
    r"\Codes\Verilog_HDL\cnn_fpga_accelerator\data\quant\W8_txt"
    r"\fixedpoint_meta.json"
)
OUTPUT_FOLDER = Path(
    r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework"
    r"\Codes\Verilog_HDL\cnn_fpga_accelerator\data\mem"
    r"\temporal_inputs"
)
SEQUENCE_INDEX = 0
EXPECTED_SEQUENCE_LENGTH = 4
EXPECTED_IMAGE_SIZE = 64
EXPECTED_VALUES_PER_FRAME = 3 * EXPECTED_IMAGE_SIZE * EXPECTED_IMAGE_SIZE
# Import existing Stage-03 split logic
sys.path.insert(0, str(ML_PYTHON_FOLDER))
from sequence_dataset import (
    IMAGE_DIR,
    LABEL_DIR,
    IMAGE_SIZE,
    SEQUENCE_LENGTH,
    TRAIN_RATIO,
    VAL_RATIO,
    TEST_RATIO,
    KITTITemporalDataset,
    create_stratified_splits
)
# Helper functions
def load_a0_scale():
    with open(FIXEDPOINT_META_FILE, "r", encoding="utf-8") as input_handle:
        fixedpoint_meta = json.load(input_handle)
    if "a0_scale" not in fixedpoint_meta:
        raise KeyError(
            "fixedpoint_meta.json does not contain 'a0_scale'."
        )
    return float(fixedpoint_meta["a0_scale"])
def convert_image_to_stage02_int8(image_path, a0_scale):
    image_transform = transforms.Compose([
        transforms.Resize((EXPECTED_IMAGE_SIZE, EXPECTED_IMAGE_SIZE)),
        transforms.ToTensor()
    ])
    image = Image.open(image_path).convert("RGB")
    image_tensor = image_transform(image)
    if tuple(image_tensor.shape) != (
        3,
        EXPECTED_IMAGE_SIZE,
        EXPECTED_IMAGE_SIZE
    ):
        raise ValueError(
            "Unexpected image tensor shape.\n"
            f"Expected: (3, {EXPECTED_IMAGE_SIZE}, {EXPECTED_IMAGE_SIZE})\n"
            f"Received: {tuple(image_tensor.shape)}"
        )
    quantized_tensor = torch.round(image_tensor / a0_scale)
    quantized_tensor = torch.clamp(
        quantized_tensor,
        min=-128,
        max=127
    ).to(torch.int16)
    flattened_chw_values = quantized_tensor.reshape(-1)
    if len(flattened_chw_values) != EXPECTED_VALUES_PER_FRAME:
        raise ValueError(
            "Unexpected flattened image length.\n"
            f"Expected: {EXPECTED_VALUES_PER_FRAME}\n"
            f"Received: {len(flattened_chw_values)}"
        )
    return flattened_chw_values
def write_signed_int8_mem_file(quantized_values, output_file):
    with open(output_file, "w", encoding="utf-8") as output_handle:
        for signed_value in quantized_values:
            unsigned_byte_value = int(signed_value.item()) & 0xFF
            output_handle.write(f"{unsigned_byte_value:02X}\n")
# Main export
def main():
    if not ML_PYTHON_FOLDER.exists():
        raise FileNotFoundError(
            f"ML_Python folder not found:\n{ML_PYTHON_FOLDER}"
        )
    if not IMAGE_DIRECTORY.exists():
        raise FileNotFoundError(
            f"KITTI image directory not found:\n{IMAGE_DIRECTORY}"
        )
    if not FIXEDPOINT_META_FILE.exists():
        raise FileNotFoundError(
            f"fixedpoint_meta.json not found:\n{FIXEDPOINT_META_FILE}"
        )
    if IMAGE_SIZE != EXPECTED_IMAGE_SIZE:
        raise ValueError(
            f"Stage-03 image size mismatch: {IMAGE_SIZE}"
        )
    if SEQUENCE_LENGTH != EXPECTED_SEQUENCE_LENGTH:
        raise ValueError(
            f"Stage-03 sequence length mismatch: {SEQUENCE_LENGTH}"
        )
    a0_scale = load_a0_scale()
    dataset = KITTITemporalDataset(
        image_dir=IMAGE_DIR,
        label_dir=LABEL_DIR,
        sequence_length=SEQUENCE_LENGTH,
        image_size=IMAGE_SIZE
    )
    _, _, test_indices = create_stratified_splits(
        dataset=dataset,
        train_ratio=TRAIN_RATIO,
        val_ratio=VAL_RATIO,
        test_ratio=TEST_RATIO
    )
    if SEQUENCE_INDEX >= len(test_indices):
        raise IndexError(
            f"SEQUENCE_INDEX {SEQUENCE_INDEX} is outside the test split."
        )
    dataset_index = test_indices[SEQUENCE_INDEX]
    frame_start_index = dataset.sequence_start_indices[dataset_index]
    OUTPUT_FOLDER.mkdir(parents=True, exist_ok=True)
    print("\nTemporal FPGA Input Export")
    print("=" * 60)
    print(f"Stage-03 test sequence index: {SEQUENCE_INDEX}")
    print(f"Original dataset index:        {dataset_index}")
    print(f"Frame start index:             {frame_start_index}")
    print(f"Input scale, a0_scale:         {a0_scale:.18f}")
    print(f"Output folder:                 {OUTPUT_FOLDER}")
    print("-" * 60)
    for frame_position in range(EXPECTED_SEQUENCE_LENGTH):
        image_index = frame_start_index + frame_position
        image_file_name = dataset.image_files[image_index]
        image_path = Path(dataset.image_dir) / image_file_name
        quantized_values = convert_image_to_stage02_int8(
            image_path=image_path,
            a0_scale=a0_scale
        )
        output_file = (
            OUTPUT_FOLDER /
            f"sequence_{SEQUENCE_INDEX:03d}_frame_{frame_position}_input.mem"
        )
        write_signed_int8_mem_file(
            quantized_values=quantized_values,
            output_file=output_file
        )
        print(f"Frame {frame_position}:")
        print(f"  Source image: {image_file_name}")
        print(f"  Output file:  {output_file.name}")
        print(
            "  Quantized range: "
            f"{int(quantized_values.min().item())} "
            f"to {int(quantized_values.max().item())}"
        )
        print(f"  Stored values: {len(quantized_values)}")
    print("-" * 60)
    print("Export completed successfully.")
if __name__ == "__main__":
    main()