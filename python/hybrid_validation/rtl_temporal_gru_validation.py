"""
Stage-04 hybrid validation:
RTL-verified temporal CNN feature files -> dequantization -> saved CNN-GRU inference.

This script does not run Vivado and does not change any Verilog files.
It reads the four fixed-point expected feature files that were individually
matched against the Stage-02 RTL CNN output stream, reconstructs the temporal
sequence in BRAM order, and evaluates the saved Stage-03 CNN-GRU model.
"""
from __future__ import annotations
import hashlib
import importlib.util
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable, Optional
import torch
FEATURES_PER_FRAME = 8192
SEQUENCE_LENGTH = 4
CLASS_NAMES = {
    0: "No car",
    1: "Car present",
}
SCRIPT_FOLDER = Path(__file__).resolve().parent
ML_PYTHON_FOLDER = SCRIPT_FOLDER.parent
CODES_FOLDER = ML_PYTHON_FOLDER.parent
TEMPORAL_INPUT_FOLDER = (
    CODES_FOLDER
    / "Verilog_HDL"
    / "cnn_fpga_accelerator"
    / "data"
    / "mem"
    / "temporal_inputs"
)
OUTPUT_FEATURE_FILE = (
    SCRIPT_FOLDER
    / "rtl_verified_sequence_000_features.pt"
)
OUTPUT_SUMMARY_FILE = (
    SCRIPT_FOLDER
    / "hybrid_sequence_000_results.txt"
)
def unique_paths(paths: Iterable[Path]) -> list[Path]:
    """Return existing candidate paths without duplicates."""
    seen_paths: set[str] = set()
    unique_existing_paths: list[Path] = []
    for candidate_path in paths:
        try:
            resolved_path = candidate_path.resolve()
        except OSError:
            resolved_path = candidate_path
        resolved_string = str(resolved_path).lower()
        if resolved_string in seen_paths:
            continue
        seen_paths.add(resolved_string)
        if candidate_path.is_file():
            unique_existing_paths.append(candidate_path)
    return unique_existing_paths
def find_file_by_name(
    root_folder: Path,
    file_name: str,
    required_text: Optional[str] = None,
) -> Optional[Path]:
    """Find the first matching file below root_folder."""
    if not root_folder.exists():
        return None
    for candidate_path in sorted(root_folder.rglob(file_name)):
        if not candidate_path.is_file():
            continue
        if required_text is not None:
            try:
                file_text = candidate_path.read_text(
                    encoding="utf-8",
                    errors="ignore",
                )
            except OSError:
                continue
            if required_text not in file_text:
                continue
        return candidate_path
    return None
def choose_required_file(
    description: str,
    direct_candidates: Iterable[Path],
    search_root: Optional[Path] = None,
    search_name: Optional[str] = None,
    required_text: Optional[str] = None,
) -> Path:
    """Choose a required file from direct candidates or a recursive search."""
    existing_candidates = unique_paths(direct_candidates)

    if existing_candidates:
        return existing_candidates[0]
    if search_root is not None and search_name is not None:
        found_path = find_file_by_name(
            root_folder=search_root,
            file_name=search_name,
            required_text=required_text,
        )
        if found_path is not None:
            return found_path
    candidate_text = "\n".join(
        f"  - {candidate_path}" for candidate_path in direct_candidates
    )
    raise FileNotFoundError(
        f"Could not find {description}.\n"
        f"Checked:\n{candidate_text}"
    )
def choose_optional_file(
    direct_candidates: Iterable[Path],
    search_root: Optional[Path] = None,
    search_name: Optional[str] = None,
) -> Optional[Path]:
    """Choose an optional file without failing when it is unavailable."""
    existing_candidates = unique_paths(direct_candidates)
    if existing_candidates:
        return existing_candidates[0]
    if search_root is not None and search_name is not None:
        return find_file_by_name(
            root_folder=search_root,
            file_name=search_name,
        )
    return None
def load_torch_object(file_path: Path) -> Any:
    """Load a PyTorch file while supporting current and older PyTorch APIs."""
    try:
        return torch.load(
            file_path,
            map_location="cpu",
            weights_only=False,
        )
    except TypeError:
        return torch.load(
            file_path,
            map_location="cpu",
        )
def import_cnn_gru_model(model_definition_path: Path) -> Any:
    """Import CNNGRU from the supplied Stage-03 models.py file."""
    module_name = "stage04_cnn_gru_models"
    specification = importlib.util.spec_from_file_location(
        module_name,
        model_definition_path,
    )
    if specification is None or specification.loader is None:
        raise ImportError(
            f"Could not load model definition file: {model_definition_path}"
        )
    imported_module = importlib.util.module_from_spec(specification)
    sys.modules[module_name] = imported_module
    specification.loader.exec_module(imported_module)
    if not hasattr(imported_module, "CNNGRU"):
        raise AttributeError(
            "The selected models.py does not contain the CNNGRU class."
        )
    return imported_module.CNNGRU
def read_unsigned_int8_mem_file(file_path: Path) -> torch.Tensor:
    """Read one 8192-value unsigned hexadecimal feature-memory file."""
    feature_values: list[int] = []
    with file_path.open("r", encoding="utf-8") as feature_file:
        for raw_line in feature_file:
            stripped_line = raw_line.strip()
            if not stripped_line:
                continue
            if stripped_line.startswith("//"):
                continue
            feature_value = int(stripped_line, 16)
            if feature_value < 0 or feature_value > 255:
                raise ValueError(
                    f"Value {feature_value} is outside unsigned int8 range "
                    f"in {file_path.name}."
                )
            feature_values.append(feature_value)
    if len(feature_values) != FEATURES_PER_FRAME:
        raise ValueError(
            f"{file_path.name} has {len(feature_values)} values. "
            f"Expected {FEATURES_PER_FRAME}."
        )
    return torch.tensor(
        feature_values,
        dtype=torch.float32,
    )
def calculate_sha256(file_path: Path) -> str:
    """Calculate the SHA-256 digest of a source feature file."""
    file_hash = hashlib.sha256()
    with file_path.open("rb") as binary_file:
        for file_chunk in iter(lambda: binary_file.read(65536), b""):
            file_hash.update(file_chunk)

    return file_hash.hexdigest()
def select_act_scales_file() -> Path:
    """Find the Stage-01/Stage-02 activation-scale metadata."""
    direct_candidates = [
        CODES_FOLDER
        / "Python_ML"
        / "exports"
        / "quant"
        / "W8_txt"
        / "act_scales.json",
        CODES_FOLDER
        / "ML_Python"
        / "exports"
        / "quant"
        / "W8_txt"
        / "act_scales.json",
    ]
    return choose_required_file(
        description="activation-scale metadata (act_scales.json)",
        direct_candidates=direct_candidates,
        search_root=CODES_FOLDER,
        search_name="act_scales.json",
        required_text="a2_scale",
    )
def main() -> None:
    print("Stage-04 Hybrid CNN-GRU Validation")
    print("=" * 68)
    print("Source: RTL-verified temporal CNN feature sequence")
    print("Sequence: 000, frames 0 to 3")
    print()
    expected_feature_files = [
        TEMPORAL_INPUT_FOLDER
        / f"sequence_000_frame_{frame_index}_expected.mem"
        for frame_index in range(SEQUENCE_LENGTH)
    ]
    for feature_file in expected_feature_files:
        if not feature_file.is_file():
            raise FileNotFoundError(
                f"Required RTL-verified feature file not found:\n{feature_file}"
            )
    act_scales_path = select_act_scales_file()
    with act_scales_path.open("r", encoding="utf-8") as metadata_file:
        act_scales = json.load(metadata_file)
    if "a2_scale" not in act_scales:
        raise KeyError(
            f"a2_scale was not found in:\n{act_scales_path}"
        )
    a2_scale = float(act_scales["a2_scale"])
    model_definition_path = choose_required_file(
        description="Stage-03 CNN-GRU model definition (models.py)",
        direct_candidates=[
            ML_PYTHON_FOLDER / "models.py",
            SCRIPT_FOLDER / "models.py",
        ],
        search_root=ML_PYTHON_FOLDER,
        search_name="models.py",
        required_text="class CNNGRU",
    )
    checkpoint_path = choose_required_file(
        description="saved CNN-GRU checkpoint (cnn_gru_model.pt)",
        direct_candidates=[
            ML_PYTHON_FOLDER / "cnn_gru_model.pt",
            SCRIPT_FOLDER / "cnn_gru_model.pt",
        ],
        search_root=ML_PYTHON_FOLDER,
        search_name="cnn_gru_model.pt",
    )
    reference_test_feature_path = choose_optional_file(
        direct_candidates=[
            ML_PYTHON_FOLDER
            / "prepared_features"
            / "test_features.pt",
        ],
        search_root=ML_PYTHON_FOLDER,
        search_name="test_features.pt",
    )
    print(f"Temporal feature folder: {TEMPORAL_INPUT_FOLDER}")
    print(f"Activation metadata:     {act_scales_path}")
    print(f"CNN-GRU model file:      {model_definition_path}")
    print(f"CNN-GRU checkpoint:      {checkpoint_path}")
    print(f"Conv2 output scale:      {a2_scale:.15f}")
    print("-" * 68)
    quantized_frames: list[torch.Tensor] = []
    for frame_index, feature_file in enumerate(expected_feature_files):
        quantized_frame = read_unsigned_int8_mem_file(feature_file)
        quantized_frames.append(quantized_frame)
        print(
            f"Frame {frame_index}: "
            f"values={quantized_frame.numel()}, "
            f"range={int(quantized_frame.min().item())}"
            f"..{int(quantized_frame.max().item())}, "
            f"sha256={calculate_sha256(feature_file)}"
        )
    quantized_sequence = torch.stack(
        quantized_frames,
        dim=0,
    )
    hybrid_feature_sequence = (
        quantized_sequence * a2_scale
    ).unsqueeze(0)
    if hybrid_feature_sequence.shape != (
        1,
        SEQUENCE_LENGTH,
        FEATURES_PER_FRAME,
    ):
        raise RuntimeError(
            f"Unexpected hybrid feature sequence shape: "
            f"{tuple(hybrid_feature_sequence.shape)}"
        )
    CNNGRU = import_cnn_gru_model(model_definition_path)
    checkpoint_data = load_torch_object(checkpoint_path)
    if "model_state_dict" not in checkpoint_data:
        raise KeyError(
            f"model_state_dict was not found in checkpoint:\n{checkpoint_path}"
        )
    model = CNNGRU()
    model.load_state_dict(checkpoint_data["model_state_dict"])
    model.eval()
    with torch.no_grad():
        hybrid_logits = model(hybrid_feature_sequence)
        hybrid_probabilities = torch.softmax(
            hybrid_logits,
            dim=1,
        )
        hybrid_prediction = int(
            torch.argmax(hybrid_probabilities, dim=1).item()
        )
    hybrid_prediction_name = CLASS_NAMES[hybrid_prediction]
    hybrid_confidence = float(
        hybrid_probabilities[0, hybrid_prediction].item() * 100.0
    )
    print("-" * 68)
    print(
        "Reconstructed temporal tensor shape: "
        f"{tuple(hybrid_feature_sequence.shape)}"
    )
    print(
        f"Hybrid CNN-GRU prediction: {hybrid_prediction_name} "
        f"({hybrid_confidence:.2f}%)"
    )
    reference_summary_lines: list[str] = []
    if reference_test_feature_path is not None:
        reference_data = load_torch_object(reference_test_feature_path)
        if "features" not in reference_data or "labels" not in reference_data:
            raise KeyError(
                "test_features.pt does not contain both features and labels."
            )
        original_feature_sequence = (
            reference_data["features"][0]
            .float()
            .unsqueeze(0)
        )
        true_label = int(reference_data["labels"][0].item())
        true_label_name = CLASS_NAMES[true_label]
        with torch.no_grad():
            original_logits = model(original_feature_sequence)
            original_probabilities = torch.softmax(
                original_logits,
                dim=1,
            )
            original_prediction = int(
                torch.argmax(original_probabilities, dim=1).item()
            )
        original_prediction_name = CLASS_NAMES[original_prediction]
        original_confidence = float(
            original_probabilities[0, original_prediction].item() * 100.0
        )
        max_feature_difference = float(
            torch.max(
                torch.abs(
                    hybrid_feature_sequence -
                    original_feature_sequence
                )
            ).item()
        )
        mean_feature_difference = float(
            torch.mean(
                torch.abs(
                    hybrid_feature_sequence -
                    original_feature_sequence
                )
            ).item()
        )
        max_logit_difference = float(
            torch.max(
                torch.abs(
                    hybrid_logits -
                    original_logits
                )
            ).item()
        )
        prediction_preserved = (
            hybrid_prediction == original_prediction
        )
        hybrid_correct = (
            hybrid_prediction == true_label
        )
        print(
            f"Original Stage-03 sequence prediction: "
            f"{original_prediction_name} ({original_confidence:.2f}%)"
        )
        print(f"Ground-truth label: {true_label_name}")
        print(
            "Maximum feature difference: "
            f"{max_feature_difference:.10f}"
        )
        print(
            "Mean feature difference: "
            f"{mean_feature_difference:.10f}"
        )
        print(
            "Maximum logit difference: "
            f"{max_logit_difference:.10f}"
        )
        print(
            "Prediction preservation: "
            f"{'PASS' if prediction_preserved else 'FAIL'}"
        )
        print(
            "Hybrid classification: "
            f"{'CORRECT' if hybrid_correct else 'INCORRECT'}"
        )
        reference_summary_lines.extend([
            f"Reference test-feature file: {reference_test_feature_path}",
            f"Ground-truth label: {true_label} ({true_label_name})",
            (
                "Original Stage-03 prediction: "
                f"{original_prediction} ({original_prediction_name})"
            ),
            f"Original confidence: {original_confidence:.6f}%",
            (
                "Maximum feature difference: "
                f"{max_feature_difference:.10f}"
            ),
            (
                "Mean feature difference: "
                f"{mean_feature_difference:.10f}"
            ),
            (
                "Maximum logit difference: "
                f"{max_logit_difference:.10f}"
            ),
            (
                "Prediction preservation: "
                f"{'PASS' if prediction_preserved else 'FAIL'}"
            ),
            (
                "Hybrid classification correctness: "
                f"{'CORRECT' if hybrid_correct else 'INCORRECT'}"
            ),
        ])
    else:
        print(
            "Reference test_features.pt was not found; "
            "the hybrid result was generated without a float-feature comparison."
        )
        reference_summary_lines.append(
            "Reference test_features.pt: not found; "
            "no float-feature comparison was performed."
        )
    torch.save(
        {
            "features": hybrid_feature_sequence.cpu(),
            "sequence_length": SEQUENCE_LENGTH,
            "feature_size": FEATURES_PER_FRAME,
            "a2_scale": a2_scale,
            "source_type": (
                "RTL-verified fixed-point Conv2-ReLU-MaxPool "
                "feature sequence"
            ),
            "source_files": [
                str(feature_file)
                for feature_file in expected_feature_files
            ],
            "prediction": hybrid_prediction,
            "prediction_name": hybrid_prediction_name,
            "confidence_percent": hybrid_confidence,
        },
        OUTPUT_FEATURE_FILE,
    )
    summary_lines = [
        "Stage-04 Hybrid CNN-GRU Validation",
        "=" * 68,
        (
            "Validation source: four RTL-verified fixed-point "
            "Conv2-ReLU-MaxPool output vectors"
        ),
        "Sequence: 000, frames 0 to 3",
        f"Generated: {datetime.now().isoformat(timespec='seconds')}",
        "",
        f"Temporal feature folder: {TEMPORAL_INPUT_FOLDER}",
        f"Activation metadata: {act_scales_path}",
        f"CNN-GRU model definition: {model_definition_path}",
        f"CNN-GRU checkpoint: {checkpoint_path}",
        f"Conv2 output scale (a2_scale): {a2_scale:.15f}",
        "",
        f"Hybrid feature tensor shape: {tuple(hybrid_feature_sequence.shape)}",
        (
            "Hybrid CNN-GRU prediction: "
            f"{hybrid_prediction} ({hybrid_prediction_name})"
        ),
        f"Hybrid confidence: {hybrid_confidence:.6f}%",
        "",
        "Expected feature source files:",
    ]
    for feature_file in expected_feature_files:
        summary_lines.append(
            f"  {feature_file.name} | sha256={calculate_sha256(feature_file)}"
        )
    summary_lines.extend([
        "",
        "Checkpoint metadata:",
        (
            "  best_val_accuracy: "
            f"{checkpoint_data.get('best_val_accuracy', 'not recorded')}"
        ),
        (
            "  best_epoch: "
            f"{checkpoint_data.get('best_epoch', 'not recorded')}"
        ),
        (
            "  sequence_length: "
            f"{checkpoint_data.get('sequence_length', 'not recorded')}"
        ),
        (
            "  feature_size: "
            f"{checkpoint_data.get('feature_size', 'not recorded')}"
        ),
        "",
        "Comparison with original Stage-03 sequence:",
    ])
    summary_lines.extend(
        f"  {summary_line}"
        for summary_line in reference_summary_lines
    )
    OUTPUT_SUMMARY_FILE.write_text(
        "\n".join(summary_lines) + "\n",
        encoding="utf-8",
    )
    print("-" * 68)
    print("Hybrid feature tensor saved:")
    print(OUTPUT_FEATURE_FILE)
    print("Hybrid validation summary saved:")
    print(OUTPUT_SUMMARY_FILE)
    print("=" * 68)
if __name__ == "__main__":
    main()