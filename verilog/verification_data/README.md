# FPGA Verification Data

This directory contains the curated fixed-point parameters and temporal verification vectors used to reproduce the RTL regression tests for the optimized CNN temporal feature-extraction architecture.

## Directory Structure

```text
verification_data/
├── parameters/
│   ├── conv1_w.mem
│   ├── conv1_b_int32_correct.mem
│   ├── conv2_w.mem
│   └── conv2_b_int32_correct.mem
│
└── temporal_sequence/
    ├── sequence_000_frame_0_input.mem
    ├── sequence_000_frame_0_expected.mem
    ├── sequence_000_frame_1_input.mem
    ├── sequence_000_frame_1_expected.mem
    ├── sequence_000_frame_2_input.mem
    ├── sequence_000_frame_2_expected.mem
    ├── sequence_000_frame_3_input.mem
    ├── sequence_000_frame_3_expected.mem
    └── temporal_expected_summary.txt
```

## Parameter Files

The `parameters/` directory contains the quantized CNN weights and corrected integer bias values used by the Verilog CNN feature extractor.

- `conv1_w.mem` - Conv1 quantized weights
- `conv1_b_int32_correct.mem` - Conv1 corrected integer biases
- `conv2_w.mem` - Conv2 quantized weights
- `conv2_b_int32_correct.mem` - Conv2 corrected integer biases

## Temporal Verification Sequence

The `temporal_sequence/` directory contains one four-frame verification sequence.

Each input file provides the quantized input values for one 64 × 64 RGB frame.

Each corresponding expected file provides the 8,192 signed 8-bit CNN feature values expected from that frame.

Across all four frames, the temporal regression therefore checks the complete 32,768-feature sequence.

## Using the Files in Vivado

The optimized regression testbench is:

```text
verilog/testbenches/optimized/cnn_temporal_capture_tb.v
```

The board-level latency monitor is:

```text
verilog/testbenches/optimized/cnn_board_latency_monitor_tb.v
```

The regression testbench references the `.mem` files by filename.

When recreating the simulation in Vivado:

1. Add the required files from `parameters/` and `temporal_sequence/` to the Vivado simulation project.
2. Ensure the `.mem` files are available to the simulator at runtime.
3. Set `cnn_temporal_capture_tb` as the simulation top for the full four-frame feature regression.
4. Run the behavioral simulation and check the final self-checking PASS/FAIL result.

The latency-monitor testbench should be used separately when evaluating the board-level RTL execution latency.

## Verification Scope

The temporal regression checks:
- four consecutive input frames
- 8,192 CNN features per frame
- 32,768 temporal feature values in total
- feature-stream ordering
- output addresses
- unknown (`X/Z`) values
- temporal-buffer contents
- exact comparison against the expected fixed-point feature vectors

The latency testbench reports simulation-derived execution timing. These latency results should not be interpreted as direct oscilloscope or hardware-counter measurements from the physical FPGA board.