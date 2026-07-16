from pathlib import Path
import json
import sys
import torch
# Exact paths
CURRENT_FOLDER = Path(__file__).resolve().parent
FEATURE_FILE = Path(
    r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework"
    r"\Codes\ML_Python\prepared_features\test_features.pt"
)
MODEL_FILE = Path(
    r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework"
    r"\Codes\ML_Python\cnn_gru_model.pt"
)
ACT_SCALES_FILE = Path(
    r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework"
    r"\Codes\Python_ML\exports\quant\W8_txt\act_scales.json"
)
PROJECT_FOLDER = MODEL_FILE.parent
EXPORT_FOLDER = CURRENT_FOLDER / "quantized_sequences"
sys.path.insert(0, str(PROJECT_FOLDER))
from models import CNNGRU
# Settings
SEQUENCE_INDEX = 0
EXPECTED_SEQUENCE_LENGTH = 4
EXPECTED_FEATURE_SIZE = 8192
QUANTIZED_MINIMUM = 0
QUANTIZED_MAXIMUM = 255
# Helper functions
def class_name(class_index):
    if class_index == 0:
        return "No car"
    if class_index == 1:
        return "Car present"
    return f"Unknown class ({class_index})"
def load_a2_scale():
    with open(ACT_SCALES_FILE, "r", encoding="utf-8") as input_handle:
        activation_scales = json.load(input_handle)
    if "a2_scale" not in activation_scales:
        raise KeyError("act_scales.json does not contain 'a2_scale'.")
    return float(activation_scales["a2_scale"])
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
    return output_scores, predicted_class, prediction_confidence
def quantize_feature_vector(float_feature_vector, a2_scale):
    quantized_feature_vector = torch.round(
        float_feature_vector / a2_scale
    )
    quantized_feature_vector = torch.clamp(
        quantized_feature_vector,
        QUANTIZED_MINIMUM,
        QUANTIZED_MAXIMUM
    )
    return quantized_feature_vector.to(torch.uint8)
def export_feature_vector_to_mem(
    quantized_feature_vector,
    output_file
):
    with open(output_file, "w", encoding="utf-8") as output_handle:
        for quantized_value in quantized_feature_vector:
            output_handle.write(f"{int(quantized_value.item()):02X}\n")
def load_feature_vector_from_mem(input_file):
    loaded_values = []
    with open(input_file, "r", encoding="utf-8") as input_handle:
        for line_number, line in enumerate(input_handle, start=1):
            stripped_value = line.strip()
            if not stripped_value:
                continue
            try:
                integer_value = int(stripped_value, 16)
            except ValueError as error:
                raise ValueError(
                    f"Invalid hexadecimal value in {input_file.name}, "
                    f"line {line_number}: {stripped_value}"
                ) from error
            if integer_value < QUANTIZED_MINIMUM:
                raise ValueError(
                    f"Negative value found in {input_file.name}, "
                    f"line {line_number}."
                )
            if integer_value > QUANTIZED_MAXIMUM:
                raise ValueError(
                    f"Value above 8-bit range in {input_file.name}, "
                    f"line {line_number}: {integer_value}"
                )
            loaded_values.append(integer_value)
    if len(loaded_values) != EXPECTED_FEATURE_SIZE:
        raise ValueError(
            f"Unexpected feature count in {input_file.name}.\n"
            f"Expected: {EXPECTED_FEATURE_SIZE}\n"
            f"Received: {len(loaded_values)}"
        )
    return torch.tensor(loaded_values, dtype=torch.float32)
def build_sequence_from_mem_files(export_folder, a2_scale):
    reloaded_frames = []
    for frame_index in range(EXPECTED_SEQUENCE_LENGTH):
        input_file = (
            export_folder /
            f"sequence_{SEQUENCE_INDEX:03d}_frame_{frame_index}.mem"
        )
        if not input_file.exists():
            raise FileNotFoundError(
                f"Expected memory file not found:\n{input_file}"
            )
        quantized_frame = load_feature_vector_from_mem(input_file)
        dequantized_frame = quantized_frame * a2_scale
        reloaded_frames.append(dequantized_frame)
    return torch.stack(reloaded_frames, dim=0).unsqueeze(0)
# Main test
def main():
    if not FEATURE_FILE.exists():
        raise FileNotFoundError(
            f"Test-feature file not found:\n{FEATURE_FILE}"
        )
    if not MODEL_FILE.exists():
        raise FileNotFoundError(
            f"CNN-GRU model file not found:\n{MODEL_FILE}"
        )
    if not ACT_SCALES_FILE.exists():
        raise FileNotFoundError(
            f"Activation-scale file not found:\n{ACT_SCALES_FILE}"
        )
    a2_scale = load_a2_scale()
    checkpoint = torch.load(MODEL_FILE, map_location="cpu")
    if checkpoint["sequence_length"] != EXPECTED_SEQUENCE_LENGTH:
        raise ValueError(
            "Unexpected CNN-GRU sequence length.\n"
            f"Expected: {EXPECTED_SEQUENCE_LENGTH}\n"
            f"Received: {checkpoint['sequence_length']}"
        )
    if checkpoint["feature_size"] != EXPECTED_FEATURE_SIZE:
        raise ValueError(
            "Unexpected CNN-GRU feature size.\n"
            f"Expected: {EXPECTED_FEATURE_SIZE}\n"
            f"Received: {checkpoint['feature_size']}"
        )
    model = CNNGRU(
        feature_size=checkpoint["feature_size"]
    )
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    saved_test_data = torch.load(FEATURE_FILE, map_location="cpu")
    if "features" not in saved_test_data or "labels" not in saved_test_data:
        raise KeyError(
            "test_features.pt must contain 'features' and 'labels'."
        )
    test_features = saved_test_data["features"].float()
    test_labels = saved_test_data["labels"].long()
    if SEQUENCE_INDEX >= len(test_features):
        raise IndexError(
            f"SEQUENCE_INDEX {SEQUENCE_INDEX} is outside the test set."
        )
    original_feature_sequence = test_features[
        SEQUENCE_INDEX:SEQUENCE_INDEX + 1
    ]
    true_label = test_labels[SEQUENCE_INDEX].item()
    expected_shape = torch.Size([
        1,
        EXPECTED_SEQUENCE_LENGTH,
        EXPECTED_FEATURE_SIZE
    ])
    if original_feature_sequence.shape != expected_shape:
        raise ValueError(
            "Unexpected original feature-sequence shape.\n"
            f"Expected: {expected_shape}\n"
            f"Received: {original_feature_sequence.shape}"
        )
    original_scores, original_prediction, original_confidence = (
        run_gru_inference(
            model=model,
            feature_sequence=original_feature_sequence
        )
    )
    EXPORT_FOLDER.mkdir(parents=True, exist_ok=True)
    quantized_frames = []
    for frame_index in range(EXPECTED_SEQUENCE_LENGTH):
        float_frame = original_feature_sequence[0, frame_index, :]
        quantized_frame = quantize_feature_vector(
            float_feature_vector=float_frame,
            a2_scale=a2_scale
        )
        output_file = (
            EXPORT_FOLDER /
            f"sequence_{SEQUENCE_INDEX:03d}_frame_{frame_index}.mem"
        )
        export_feature_vector_to_mem(
            quantized_feature_vector=quantized_frame,
            output_file=output_file
        )
        quantized_frames.append(quantized_frame)
    reloaded_feature_sequence = build_sequence_from_mem_files(
        export_folder=EXPORT_FOLDER,
        a2_scale=a2_scale
    )
    reloaded_scores, reloaded_prediction, reloaded_confidence = (
        run_gru_inference(
            model=model,
            feature_sequence=reloaded_feature_sequence
        )
    )
    maximum_feature_difference = torch.max(
        torch.abs(
            original_feature_sequence - reloaded_feature_sequence
        )
    ).item()
    maximum_output_difference = torch.max(
        torch.abs(original_scores - reloaded_scores)
    ).item()
    all_quantized_values = torch.cat(quantized_frames)
    print("\nQuantized Four-Frame CNN-GRU Sequence Test")
    print("=" * 60)
    print(f"Selected sequence index:        {SEQUENCE_INDEX}")
    print(f"True class:                     {class_name(true_label)}")
    print(f"Original sequence shape:         {original_feature_sequence.shape}")
    print(f"Reloaded sequence shape:         {reloaded_feature_sequence.shape}")
    print(f"Activation scale, a2_scale:      {a2_scale:.18f}")
    print(f"Memory export folder:            {EXPORT_FOLDER}")
    print("-" * 60)
    print(
        "Quantized value range:         "
        f"{int(all_quantized_values.min().item())} "
        f"to {int(all_quantized_values.max().item())}"
    )
    print(
        "Maximum feature difference:    "
        f"{maximum_feature_difference:.10f}"
    )
    print(
        "Maximum output-score difference:"
        f" {maximum_output_difference:.10f}"
    )
    print("-" * 60)
    print(
        f"Original prediction:            "
        f"{class_name(original_prediction)}"
    )
    print(f"Original confidence:            {original_confidence:.2f}%")
    print(
        f"Quantized prediction:           "
        f"{class_name(reloaded_prediction)}"
    )
    print(f"Quantized confidence:           {reloaded_confidence:.2f}%")
    print(
        "Prediction preserved:          "
        f"{original_prediction == reloaded_prediction}"
    )
    print(
        "Quantized prediction correct:  "
        f"{reloaded_prediction == true_label}"
    )
if __name__ == "__main__":
    main()