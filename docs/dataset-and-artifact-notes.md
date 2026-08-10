# Dataset and Artifact Notes

This repository is a public technical portfolio version of an ongoing MSc dissertation project. It contains selected source code, RTL modules, verification data, result summaries, implementation evidence, and documentation.

The repository intentionally excludes the full datasets, trained model checkpoints, bulk generated feature tensors, Vivado build products, bitstreams, and complete dissertation submission materials.

A small curated set of FPGA verification memory files is intentionally included to support reproduction of the published four-frame RTL regression.

## Dataset Usage

The project uses autonomous-driving image data for binary car-presence classification.

The classification task is:

| Label | Meaning |
|---|---|
| 0 | No car |
| 1 | Car present |

The full dataset is not redistributed in this repository.

Users who want to reproduce or extend the complete machine-learning workflow should obtain the dataset from the official dataset provider and comply with the applicable licensing and usage conditions.

## Why the Full Dataset Is Excluded

Dataset files are excluded because:

- they are large and unsuitable for a lightweight public repository
- they may be subject to external licensing requirements
- they are not required for reviewing the RTL implementation structure
- the repository is intended as a technical portfolio rather than a dataset mirror
- keeping the full dataset separate avoids accidental redistribution of third-party data

The `.gitignore` excludes common dataset locations and archives such as:

```text
data/
dataset/
datasets/
kitti/
KITTI/
cifar-10-batches-py/
*.tar
*.tar.gz
*.zip
*.7z
*.rar
```

## Model Checkpoints

Trained model checkpoints are intentionally excluded.

Excluded formats include:

```text
*.pt
*.pth
*.pkl
*.ckpt
*.onnx
```

The repository documents the model architectures, processing workflow, and measured results without redistributing trained model checkpoints.

## Generated Feature Tensors

Bulk generated feature tensors are excluded because they can be large and may be derived directly from dataset samples.

Excluded generated tensor formats include:

```text
*.npy
*.npz
*.pt
```

The public documentation instead describes the feature representation:

```text
CNN feature size per frame = 8,192
Temporal sequence length   = 4 frames
Temporal feature size      = 4 × 8,192
                           = 32,768 values
```

## Curated FPGA Verification Memory Files

Generated `.mem` files are excluded by default, but a deliberately selected verification subset is included under:

```text
verilog/verification_data/
```

The published parameter files are:

```text
parameters/
├── conv1_w.mem
├── conv1_b_int32_correct.mem
├── conv2_w.mem
└── conv2_b_int32_correct.mem
```

The published four-frame verification sequence is:

```text
temporal_sequence/
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

Each input frame contains:

```text
64 × 64 × 3 = 12,288
```

quantized input values.

Each expected output file contains:

```text
8,192
```

signed 8-bit CNN feature values.

The complete temporal regression therefore verifies:

```text
4 × 8,192 = 32,768
```

expected feature values.

These files are included specifically to support the public RTL verification workflow.

Bulk generated memory vectors remain excluded.

The `.gitignore` therefore follows the pattern:

```text
*.mem
```

with explicit exceptions for the curated files under:

```text
verilog/verification_data/parameters/
verilog/verification_data/temporal_sequence/
```

Further instructions are available in:

[`../verilog/verification_data/README.md`](../verilog/verification_data/README.md)

## FPGA Constraints

Board-specific Xilinx Design Constraints are included for both FPGA targets:

```text
verilog/constraints/
├── basys3/
│   ├── cnn_feature_demo_top_baseline.xdc
│   └── cnn_feature_basys3.xdc
│
└── nexys_video/
    └── cnn_feature_nexys_video.xdc
```

The baseline Basys-3 constraint file is retained separately from the current board-specific constraint configuration so that the earlier implementation remains identifiable.

## Baseline and Optimized RTL

The repository separates the earlier validated RTL from the current optimized architecture:

```text
verilog/rtl/
├── baseline/
└── optimized/
```

Likewise, verification testbenches are separated into:

```text
verilog/testbenches/
├── baseline/
└── optimized/
```

This preserves the architectural progression without mixing the reference implementation with the later pipelined and multi-lane design.

## Vivado Generated Files

Vivado-generated build products are intentionally excluded.

Excluded files and directories include:

```text
.Xil/
*.jou
*.log
*.str
*.dcp
*.bit
*.bin
*.mcs
*.ltx
*.wdb
*.vcd
*.rpt
*.cache/
*.hw/
*.ip_user_files/
*.runs/
*.sim/
xsim.dir/
```

Selected screenshots and documented metrics are provided instead of complete Vivado-generated project directories.

## Bitstreams and Checkpoints

FPGA bitstreams and Vivado design checkpoints are not distributed.

Examples include:

```text
*.bit
*.dcp
```

These are generated implementation artifacts rather than primary source files.

Both Basys-3 and Nexys Video implementation stages are represented in the repository through RTL, constraints, documentation, timing/resource evidence, and selected physical validation images.

## Full Dissertation Materials

Complete academic submission materials remain private.

Excluded academic materials include:

- full dissertation reports
- internal progress reports
- assessment drafts
- supervisor correspondence
- private project notes
- university submission files

This repository is not intended to replace the official dissertation submission.

## What Is Included

The public repository includes selected material such as:

- CNN baseline Python source
- fixed-point quantisation scripts and metadata
- hybrid CNN-GRU validation scripts
- baseline Verilog RTL
- current optimized Verilog RTL
- baseline and optimized Verilog testbenches
- Basys-3 FPGA constraints
- Nexys Video FPGA constraints
- curated W8A8 parameter memory files
- one curated four-frame RTL verification sequence
- result summaries
- FPGA scalability documentation
- FPGA architecture-optimisation documentation
- architecture diagrams
- Vivado verification and implementation screenshots
- Basys-3 physical validation evidence
- Nexys Video physical validation evidence

## Reproducibility Scope

The repository supports reproduction of the published **FPGA RTL verification flow** using the curated parameter files and four-frame input/reference sequence.

The optimized temporal regression uses:

```text
verilog/testbenches/optimized/cnn_temporal_capture_tb.v
```

with the files under:

```text
verilog/verification_data/
```

The repository does **not** provide complete one-command reproduction of the entire machine-learning training workflow because the full dataset and trained checkpoints are intentionally excluded.

Accordingly, two levels of reproducibility should be distinguished:

### FPGA RTL Verification

The repository provides the selected RTL, testbench, CNN parameters, input vectors, and expected feature vectors required for the published four-frame regression.

### Complete Machine-Learning Retraining

Full retraining requires the external dataset and regeneration of trained model checkpoints and other derived artifacts.

## Public Repository Scope

The repository is designed primarily for technical review of:

- CNN and temporal-model development
- fixed-point conversion
- FPGA-compatible feature representation
- Verilog RTL architecture
- self-checking verification
- FPGA device scalability
- architectural bottleneck analysis
- pipelining and multi-lane processing
- resource utilisation
- timing closure
- physical FPGA deployment evidence

It deliberately balances technical reproducibility with responsible exclusion of large, generated, private, and third-party materials.