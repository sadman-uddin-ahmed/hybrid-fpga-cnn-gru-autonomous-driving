# Results Summary

This document summarises the main measurable results from the hybrid FPGA-CNN-GRU autonomous-driving perception project.

The project combines:

- CNN-based spatial feature extraction
- W8A8 fixed-point quantisation
- Verilog RTL implementation of the CNN feature extractor
- four-frame temporal feature buffering
- CNN-RNN, CNN-LSTM and CNN-GRU temporal-model evaluation
- hybrid FPGA-compatible CNN-GRU validation
- Basys-3 and Nexys Video FPGA implementation
- FPGA device-scalability analysis
- FPGA-oriented architectural optimisation

The most recent FPGA work demonstrates that moving the unchanged design to a larger FPGA increased implementation headroom but did not reduce execution latency. Subsequent RTL architectural optimisation reduced the four-frame CNN feature-extraction latency from 4097.577920 ms to 227.185600 ms at the same 50 MHz CNN core clock.

For additional technical detail, see:

- [FPGA device scalability](fpga-device-scalability.md)
- [FPGA architecture optimisation](fpga-architecture-optimisation.md)
- [Temporal model comparison](temporal-model-comparison.md)

---

## CNN Baseline

| Item | Result |
| --- | ---: |
| Input image size | 64 × 64 RGB |
| Classification task | Binary car-present / no-car |
| Total CNN parameters | 1,054,050 |
| CNN feature size before classifier | 8,192 |
| Test accuracy | 98.247% |
| CPU inference time | 10.263118 ms/image |
| Model size | 4.02 MB |

The CNN baseline established the spatial perception foundation for the project.

The convolutional feature output before the fully connected classifier was subsequently used as the FPGA-compatible feature representation.

---

## CNN Architecture Summary

| Layer | Input dimensions | Output dimensions | Parameters |
| --- | ---: | ---: | ---: |
| Conv1 | 3 × 64 × 64 | 16 × 64 × 64 | 448 |
| ReLU | 16 × 64 × 64 | 16 × 64 × 64 | 0 |
| MaxPool | 16 × 64 × 64 | 16 × 32 × 32 | 0 |
| Conv2 | 16 × 32 × 32 | 32 × 32 × 32 | 4,640 |
| ReLU | 32 × 32 × 32 | 32 × 32 × 32 | 0 |
| MaxPool | 32 × 32 × 32 | 32 × 16 × 16 | 0 |
| FC1 | 8,192 | 128 | 1,048,704 |
| FC2 | 128 | 2 | 258 |
| Total | - | - | 1,054,050 |

For the FPGA and hybrid workflow, the feature vector before the fully connected classifier is used:

```text
32 × 16 × 16 = 8,192 features
```

---

## Quantisation Results

| Setting | Weight bits | Activation bits | Accuracy | Evaluation time |
| --- | ---: | ---: | ---: | ---: |
| Float | 32 | 32 | 98.2523% | 7.141628 s |
| W8A8 | 8 | 8 | 98.2523% | 6.899376 s |
| W8A6 | 8 | 6 | 98.3825% | 6.920166 s |
| W6A6 | 6 | 6 | 98.3825% | 7.090248 s |
| W4A4 | 4 | 4 | 98.6429% | 7.086219 s |

W8A8 was selected for the FPGA implementation because it provides a practical fixed-point representation while retaining the baseline CNN accuracy.

---

## Activation Scales

| Layer output | Maximum value | Scale |
| --- | ---: | ---: |
| Conv1 block output | 1.625949 | 0.01280275 |
| Conv2 block output | 1.438557 | 0.01132722 |

The Conv2 activation scale is also used when reconstructing FPGA-compatible CNN features for host-side CNN-GRU classification.

---

## Temporal Dataset and Feature Representation

| Item | Result |
| --- | ---: |
| Total images | 7,481 |
| Sequence length | 4 frames |
| Total temporal sequences | 7,478 |
| Feature size per frame | 8,192 |
| Temporal feature size per sequence | 32,768 |
| Training sequences | 5,981 |
| Validation sequences | 747 |
| Test sequences | 750 |

Each temporal sample is represented as:

```text
[batch size, sequence length, feature size]
=
[batch size, 4, 8192]
```

---

## Temporal Model Comparison

| Model | Parameters | Test accuracy | Precision | Recall | F1-score |
| --- | ---: | ---: | ---: | ---: | ---: |
| CNN-RNN | 1,065,474 | 98.40% | 98.83% | 99.41% | 99.12% |
| CNN-LSTM | 4,261,122 | 99.07% | 99.41% | 99.56% | 99.49% |
| CNN-GRU | 3,195,906 | 99.07% | 99.13% | 99.85% | 99.49% |

CNN-GRU was selected for hybrid validation because it:

- matched the CNN-LSTM test accuracy
- matched the CNN-LSTM F1-score
- achieved the highest recall
- produced the lowest false-negative count
- required fewer parameters than CNN-LSTM

---

## Confusion Matrix Comparison

| Model | True positive | True negative | False positive | False negative |
| --- | ---: | ---: | ---: | ---: |
| CNN-RNN | 677 | 61 | 8 | 4 |
| CNN-LSTM | 678 | 65 | 4 | 3 |
| CNN-GRU | 680 | 63 | 6 | 1 |

CNN-GRU produced only one false negative on the test set.

For the car-present / no-car task, reducing false negatives is particularly important because a false negative corresponds to a missed car-present case.

---

## FPGA CNN Feature-Extractor Verification

The W8A8 CNN feature extractor was transferred to Verilog RTL and verified against Python-generated fixed-point reference data.

| Item | Result |
| --- | ---: |
| Input frame | 64 × 64 RGB |
| Quantisation | W8A8 |
| CNN output features per frame | 8,192 |
| Output type | signed 8-bit |
| Missing output values | 0 |
| Duplicate output values | 0 |
| Unknown X/Z values | 0 |
| Golden-reference comparison | PASS |

The RTL feature-extraction datapath therefore reproduced the expected fixed-point CNN behaviour.

---

## Earlier Standalone Basys-3 CNN Implementation

An earlier standalone CNN feature-extractor implementation demonstrated that the W8A8 CNN datapath could be implemented on the Basys-3 Artix-7 FPGA.

| Resource | Result |
| --- | ---: |
| LUTs | 4,811 |
| Flip-flops | 774 |
| BRAM tiles | 25 |
| DSP blocks | 8 |
| Internal CNN clock | 50 MHz |
| Worst negative slack | 0.251 ns |
| Total negative slack | 0 ns |

This represented an intermediate implementation before four-frame temporal buffering and later FPGA architectural optimisation were introduced.

---

## Four-Frame FPGA Temporal Buffering

The FPGA-side architecture was extended to process four consecutive CNN input frames and store their feature vectors in a temporal buffer.

| Item | Result |
| --- | ---: |
| Frames per temporal sequence | 4 |
| Features per frame | 8,192 |
| Total temporal features | 32,768 |
| Feature data type | signed 8-bit |
| Temporal frames captured | 4 |
| Output-stream address errors | 0 |
| Output-stream X/Z values | 0 |
| Output-stream mismatches | 0 |
| Temporal-buffer X/Z values | 0 |
| Temporal-buffer mismatches | 0 |

The temporal buffer address organisation is:

| Frame | Buffer address range |
| --- | ---: |
| Frame 0 | 0 to 8,191 |
| Frame 1 | 8,192 to 16,383 |
| Frame 2 | 16,384 to 24,575 |
| Frame 3 | 24,576 to 32,767 |

The FPGA therefore produces the 32,768-value temporal representation required by the four-frame CNN-GRU workflow.

---

## Validated Basys-3 Temporal Baseline

The complete Basys-3 FPGA-side temporal implementation contained:

- W8A8 CNN feature extraction
- four-frame sequencing
- temporal feature buffering
- clock-divider logic
- board-level controls
- status-output logic

Its implementation results were:

| Resource / Metric | Result |
| --- | ---: |
| LUTs | 4,112 |
| Registers | 786 |
| BRAM tiles | 45 |
| DSP48E1 blocks | 8 |
| CNN core clock | 50 MHz |
| Setup slack | +0.698 ns |
| Bitstream generation | Successful |

Block-RAM capacity was the principal hardware constraint on the Basys-3, reaching approximately 90% utilisation.

---

## Physical Basys-3 Validation

The Basys-3 implementation was programmed and physically executed.

| LED signal | Final observed state | Interpretation |
| --- | --- | --- |
| LD0 - Done | ON | Processing completed |
| LD1 - Busy | OFF | Processing no longer active |
| LD2 - Started | ON | Start command accepted |
| LD3 - Pass | ON | Internal board-level verification passed |
| LD4 - Fail | OFF | No failure condition detected |

The board accepted reset and start controls, completed the four-frame processing sequence and reached the expected PASS state.

---

## Original Board-Level RTL Latency

The validated serial architecture produced:

| Measurement item | Result |
| --- | ---: |
| Start accepted time | 605 ns |
| Done and Pass time | 4,097.578525 ms |
| Four-frame latency | 4097.577920 ms |
| Average latency per frame | 1024.394480 ms/frame |
| Estimated throughput | 0.976186 frames/s |

This result established the performance baseline used for subsequent FPGA scalability and architecture-optimisation experiments.

The latency value is derived from board-level RTL simulation rather than external physical timing instrumentation.

---

# FPGA Device Scalability

## Basys-3 to Nexys Video Port

The validated temporal CNN architecture was ported from the Basys-3 to the higher-capacity Nexys Video Artix-7 FPGA.

For the controlled comparison, the following were deliberately retained:

- CNN architecture
- W8A8 parameters
- fixed-point arithmetic
- four-frame temporal structure
- processing schedule
- 50 MHz CNN core clock

The objective was to determine whether increased FPGA capacity alone could improve execution latency.

---

## Functional Equivalence Across Devices

The Nexys Video port passed the complete four-frame temporal regression.

| Verification Metric | Result |
| --- | ---: |
| Frames processed | 4 |
| Features per frame | 8,192 |
| Total features verified | 32,768 |
| Address errors | 0 |
| X/Z values | 0 |
| Stream mismatches | 0 |
| Temporal-buffer mismatches | 0 |

The device migration therefore preserved the complete numerical feature sequence.

---

## Device Resource Scalability

| Resource | Basys-3 utilisation | Nexys Video utilisation |
| --- | ---: | ---: |
| Slice LUTs | 19.77% | 3.06% |
| Slice Registers | 1.89% | 0.27% |
| Block RAM | 90.00% | 12.33% |
| DSP48E1 | 8.89% | 1.08% |

The larger Nexys Video device provided substantially more implementation headroom.

The most significant improvement was block-RAM utilisation:

```text
Basys-3:      90.00%
Nexys Video:  12.33%
```

This additional capacity made later memory banking, additional MAC units and deeper pipelining practical.

---

## Device Migration Did Not Reduce Latency

Despite the large resource-capacity improvement, the unchanged architecture produced the same execution latency on both FPGAs.

| Metric | Basys-3 | Nexys Video |
| --- | ---: | ---: |
| Four-frame latency | 4097.577920 ms | 4097.577920 ms |
| Average latency per frame | 1024.394480 ms | 1024.394480 ms |
| Estimated throughput | 0.976186 fps | 0.976186 fps |

The device migration therefore produced:

```text
0% architectural latency improvement
```

at the controlled 50 MHz CNN core clock.

This demonstrated that the performance limitation was primarily caused by the RTL processing architecture rather than insufficient FPGA capacity.

---

## Original Conv2 Bottleneck

Detailed cycle analysis identified Conv2 as the dominant bottleneck.

| Conv2 Metric | Result |
| --- | ---: |
| Approximate cycles per frame | 47,028,224 |
| Latency at 50 MHz | 940.564480 ms |
| Share of frame latency | 91.82% |

The original Conv2 controller used a highly serial sequence for memory access, operand preparation, multiplication, accumulation and quantisation.

This result motivated FPGA-oriented architectural optimisation rather than further device-only scaling.

---

# FPGA Architecture Optimisation

The architecture was subsequently redesigned through three progressive optimisation stages.

The CNN core clock remained fixed at 50 MHz so that performance gains could be attributed to architectural changes rather than increased clock frequency.

---

## Optimisation Progression

| Architecture | Four-frame latency | Average per frame | Throughput | Speedup |
| --- | ---: | ---: | ---: | ---: |
| Original architecture | 4097.577920 ms | 1024.394480 ms | 0.976186 fps | 1.00x |
| Pipelined Conv2 MAC | 752.128960 ms | 188.032240 ms | 5.318237 fps | 5.45x |
| Four-lane Conv2 | 449.352640 ms | 112.338160 ms | 8.901695 fps | 9.12x |
| Four-lane Conv1 + Conv2 | 227.185600 ms | 56.796400 ms | 17.606750 fps | 18.04x |

The complete progression was:

```text
4097.577920 ms
      |
      v
752.128960 ms
      |
      v
449.352640 ms
      |
      v
227.185600 ms
```

The current optimized architecture therefore achieves:

```text
18.04x speedup
94.46% four-frame latency reduction
17.606750 frames/s estimated throughput
```

relative to the original architecture.

---

## Iteration 1: Pipelined Conv2 MAC

The first optimisation reorganised the highly sequential Conv2 MAC schedule around registered arithmetic.

This reduced controller overhead while preserving:

- signed W8A8 operands
- output ordering
- per-output accumulation order
- requantisation
- rounding
- ReLU
- saturation
- max pooling

The result was:

```text
4097.577920 ms -> 752.128960 ms
```

corresponding to a:

```text
5.45x speedup
```

without changing the 50 MHz CNN core frequency.

---

## Iteration 2: Four-Lane Conv2

Conv2 was then redesigned to process four independent output channels concurrently.

The architecture introduced:

- four parallel W8A8 multiplication lanes
- four independent accumulators
- four Conv2 weight banks
- four bias banks
- shared input-feature access

The resulting latency became:

```text
449.352640 ms for four frames
```

with:

```text
8.901695 frames/s
9.12x speedup vs original
```

After Conv2 acceleration, the principal remaining bottleneck shifted toward Conv1.

---

## Conv1 Design-Space Exploration

Parallel Conv1 configurations were analytically evaluated.

| Conv1 configuration | Predicted Conv1 latency | Predicted four-frame latency | Predicted throughput |
| --- | ---: | ---: | ---: |
| 2 lanes | 42.598400 ms/frame | 301.241280 ms | 13.278393 fps |
| 4 lanes | 24.084480 ms/frame | 227.185600 ms | 17.606750 fps |
| 8 lanes | 14.827520 ms/frame | 190.157760 ms | 21.035166 fps |

Four lanes were selected as the design-space knee.

Moving from four to eight Conv1 lanes provided a smaller whole-system improvement while increasing:

- DSP consumption
- accumulator count
- register count
- activation fan-out
- weight-bank connectivity
- routing pressure
- control and verification complexity

---

## Current Four-Lane Conv1 + Conv2 Architecture

The current optimized implementation contains output-channel parallelism in both convolution stages.

Conv1 uses four independent MAC lanes operating on the same input activation.

Each Conv1 output channel retains the original:

```text
3 × 3 × 3 = 27
```

signed-product accumulation sequence.

The architecture preserves:

- signed 8-bit activations
- signed 8-bit weights
- registered signed multiplication
- signed 64-bit accumulation
- original accumulation order
- fixed-point scaling
- arithmetic shifting
- rounding
- ReLU
- positive saturation
- 2 × 2 maximum pooling

Parallelism therefore changes the execution schedule of independent output channels without changing the numerical computation performed for each feature value.

---

## Optimized Functional Regression

The current optimized architecture was subjected to the complete four-frame regression.

| Verification Metric | Result |
| --- | ---: |
| Temporal frames captured | 4 |
| CNN features streamed | 32,768 |
| Stream address errors | 0 |
| Stream X/Z values | 0 |
| Stream mismatches | 0 |
| Temporal-buffer X/Z values | 0 |
| Temporal-buffer mismatches | 0 |
| Final regression result | PASS |

All:

```text
4 × 8192 = 32,768
```

streamed and stored CNN feature values remained bit-exact with the expected W8A8 reference vectors.

The performance improvement was therefore achieved without sacrificing numerical correctness.

---

## Optimized FPGA Resource Utilisation

The same optimized RTL was implemented on both Basys-3 and Nexys Video.

| Resource | Basys-3 XC7A35T | Nexys Video XC7A200T |
| --- | ---: | ---: |
| Slice LUTs | 4,876 / 20,800 = 23.44% | 4,859 / 133,800 = 3.63% |
| Slice Registers | 1,206 / 41,600 = 2.90% | 1,206 / 267,600 = 0.45% |
| Block-RAM tiles | 44.5 / 50 = 89.00% | 44.5 / 365 = 12.19% |
| DSP48E1 blocks | 16 / 90 = 17.78% | 16 / 740 = 2.16% |

The optimized architecture doubled DSP use relative to the original 8-DSP temporal baseline while retaining approximately the same block-memory requirement.

The final Conv1 optimisation specifically increased total DSP use from:

```text
13 -> 16
```

while BRAM remained:

```text
44.5 tiles
```

and four-frame latency decreased by approximately 49.44% relative to the preceding four-lane Conv2 implementation.

---

## Optimized Routed Timing

Both FPGA implementations met the retained 50 MHz CNN core timing constraint.

| Timing Metric | Basys-3 | Nexys Video |
| --- | ---: | ---: |
| CNN core period | 20.000 ns | 20.000 ns |
| CNN core frequency | 50 MHz | 50 MHz |
| WNS | +3.599 ns | +4.347 ns |
| TNS | 0.000 ns | 0.000 ns |
| WHS | +0.034 ns | +0.124 ns |
| THS | 0.000 ns | 0.000 ns |
| Setup failing endpoints | 0 | 0 |
| Hold failing endpoints | 0 | 0 |

Both versions completed:

- synthesis
- placement
- routing
- routed timing analysis
- design-rule checking
- post-route power estimation
- bitstream generation

No functional RTL change was required between the optimized Basys-3 and Nexys Video implementations.

---

## Hybrid CNN-GRU Validation

The FPGA-compatible CNN features were also evaluated using the selected CNN-GRU temporal classifier.

For the representative four-frame validation sequence:

| Item | Original CNN-GRU features | FPGA-compatible reconstructed features |
| --- | ---: | ---: |
| Ground truth | Car present | Car present |
| Predicted class | Car present | Car present |
| Prediction confidence | 96.25% | 96.66% |
| Classification correct | Yes | Yes |
| Final prediction preserved | - | Yes |

The FPGA-compatible feature representation therefore preserved the original CNN-GRU classification decision.

---

## Feature and Logit Difference

| Comparison metric | Result |
| --- | ---: |
| Maximum feature difference | 0.0142679811 |
| Mean feature difference | 0.0018423868 |
| Maximum CNN-GRU logit difference | 0.0596141815 |
| Final class prediction preserved | Yes |

The numerical differences result from fixed-point quantisation and reconstruction but did not alter the final class prediction.

---

## Full-Test Quantisation Consistency

| Metric | Floating-point features | Quantized/reconstructed features |
| --- | ---: | ---: |
| Test accuracy | 98.80% | 98.80% |
| Precision | 99.56% | 99.56% |
| Recall | 99.12% | 99.12% |
| F1-score | 99.34% | 99.34% |
| Prediction preservation | - | 750 / 750 |

Across all 750 test sequences, quantisation and feature reconstruction preserved every CNN-GRU prediction.

---

## FPGA Latency Measurement Scope

The FPGA latency figures in this repository are obtained from board-level RTL simulation.

For the current optimized architecture:

| Metric | Result |
| --- | ---: |
| Four-frame latency | 227.185600 ms |
| Average latency per frame | 56.796400 ms |
| Estimated throughput | 17.606750 fps |
| Speedup vs original | 18.04x |
| Latency reduction | 94.46% |

These values should **not** be interpreted as direct physical timing measurements.

Physical FPGA implementation and board execution have been demonstrated during the project, but the detailed latency values were not independently measured using:

- an external timing pin
- an FPGA hardware cycle counter
- UART timing output
- Integrated Logic Analyzer timing capture
- oscilloscope timing measurement

Direct physical latency instrumentation therefore remains separate from the RTL-simulation latency analysis.

---

## Current FPGA Scope

The programmable-logic implementation currently covers:

```text
Four input frames
        |
        v
W8A8 Conv1
        |
        v
ReLU
        |
        v
MaxPool
        |
        v
W8A8 Conv2
        |
        v
ReLU
        |
        v
MaxPool
        |
        v
8,192 features/frame
        |
        v
Four-frame temporal buffer
        |
        v
32,768 signed 8-bit temporal features
```

The complete CNN-GRU temporal classifier is not currently executed entirely inside FPGA programmable logic.

The project therefore represents a hybrid architecture in which FPGA-side CNN temporal feature extraction is combined with host-side temporal classification.

---

## Main Engineering Conclusions

### Machine-Learning Results

- A compact CNN achieved approximately 98.25% baseline test accuracy.
- W8A8 quantisation preserved the baseline CNN accuracy.
- CNN-RNN, CNN-LSTM and CNN-GRU temporal models were evaluated.
- CNN-GRU achieved 99.07% test accuracy, 99.85% recall and 99.49% F1-score.
- CNN-GRU produced only one false negative in the evaluated test set.
- FPGA-compatible feature quantisation and reconstruction preserved all 750 CNN-GRU test predictions.

### FPGA Functional Results

- The W8A8 CNN was transferred to Verilog RTL.
- Each frame produces exactly 8,192 signed 8-bit CNN features.
- Four-frame buffering produces exactly 32,768 temporal feature values.
- Full temporal regression produced zero address errors, zero X/Z values and zero feature mismatches.
- Exact W8A8 numerical behaviour was retained after architectural parallelisation.

### FPGA Scalability Results

- The validated architecture was ported from Basys-3 to Nexys Video.
- Nexys Video reduced BRAM utilisation from 90.00% to 12.33%.
- DSP utilisation decreased from 8.89% to 1.08% for the unchanged architecture.
- The unchanged device migration produced no latency improvement.
- This established that the original performance limitation was architectural rather than primarily resource-capacity limited.

### FPGA Architecture-Optimisation Results

- Conv2 was identified as approximately 91.82% of the original frame latency.
- Pipelined Conv2 reduced four-frame latency to 752.128960 ms.
- Four-lane Conv2 reduced it further to 449.352640 ms.
- Four-lane Conv1 + Conv2 reduced it to 227.185600 ms.
- Estimated throughput increased from 0.976186 fps to 17.606750 fps.
- Overall latency decreased by approximately 94.46%.
- Overall architectural speedup reached 18.04x.
- The complete improvement was achieved while retaining the same 50 MHz CNN core clock.
- The optimized architecture closes routed timing and generates bitstreams on both Basys-3 and Nexys Video.

The central FPGA finding is therefore:

> Moving an unchanged design to a larger FPGA created resource headroom, but architectural pipelining, output-channel parallelism and memory banking produced the actual performance improvement.

The current implementation remains open to further FPGA-specific optimisation, including deeper streaming, additional parallelism, clock-frequency exploration and direct physical latency instrumentation.