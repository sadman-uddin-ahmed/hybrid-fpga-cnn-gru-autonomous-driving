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