from __future__ import annotations
import hashlib
from pathlib import Path
import numpy as np
# User configuration
PROJECT_ROOT = Path(
    r"D:\LJMU\Modules\MSc_Dissertation\Dissertation_Framework"
)
MEM_DIRECTORY = (
    PROJECT_ROOT
    / "Codes"
    / "Verilog_HDL"
    / "cnn_fpga_accelerator"
    / "data"
    / "mem"
)
TEMPORAL_INPUT_DIRECTORY = MEM_DIRECTORY / "temporal_inputs"
FRAME_COUNT = 4
INPUT_VALUES_PER_FRAME = 3 * 64 * 64
FEATURE_VALUES_PER_FRAME = 32 * 16 * 16
CONV1_SCALE_MULTIPLIER = 1301962
CONV2_SCALE_MULTIPLIER = 1516810
SCALE_SHIFT = 30
# Memory-file helpers
def read_signed_hex_memory(memory_path: Path, bit_width: int) -> np.ndarray:
    """Read a one-value-per-line hexadecimal .mem file as signed integers."""
    values = []
    signed_threshold = 1 << (bit_width - 1)
    full_range = 1 << bit_width
    with memory_path.open("r", encoding="utf-8") as memory_file:
        for line_number, raw_line in enumerate(memory_file, start=1):
            text_value = raw_line.strip()
            if not text_value:
                continue
            try:
                unsigned_value = int(text_value, 16)
            except ValueError as error:
                raise ValueError(
                    f"Invalid hexadecimal value in {memory_path} at line "
                    f"{line_number}: {text_value}"
                ) from error
            if unsigned_value >= full_range:
                raise ValueError(
                    f"Value outside {bit_width}-bit range in {memory_path} "
                    f"at line {line_number}: {text_value}"
                )
            if unsigned_value >= signed_threshold:
                values.append(unsigned_value - full_range)
            else:
                values.append(unsigned_value)
    return np.asarray(values, dtype=np.int64)
def write_int8_hex_memory(memory_path: Path, values: np.ndarray) -> None:
    """Write signed int8 values as two-digit hexadecimal lines for $readmemh."""
    flat_values = np.asarray(values, dtype=np.int64).reshape(-1)
    if np.any(flat_values < -128) or np.any(flat_values > 127):
        raise ValueError(
            f"Output range is not valid signed int8 for {memory_path}."
        )
    with memory_path.open("w", encoding="utf-8", newline="\n") as memory_file:
        for value in flat_values:
            memory_file.write(f"{int(value) & 0xFF:02X}\n")
def sha256_file(file_path: Path) -> str:
    digest = hashlib.sha256()
    with file_path.open("rb") as file_handle:
        for data_block in iter(lambda: file_handle.read(1024 * 1024), b""):
            digest.update(data_block)
    return digest.hexdigest()
# Exact fixed-point reference model for current Stage-02 RTL
def quantize_relu_int8(
    accumulator_values: np.ndarray,
    scale_multiplier: int,
) -> np.ndarray:
    """Match the RTL: multiply, round positive products only, shift, ReLU, saturate."""
    accumulator_values = np.asarray(accumulator_values, dtype=np.int64)
    quantized_product = accumulator_values * np.int64(scale_multiplier)
    rounded_product = quantized_product + np.where(
        quantized_product > 0,
        np.int64(1 << (SCALE_SHIFT - 1)),
        np.int64(0),
    )
    shifted_values = rounded_product >> SCALE_SHIFT
    return np.clip(shifted_values, 0, 127).astype(np.int8)
def conv_relu_maxpool_fixed(
    input_features: np.ndarray,
    convolution_weights: np.ndarray,
    convolution_biases: np.ndarray,
    scale_multiplier: int,
) -> np.ndarray:
    """Exact 3x3 pad-1 convolution, fixed-point quantisation, ReLU and 2x2 max pool."""
    input_features = np.asarray(input_features, dtype=np.int64)
    convolution_weights = np.asarray(convolution_weights, dtype=np.int64)
    convolution_biases = np.asarray(convolution_biases, dtype=np.int64)
    input_channels, input_height, input_width = input_features.shape
    output_channels, weight_input_channels, kernel_height, kernel_width = (
        convolution_weights.shape
    )
    if weight_input_channels != input_channels:
        raise ValueError(
            "Input-channel mismatch between feature tensor and convolution weights."
        )
    if kernel_height != 3 or kernel_width != 3:
        raise ValueError("This reference model requires 3x3 convolution kernels.")
    if input_height % 2 != 0 or input_width % 2 != 0:
        raise ValueError("Input feature-map dimensions must be even for 2x2 pooling.")
    padded_input = np.pad(
        input_features,
        pad_width=((0, 0), (1, 1), (1, 1)),
        mode="constant",
        constant_values=0,
    )
    convolution_output = np.empty(
        (output_channels, input_height, input_width),
        dtype=np.int64,
    )
    for output_channel_index in range(output_channels):
        accumulator_map = np.full(
            (input_height, input_width),
            convolution_biases[output_channel_index],
            dtype=np.int64,
        )
        for input_channel_index in range(input_channels):
            for kernel_y_index in range(3):
                for kernel_x_index in range(3):
                    weight_value = convolution_weights[
                        output_channel_index,
                        input_channel_index,
                        kernel_y_index,
                        kernel_x_index,
                    ]
                    accumulator_map += (
                        weight_value
                        * padded_input[
                            input_channel_index,
                            kernel_y_index:kernel_y_index + input_height,
                            kernel_x_index:kernel_x_index + input_width,
                        ]
                    )
        convolution_output[output_channel_index] = accumulator_map
    quantized_output = quantize_relu_int8(
        convolution_output,
        scale_multiplier,
    )
    return np.maximum.reduce(
        [
            quantized_output[:, 0::2, 0::2],
            quantized_output[:, 0::2, 1::2],
            quantized_output[:, 1::2, 0::2],
            quantized_output[:, 1::2, 1::2],
        ]
    )
def run_stage02_reference(
    input_image_values: np.ndarray,
    conv1_weights: np.ndarray,
    conv1_biases: np.ndarray,
    conv2_weights: np.ndarray,
    conv2_biases: np.ndarray,
) -> np.ndarray:
    """Generate the 8192 final Conv2->ReLU->MaxPool feature values."""
    if input_image_values.size != INPUT_VALUES_PER_FRAME:
        raise ValueError(
            "Each CNN input image must contain exactly 12288 values."
        )
    conv1_input = input_image_values.reshape(3, 64, 64)
    conv1_output = conv_relu_maxpool_fixed(
        input_features=conv1_input,
        convolution_weights=conv1_weights,
        convolution_biases=conv1_biases,
        scale_multiplier=CONV1_SCALE_MULTIPLIER,
    )
    conv2_output = conv_relu_maxpool_fixed(
        input_features=conv1_output,
        convolution_weights=conv2_weights,
        convolution_biases=conv2_biases,
        scale_multiplier=CONV2_SCALE_MULTIPLIER,
    )
    final_features = conv2_output.reshape(-1)
    if final_features.size != FEATURE_VALUES_PER_FRAME:
        raise RuntimeError(
            "Stage-02 reference produced an unexpected feature-vector length."
        )
    return final_features
# Input validation and export
def require_length(values: np.ndarray, expected_length: int, source_path: Path) -> None:
    if values.size != expected_length:
        raise ValueError(
            f"{source_path} contains {values.size} values; expected {expected_length}."
        )
def main() -> None:
    baseline_input_path = MEM_DIRECTORY / "in_img_int8.mem"
    baseline_expected_path = MEM_DIRECTORY / "out_conv2_pool_int8_expected.mem"
    conv1_weight_path = MEM_DIRECTORY / "conv1_w.mem"
    conv1_bias_path = MEM_DIRECTORY / "conv1_b_int32_correct.mem"
    conv2_weight_path = MEM_DIRECTORY / "conv2_w.mem"
    conv2_bias_path = MEM_DIRECTORY / "conv2_b_int32_correct.mem"
    if not TEMPORAL_INPUT_DIRECTORY.is_dir():
        raise FileNotFoundError(
            "Temporal input folder was not found: "
            f"{TEMPORAL_INPUT_DIRECTORY}"
        )
    for required_path in [
        baseline_input_path,
        baseline_expected_path,
        conv1_weight_path,
        conv1_bias_path,
        conv2_weight_path,
        conv2_bias_path,
    ]:
        if not required_path.is_file():
            raise FileNotFoundError(f"Required file was not found: {required_path}")
    conv1_weights = read_signed_hex_memory(conv1_weight_path, 8)
    conv1_biases = read_signed_hex_memory(conv1_bias_path, 32)
    conv2_weights = read_signed_hex_memory(conv2_weight_path, 8)
    conv2_biases = read_signed_hex_memory(conv2_bias_path, 32)
    require_length(conv1_weights, 16 * 3 * 3 * 3, conv1_weight_path)
    require_length(conv1_biases, 16, conv1_bias_path)
    require_length(conv2_weights, 32 * 16 * 3 * 3, conv2_weight_path)
    require_length(conv2_biases, 32, conv2_bias_path)
    conv1_weights = conv1_weights.reshape(16, 3, 3, 3)
    conv2_weights = conv2_weights.reshape(32, 16, 3, 3)
    print("Running fixed-point baseline self-check...")
    baseline_input = read_signed_hex_memory(baseline_input_path, 8)
    baseline_expected = read_signed_hex_memory(baseline_expected_path, 8)
    require_length(baseline_input, INPUT_VALUES_PER_FRAME, baseline_input_path)
    require_length(
        baseline_expected,
        FEATURE_VALUES_PER_FRAME,
        baseline_expected_path,
    )
    baseline_generated = run_stage02_reference(
        input_image_values=baseline_input,
        conv1_weights=conv1_weights,
        conv1_biases=conv1_biases,
        conv2_weights=conv2_weights,
        conv2_biases=conv2_biases,
    )
    baseline_mismatch_count = int(
        np.count_nonzero(baseline_generated != baseline_expected)
    )
    if baseline_mismatch_count != 0:
        maximum_difference = int(
            np.max(
                np.abs(
                    baseline_generated.astype(np.int64)
                    - baseline_expected.astype(np.int64)
                )
            )
        )
        raise RuntimeError(
            "Baseline self-check failed. The Python reference does not match the "
            "verified Stage-02 expected output. "
            f"Mismatches={baseline_mismatch_count}, "
            f"maximum_difference={maximum_difference}."
        )
    print("Baseline self-check PASSED: 8192/8192 values match.")
    summary_path = TEMPORAL_INPUT_DIRECTORY / "temporal_expected_summary.txt"
    with summary_path.open("w", encoding="utf-8", newline="\n") as summary_file:
        summary_file.write("Stage-04 temporal expected-feature export\n")
        summary_file.write("Reference: current Stage-02 fixed-point RTL convention\n")
        summary_file.write("Baseline self-check: PASS (8192/8192)\n\n")
        for frame_index in range(FRAME_COUNT):
            input_path = (
                TEMPORAL_INPUT_DIRECTORY
                / f"sequence_000_frame_{frame_index}_input.mem"
            )
            output_path = (
                TEMPORAL_INPUT_DIRECTORY
                / f"sequence_000_frame_{frame_index}_expected.mem"
            )
            if not input_path.is_file():
                raise FileNotFoundError(
                    f"Temporal input file was not found: {input_path}"
                )
            frame_input = read_signed_hex_memory(input_path, 8)
            require_length(frame_input, INPUT_VALUES_PER_FRAME, input_path)
            print(f"Generating expected Conv2 output for frame {frame_index}...")
            frame_features = run_stage02_reference(
                input_image_values=frame_input,
                conv1_weights=conv1_weights,
                conv1_biases=conv1_biases,
                conv2_weights=conv2_weights,
                conv2_biases=conv2_biases,
            )
            write_int8_hex_memory(output_path, frame_features)
            output_hash = sha256_file(output_path)
            nonzero_count = int(np.count_nonzero(frame_features))
            minimum_value = int(np.min(frame_features))
            maximum_value = int(np.max(frame_features))
            summary_line = (
                f"Frame {frame_index}: values={frame_features.size}, "
                f"range={minimum_value}..{maximum_value}, "
                f"nonzero={nonzero_count}, "
                f"sha256={output_hash}\n"
            )
            summary_file.write(summary_line)
            print(summary_line.strip())
    print("\nExpected files created successfully:")
    for frame_index in range(FRAME_COUNT):
        print(
            TEMPORAL_INPUT_DIRECTORY
            / f"sequence_000_frame_{frame_index}_expected.mem"
        )
    print(f"\nSummary file created: {summary_path}")
if __name__ == "__main__":
    main()