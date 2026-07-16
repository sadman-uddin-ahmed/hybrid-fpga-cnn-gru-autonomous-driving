from pathlib import Path
import json
import sys
import torch
# Paths
CURRENT_FOLDER = Path(__file__).resolve().parent
PROJECT_FOLDER = CURRENT_FOLDER.parent
MODEL_FILE = PROJECT_FOLDER / "cnn_gru_model.pt"
MEMORY_FILE = Path(
    r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework"
    r"\Codes\Verilog_HDL\cnn_fpga_accelerator\data\mem"
    r"\out_conv2_pool_int8_expected.mem"
)
ACT_SCALES_FILE = Path(
    r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework"
    r"\Codes\Python_ML\exports\quant\W8_txt"
    r"\act_scales.json"
)
EXPECTED_FEATURE_SIZE = 8192
EXPECTED_SEQUENCE_LENGTH = 4
sys.path.insert(0, str(PROJECT_FOLDER))
from models import CNNGRU
# Helper functions
def class_name(class_index):
    if class_index == 0:
        return "No car"
    if class_index == 1:
        return "Car present"
    return f"Unknown class ({class_index})"
def load_activation_scale(act_scales_file):
    with open(act_scales_file, "r", encoding="utf-8") as input_handle:
        activation_scales = json.load(input_handle)
    if "a2_scale" not in activation_scales:
        raise KeyError(
            "The activation-scale file does not contain 'a2_scale'."
        )
    return float(activation_scales["a2_scale"])
def load_unsigned_int8_memory(memory_file):
    quantized_values = []
    with open(memory_file, "r", encoding="utf-8") as input_handle:
        for line_number, line in enumerate(input_handle, start=1):
            hex_value = line.strip()
            if not hex_value:
                continue
            try:
                integer_value = int(hex_value, 16)
            except ValueError as error:
                raise ValueError(
                    f"Invalid hexadecimal value at line {line_number}: "
                    f"'{hex_value}'"
                ) from error
            if integer_value < 0 or integer_value > 255:
                raise ValueError(
                    f"Value outside unsigned 8-bit range at line "
                    f"{line_number}: {integer_value}"
                )
            quantized_values.append(integer_value)
    if len(quantized_values) != EXPECTED_FEATURE_SIZE:
        raise ValueError(
            "Unexpected feature count in FPGA memory file.\n"
            f"Expected: {EXPECTED_FEATURE_SIZE}\n"
            f"Received: {len(quantized_values)}"
        )
    return torch.tensor(quantized_values, dtype=torch.float32)
def run_gru_inference(model, feature_sequence):
    with torch.no_grad():
        output_scores = model(feature_sequence)
        output_probabilities = torch.softmax(output_scores, dim=1)
        predicted_class = torch.argmax(
            output_probabilities,
            dim=1
        ).item()
        prediction_confidence = (
            output_probabilities[0, predicted_class].item() * 100.0
        )
    return predicted_class, prediction_confidence, output_probabilities
# Main check
def main():
    if not MODEL_FILE.exists():
        raise FileNotFoundError(
            f"CNN-GRU model file not found:\n{MODEL_FILE}"
        )
    if not MEMORY_FILE.exists():
        raise FileNotFoundError(
            f"FPGA output memory file not found:\n{MEMORY_FILE}"
        )
    if not ACT_SCALES_FILE.exists():
        raise FileNotFoundError(
            f"Activation-scale file not found:\n{ACT_SCALES_FILE}"
        )
    a2_scale = load_activation_scale(ACT_SCALES_FILE)
    quantized_feature_vector = load_unsigned_int8_memory(MEMORY_FILE)
    dequantized_feature_vector = quantized_feature_vector * a2_scale
    fpga_feature_sequence = (
        dequantized_feature_vector
        .unsqueeze(0)
        .unsqueeze(0)
        .repeat(1, EXPECTED_SEQUENCE_LENGTH, 1)
    )
    expected_shape = torch.Size([
        1,
        EXPECTED_SEQUENCE_LENGTH,
        EXPECTED_FEATURE_SIZE
    ])
    if fpga_feature_sequence.shape != expected_shape:
        raise ValueError(
            "FPGA feature sequence shape mismatch.\n"
            f"Expected: {expected_shape}\n"
            f"Received: {fpga_feature_sequence.shape}"
        )
    checkpoint = torch.load(MODEL_FILE, map_location="cpu")
    model = CNNGRU(
        feature_size=checkpoint["feature_size"]
    )
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    predicted_class, confidence, probabilities = run_gru_inference(
        model=model,
        feature_sequence=fpga_feature_sequence
    )
    print("\nFPGA Quantized Feature Check")
    print("=" * 56)
    print(f"Memory file:                 {MEMORY_FILE.name}")
    print(f"Scale file:                  {ACT_SCALES_FILE.name}")
    print(f"Stored feature count:         {len(quantized_feature_vector)}")
    print("Stored representation:        unsigned 8-bit hexadecimal")
    print(f"Activation scale, a2_scale:   {a2_scale:.18f}")
    print(f"Rebuilt sequence shape:       {fpga_feature_sequence.shape}")
    print("-" * 56)
    print(
        "Quantized value range:        "
        f"{int(quantized_feature_vector.min().item())} "
        f"to {int(quantized_feature_vector.max().item())}"
    )
    print(
        "Dequantized value range:      "
        f"{dequantized_feature_vector.min().item():.8f} "
        f"to {dequantized_feature_vector.max().item():.8f}"
    )
    print("-" * 56)
    print(f"Predicted class:              {class_name(predicted_class)}")
    print(f"Prediction confidence:        {confidence:.2f}%")
    print(
        "No-car probability:           "
        f"{probabilities[0, 0].item() * 100.0:.2f}%"
    )
    print(
        "Car-present probability:      "
        f"{probabilities[0, 1].item() * 100.0:.2f}%"
    )
if __name__ == "__main__":
    main()