from pathlib import Path
import sys
import torch
# Paths
CURRENT_FOLDER = Path(__file__).resolve().parent
PROJECT_FOLDER = CURRENT_FOLDER.parent
MODEL_FILE = PROJECT_FOLDER / "cnn_gru_model.pt"
FEATURE_FILE = PROJECT_FOLDER / "prepared_features" / "test_features.pt"
# Allows this file, inside Hybrid_GRU, to import models.py
# from the main ML_Python folder.
sys.path.insert(0, str(PROJECT_FOLDER))
from models import CNNGRU
# Settings
SEQUENCE_INDEX = 0
EXPECTED_SEQUENCE_LENGTH = 4
EXPECTED_FEATURE_SIZE = 8192
# Helper function
def class_name(class_index):
    if class_index == 0:
        return "No car"
    if class_index == 1:
        return "Car present"
    return f"Unknown class ({class_index})"
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
    if "model_state_dict" not in checkpoint:
        raise KeyError(
            "The CNN-GRU checkpoint does not contain 'model_state_dict'."
        )
    if "sequence_length" not in checkpoint:
        raise KeyError(
            "The CNN-GRU checkpoint does not contain 'sequence_length'."
        )
    if "feature_size" not in checkpoint:
        raise KeyError(
            "The CNN-GRU checkpoint does not contain 'feature_size'."
        )
    sequence_length = checkpoint["sequence_length"]
    feature_size = checkpoint["feature_size"]
    if sequence_length != EXPECTED_SEQUENCE_LENGTH:
        raise ValueError(
            f"Unexpected sequence length: {sequence_length}\n"
            f"Expected: {EXPECTED_SEQUENCE_LENGTH}"
        )
    if feature_size != EXPECTED_FEATURE_SIZE:
        raise ValueError(
            f"Unexpected feature size: {feature_size}\n"
            f"Expected: {EXPECTED_FEATURE_SIZE}"
        )
    model = CNNGRU(
        feature_size=feature_size
    )
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    saved_test_data = torch.load(FEATURE_FILE, map_location="cpu")
    if "features" not in saved_test_data or "labels" not in saved_test_data:
        raise KeyError(
            "The test feature file must contain both 'features' and 'labels'."
        )
    test_features = saved_test_data["features"].float()
    test_labels = saved_test_data["labels"].long()

    if SEQUENCE_INDEX >= len(test_features):
        raise IndexError(
            f"SEQUENCE_INDEX {SEQUENCE_INDEX} is outside the test dataset."
        )
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
            "Feature sequence shape mismatch.\n"
            f"Expected: {expected_shape}\n"
            f"Received: {selected_feature_sequence.shape}"
        )
    with torch.no_grad():
        output_scores = model(selected_feature_sequence)
        output_probabilities = torch.softmax(output_scores, dim=1)

        predicted_class = torch.argmax(
            output_probabilities,
            dim=1
        ).item()
        prediction_confidence = (
            output_probabilities[0, predicted_class].item() * 100.0
        )
    print("\nCNN-GRU Feature Sequence Interface Test")
    print("=" * 48)
    print(f"Model file:              {MODEL_FILE.name}")
    print(f"Feature file:            {FEATURE_FILE.name}")
    print(f"Model name:              {checkpoint['model_name']}")
    print(f"Best validation accuracy:{checkpoint['best_val_accuracy'] * 100:.2f}%")
    print(f"Best epoch:              {checkpoint['best_epoch']}")
    print("-" * 48)
    print(f"Selected sequence index: {SEQUENCE_INDEX}")
    print(f"Feature sequence shape:  {selected_feature_sequence.shape}")
    print(f"True class:              {class_name(selected_true_label)}")
    print(f"Predicted class:         {class_name(predicted_class)}")
    print(f"Confidence:              {prediction_confidence:.2f}%")
    print(f"Prediction correct:      {predicted_class == selected_true_label}")
if __name__ == "__main__":
    main()