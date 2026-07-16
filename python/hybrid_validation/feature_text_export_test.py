from pathlib import Path
import sys
import torch
# Paths
CURRENT_FOLDER = Path(__file__).resolve().parent
PROJECT_FOLDER = CURRENT_FOLDER.parent
MODEL_FILE = PROJECT_FOLDER / "cnn_gru_model.pt"
FEATURE_FILE = PROJECT_FOLDER / "prepared_features" / "test_features.pt"
EXPORT_FOLDER = CURRENT_FOLDER / "feature_text_files"
sys.path.insert(0, str(PROJECT_FOLDER))
from models import CNNGRU
# Settings
SEQUENCE_INDEX = 0
EXPECTED_SEQUENCE_LENGTH = 4
EXPECTED_FEATURE_SIZE = 8192
# Helper functions
def class_name(class_index):
    if class_index == 0:
        return "No car"
    if class_index == 1:
        return "Car present"
    return f"Unknown class ({class_index})"
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
def export_feature_sequence(feature_sequence, export_folder):
    export_folder.mkdir(parents=True, exist_ok=True)
    for frame_index in range(EXPECTED_SEQUENCE_LENGTH):
        frame_feature_vector = feature_sequence[0, frame_index, :]
        output_file = (
            export_folder /
            f"sequence_{SEQUENCE_INDEX:03d}_frame_{frame_index}_features.txt"
        )
        with open(output_file, "w", encoding="utf-8") as output_handle:
            for feature_value in frame_feature_vector:
                output_handle.write(f"{feature_value.item():.10f}\n")
        print(f"Exported: {output_file.name}")
def load_feature_sequence_from_text(export_folder):
    loaded_frames = []
    for frame_index in range(EXPECTED_SEQUENCE_LENGTH):
        input_file = (
            export_folder /
            f"sequence_{SEQUENCE_INDEX:03d}_frame_{frame_index}_features.txt"
        )
        if not input_file.exists():
            raise FileNotFoundError(
                f"Expected text feature file not found:\n{input_file}"
            )
        frame_values = []
        with open(input_file, "r", encoding="utf-8") as input_handle:
            for line in input_handle:
                stripped_line = line.strip()

                if stripped_line:
                    frame_values.append(float(stripped_line))
        if len(frame_values) != EXPECTED_FEATURE_SIZE:
            raise ValueError(
                f"Feature count mismatch in {input_file.name}\n"
                f"Expected: {EXPECTED_FEATURE_SIZE}\n"
                f"Received: {len(frame_values)}"
            )
        loaded_frames.append(
            torch.tensor(frame_values, dtype=torch.float32)
        )
    return torch.stack(loaded_frames, dim=0).unsqueeze(0)
# Main test
def main():
    if not MODEL_FILE.exists():
        raise FileNotFoundError(
            f"CNN-GRU model file not found:\n{MODEL_FILE}"
        )
    if not FEATURE_FILE.exists():
        raise FileNotFoundError(
            f"Prepared test feature file not found:\n{FEATURE_FILE}"
        )
    checkpoint = torch.load(MODEL_FILE, map_location="cpu")
    sequence_length = checkpoint["sequence_length"]
    feature_size = checkpoint["feature_size"]
    if sequence_length != EXPECTED_SEQUENCE_LENGTH:
        raise ValueError(
            f"Unexpected sequence length: {sequence_length}"
        )
    if feature_size != EXPECTED_FEATURE_SIZE:
        raise ValueError(
            f"Unexpected feature size: {feature_size}"
        )
    model = CNNGRU(feature_size=feature_size)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    saved_test_data = torch.load(FEATURE_FILE, map_location="cpu")
    test_features = saved_test_data["features"].float()
    test_labels = saved_test_data["labels"].long()
    selected_feature_sequence = test_features[
        SEQUENCE_INDEX:SEQUENCE_INDEX + 1
    ]
    selected_true_label = test_labels[SEQUENCE_INDEX].item()
    expected_shape = torch.Size([
        1,
        sequence_length,
        feature_size
    ])
    if selected_feature_sequence.shape != expected_shape:
        raise ValueError(
            "Original feature sequence shape mismatch.\n"
            f"Expected: {expected_shape}\n"
            f"Received: {selected_feature_sequence.shape}"
        )
    original_scores, original_prediction, original_confidence = (
        run_gru_inference(model, selected_feature_sequence)
    )
    print("\nExporting four CNN feature vectors to text files")
    print("=" * 56)
    export_feature_sequence(
        feature_sequence=selected_feature_sequence,
        export_folder=EXPORT_FOLDER
    )
    reloaded_feature_sequence = load_feature_sequence_from_text(
        export_folder=EXPORT_FOLDER
    )
    if reloaded_feature_sequence.shape != expected_shape:
        raise ValueError(
            "Reloaded feature sequence shape mismatch.\n"
            f"Expected: {expected_shape}\n"
            f"Received: {reloaded_feature_sequence.shape}"
        )
    reloaded_scores, reloaded_prediction, reloaded_confidence = (
        run_gru_inference(model, reloaded_feature_sequence)
    )
    maximum_feature_difference = torch.max(
        torch.abs(selected_feature_sequence - reloaded_feature_sequence)
    ).item()
    maximum_score_difference = torch.max(
        torch.abs(original_scores - reloaded_scores)
    ).item()
    print("\nCNN-GRU Text Feature Interface Test")
    print("=" * 56)
    print(f"Selected sequence index:        {SEQUENCE_INDEX}")
    print(f"Original sequence shape:         {selected_feature_sequence.shape}")
    print(f"Reloaded sequence shape:         {reloaded_feature_sequence.shape}")
    print(f"True class:                      {class_name(selected_true_label)}")
    print("-" * 56)
    print(f"Original prediction:             {class_name(original_prediction)}")
    print(f"Original confidence:             {original_confidence:.2f}%")
    print(f"Reloaded prediction:             {class_name(reloaded_prediction)}")
    print(f"Reloaded confidence:             {reloaded_confidence:.2f}%")
    print("-" * 56)
    print(f"Maximum feature difference:      {maximum_feature_difference:.10f}")
    print(f"Maximum output-score difference: {maximum_score_difference:.10f}")
    print(
        "Prediction preserved:           "
        f"{original_prediction == reloaded_prediction}"
    )
    print(
        "Prediction correct:              "
        f"{reloaded_prediction == selected_true_label}"
    )
if __name__ == "__main__":
    main()