from pathlib import Path
import csv
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
OUTPUT_FOLDER = CURRENT_FOLDER / "full_test_results"
CSV_FILE = OUTPUT_FOLDER / "sequence_predictions.csv"
SUMMARY_FILE = OUTPUT_FOLDER / "summary.txt"
sys.path.insert(0, str(PROJECT_FOLDER))
from models import CNNGRU
# Settings
EXPECTED_SEQUENCE_LENGTH = 4
EXPECTED_FEATURE_SIZE = 8192
QUANTIZED_MINIMUM = 0
QUANTIZED_MAXIMUM = 255
BATCH_SIZE = 32
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
def quantize_and_dequantize(feature_sequences, a2_scale):
    quantized_features = torch.round(feature_sequences / a2_scale)
    quantized_features = torch.clamp(
        quantized_features,
        QUANTIZED_MINIMUM,
        QUANTIZED_MAXIMUM
    )
    quantized_features = quantized_features.to(torch.uint8)
    dequantized_features = quantized_features.float() * a2_scale
    return quantized_features, dequantized_features
def run_model_predictions(model, feature_sequences):
    all_predictions = []
    all_confidences = []
    all_logits = []
    with torch.no_grad():
        for start_index in range(0, len(feature_sequences), BATCH_SIZE):
            end_index = min(
                start_index + BATCH_SIZE,
                len(feature_sequences)
            )
            feature_batch = feature_sequences[start_index:end_index]
            output_logits = model(feature_batch)
            output_probabilities = torch.softmax(output_logits, dim=1)
            batch_predictions = torch.argmax(
                output_probabilities,
                dim=1
            )
            batch_confidences = output_probabilities.gather(
                1,
                batch_predictions.unsqueeze(1)
            ).squeeze(1)
            all_predictions.append(batch_predictions.cpu())
            all_confidences.append(batch_confidences.cpu())
            all_logits.append(output_logits.cpu())
    return (
        torch.cat(all_predictions),
        torch.cat(all_confidences),
        torch.cat(all_logits)
    )
def calculate_metrics(true_labels, predicted_labels):
    true_positive = int(
        ((predicted_labels == 1) & (true_labels == 1)).sum().item()
    )
    true_negative = int(
        ((predicted_labels == 0) & (true_labels == 0)).sum().item()
    )
    false_positive = int(
        ((predicted_labels == 1) & (true_labels == 0)).sum().item()
    )
    false_negative = int(
        ((predicted_labels == 0) & (true_labels == 1)).sum().item()
    )
    total_samples = len(true_labels)
    accuracy = (
        (true_positive + true_negative) / total_samples
        if total_samples > 0
        else 0.0
    )
    precision_denominator = true_positive + false_positive
    precision = (
        true_positive / precision_denominator
        if precision_denominator > 0
        else 0.0
    )
    recall_denominator = true_positive + false_negative
    recall = (
        true_positive / recall_denominator
        if recall_denominator > 0
        else 0.0
    )
    f1_denominator = precision + recall
    f1_score = (
        2.0 * precision * recall / f1_denominator
        if f1_denominator > 0
        else 0.0
    )
    return {
        "true_positive": true_positive,
        "true_negative": true_negative,
        "false_positive": false_positive,
        "false_negative": false_negative,
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall,
        "f1_score": f1_score
    }
def write_prediction_csv(
    true_labels,
    float_predictions,
    float_confidences,
    quantized_predictions,
    quantized_confidences,
    csv_file
):
    with open(csv_file, "w", newline="", encoding="utf-8") as output_handle:
        csv_writer = csv.writer(output_handle)
        csv_writer.writerow([
            "sequence_index",
            "true_label_index",
            "true_label",
            "float_prediction_index",
            "float_prediction",
            "float_confidence_percent",
            "quantized_prediction_index",
            "quantized_prediction",
            "quantized_confidence_percent",
            "prediction_preserved",
            "quantized_prediction_correct"
        ])
        for sequence_index in range(len(true_labels)):
            true_label = int(true_labels[sequence_index].item())
            float_prediction = int(float_predictions[sequence_index].item())
            quantized_prediction = int(
                quantized_predictions[sequence_index].item()
            )
            csv_writer.writerow([
                sequence_index,
                true_label,
                class_name(true_label),
                float_prediction,
                class_name(float_prediction),
                f"{float_confidences[sequence_index].item() * 100.0:.6f}",
                quantized_prediction,
                class_name(quantized_prediction),
                f"{quantized_confidences[sequence_index].item() * 100.0:.6f}",
                float_prediction == quantized_prediction,
                quantized_prediction == true_label
            ])
def metrics_to_lines(title, metrics):
    return [
        title,
        "-" * len(title),
        f"Accuracy:       {metrics['accuracy'] * 100.0:.2f}%",
        f"Precision:      {metrics['precision'] * 100.0:.2f}%",
        f"Recall:         {metrics['recall'] * 100.0:.2f}%",
        f"F1-score:       {metrics['f1_score'] * 100.0:.2f}%",
        f"True Positive:  {metrics['true_positive']}",
        f"True Negative:  {metrics['true_negative']}",
        f"False Positive: {metrics['false_positive']}",
        f"False Negative: {metrics['false_negative']}"
    ]
# Main evaluation
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
    OUTPUT_FOLDER.mkdir(parents=True, exist_ok=True)
    a2_scale = load_a2_scale()
    checkpoint = torch.load(MODEL_FILE, map_location="cpu")
    sequence_length = checkpoint["sequence_length"]
    feature_size = checkpoint["feature_size"]
    if sequence_length != EXPECTED_SEQUENCE_LENGTH:
        raise ValueError(
            "Unexpected CNN-GRU sequence length.\n"
            f"Expected: {EXPECTED_SEQUENCE_LENGTH}\n"
            f"Received: {sequence_length}"
        )
    if feature_size != EXPECTED_FEATURE_SIZE:
        raise ValueError(
            "Unexpected CNN-GRU feature size.\n"
            f"Expected: {EXPECTED_FEATURE_SIZE}\n"
            f"Received: {feature_size}"
        )
    model = CNNGRU(feature_size=feature_size)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    saved_test_data = torch.load(FEATURE_FILE, map_location="cpu")
    if "features" not in saved_test_data or "labels" not in saved_test_data:
        raise KeyError(
            "test_features.pt must contain both 'features' and 'labels'."
        )
    test_features = saved_test_data["features"].float()
    test_labels = saved_test_data["labels"].long()
    expected_shape = (
        len(test_features),
        EXPECTED_SEQUENCE_LENGTH,
        EXPECTED_FEATURE_SIZE
    )
    if tuple(test_features.shape) != expected_shape:
        raise ValueError(
            "Unexpected test-feature tensor shape.\n"
            f"Expected: {expected_shape}\n"
            f"Received: {tuple(test_features.shape)}"
        )
    print("\nRunning full float-feature evaluation...")
    (
        float_predictions,
        float_confidences,
        float_logits
    ) = run_model_predictions(
        model=model,
        feature_sequences=test_features
    )
    print("Quantizing and dequantizing all feature sequences...")
    quantized_features, dequantized_features = quantize_and_dequantize(
        feature_sequences=test_features,
        a2_scale=a2_scale
    )
    print("Running full FPGA-compatible quantized-feature evaluation...")
    (
        quantized_predictions,
        quantized_confidences,
        quantized_logits
    ) = run_model_predictions(
        model=model,
        feature_sequences=dequantized_features
    )
    float_metrics = calculate_metrics(
        true_labels=test_labels,
        predicted_labels=float_predictions
    )
    quantized_metrics = calculate_metrics(
        true_labels=test_labels,
        predicted_labels=quantized_predictions
    )
    prediction_preserved_count = int(
        (float_predictions == quantized_predictions).sum().item()
    )
    changed_prediction_count = len(test_labels) - prediction_preserved_count
    maximum_feature_difference = torch.max(
        torch.abs(test_features - dequantized_features)
    ).item()
    maximum_logit_difference = torch.max(
        torch.abs(float_logits - quantized_logits)
    ).item()
    quantized_minimum = int(quantized_features.min().item())
    quantized_maximum = int(quantized_features.max().item())
    write_prediction_csv(
        true_labels=test_labels,
        float_predictions=float_predictions,
        float_confidences=float_confidences,
        quantized_predictions=quantized_predictions,
        quantized_confidences=quantized_confidences,
        csv_file=CSV_FILE
    )
    summary_lines = [
        "Full CNN-GRU FPGA-Compatible Quantized Feature Evaluation",
        "=" * 62,
        f"Test sequences: {len(test_labels)}",
        f"Feature tensor shape: {tuple(test_features.shape)}",
        f"Activation scale (a2_scale): {a2_scale:.18f}",
        f"Quantized value range: {quantized_minimum} to {quantized_maximum}",
        f"Maximum feature difference: {maximum_feature_difference:.10f}",
        f"Maximum output-logit difference: {maximum_logit_difference:.10f}",
        "",
        *metrics_to_lines(
            "Original Float-Feature CNN-GRU Results",
            float_metrics
        ),
        "",
        *metrics_to_lines(
            "FPGA-Compatible Quantized-Feature CNN-GRU Results",
            quantized_metrics
        ),
        "",
        "Prediction Preservation",
        "-" * 23,
        f"Predictions preserved: {prediction_preserved_count}/{len(test_labels)}",
        f"Predictions changed: {changed_prediction_count}/{len(test_labels)}",
        f"Preservation rate: "
        f"{prediction_preserved_count / len(test_labels) * 100.0:.2f}%"
    ]
    with open(SUMMARY_FILE, "w", encoding="utf-8") as output_handle:
        output_handle.write("\n".join(summary_lines))
        output_handle.write("\n")
    print("\nFull Quantized CNN-GRU Test Results")
    print("=" * 62)
    for line in summary_lines[1:]:
        print(line)
    print("\nSaved files:")
    print(f"CSV:     {CSV_FILE}")
    print(f"Summary: {SUMMARY_FILE}")
if __name__ == "__main__":
    main()