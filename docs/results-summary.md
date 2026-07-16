# Results Summary

This document summarises the main measurable results from the hybrid FPGA-CNN-GRU autonomous-driving perception project.

The repository presents a hardware-aware perception pipeline where a quantized CNN feature extractor is implemented and validated for FPGA deployment, while CNN-GRU temporal classification is validated through a hybrid FPGA-compatible feature workflow.

## CNN baseline

| Item | Result |
|---|---:|
| Input image size | 64 × 64 RGB |
| Classification task | Binary car-present / no-car |
| Total CNN parameters | 1,054,050 |
| CNN feature size before classifier | 8,192 |
| Test accuracy | 98.247% |
| CPU inference time | 10.263118 ms/image |
| Model size | 4.02 MB |

The CNN baseline established the spatial perception foundation for the rest of the project. The convolutional feature output was later reused as the FPGA-compatible feature representation.

## CNN architecture summary

| Layer | Input dimensions | Output dimensions | Parameters |
|---|---:|---:|---:|
| Conv1 | 3 × 64 × 64 | 16 × 64 × 64 | 448 |
| ReLU | 16 × 64 × 64 | 16 × 64 × 64 | 0 |
| MaxPool | 16 × 64 × 64 | 16 × 32 × 32 | 0 |
| Conv2 | 16 × 32 × 32 | 32 × 32 × 32 | 4,640 |
| ReLU | 32 × 32 × 32 | 32 × 32 × 32 | 0 |
| MaxPool | 32 × 32 × 32 | 32 × 16 × 16 | 0 |
| FC1 | 8,192 | 128 | 1,048,704 |
| FC2 | 128 | 2 | 258 |
| Total | - | - | 1,054,050 |

For the FPGA and hybrid workflow, the feature vector before the fully connected classifier is used.

```text
32 × 16 × 16 = 8,192 features
```

## Quantization results

| Setting | Weight bits | Activation bits | Accuracy | Evaluation time |
|---|---:|---:|---:|---:|
| Float | 32 | 32 | 98.2523% | 7.141628 s |
| W8A8 | 8 | 8 | 98.2523% | 6.899376 s |
| W8A6 | 8 | 6 | 98.3825% | 6.920166 s |
| W6A6 | 6 | 6 | 98.3825% | 7.090248 s |
| W4A4 | 4 | 4 | 98.6429% | 7.086219 s |

W8A8 was selected for the FPGA workflow because it provides a practical fixed-point representation for hardware implementation while preserving the CNN baseline accuracy.

## Activation scales

| Layer output | Maximum value | Scale |
|---|---:|---:|
| Conv1 block output | 1.625949 | 0.01280275 |
| Conv2 block output | 1.438557 | 0.01132722 |

The Conv2 activation scale is used later when reconstructing FPGA-compatible CNN features for host-side CNN-GRU classification.

## Temporal dataset and feature representation

| Item | Result |
|---|---:|
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
[batch size, sequence length, feature size] = [batch size, 4, 8192]
```

## Temporal model comparison

| Model | Parameters | Test accuracy | Precision | Recall | F1-score |
|---|---:|---:|---:|---:|---:|
| CNN-RNN | 1,065,474 | 98.40% | 98.83% | 99.41% | 99.12% |
| CNN-LSTM | 4,261,122 | 99.07% | 99.41% | 99.56% | 99.49% |
| CNN-GRU | 3,195,906 | 99.07% | 99.13% | 99.85% | 99.49% |

CNN-GRU was selected for hybrid validation because it matched CNN-LSTM test accuracy and F1-score, achieved the highest recall, produced the lowest false-negative count, and used fewer parameters than CNN-LSTM.

## Confusion matrix comparison

| Model | True positive | True negative | False positive | False negative |
|---|---:|---:|---:|---:|
| CNN-RNN | 677 | 61 | 8 | 4 |
| CNN-LSTM | 678 | 65 | 4 | 3 |
| CNN-GRU | 680 | 63 | 6 | 1 |

The CNN-GRU model produced only one false negative on the test set. This was important because a false negative means a car-present case was missed.

## FPGA CNN feature-extractor verification

| Item | Result |
|---|---:|
| Target board | Digilent Basys-3 |
| FPGA device | Artix-7 xc7a35tcpg236-1 |
| External board clock | 100 MHz |
| Internal CNN core clock | 50 MHz |
| CNN output features per frame | 8,192 |
| Final Conv2 pooled outputs | 8,192 |
| Missing output values | 0 |
| Duplicate output values | 0 |
| Unknown X/Z output values | 0 |
| Golden-reference match | Passed |
| Bitstream generation | Successful |

The Verilog CNN feature extractor matched the Python-generated fixed-point golden reference. This verified that the W8A8 CNN feature-extraction path was correctly transferred into FPGA-compatible RTL.

## FPGA CNN feature-extractor implementation

| Resource | Utilisation |
|---|---:|
| LUTs | 4,811 |
| Flip-flops | 774 |
| BRAM tiles | 25 |
| DSP blocks | 8 |
| Internal CNN clock | 50 MHz |
| Worst negative slack | 0.251 ns |
| Total negative slack | 0 ns |

This implementation demonstrated that the quantized CNN feature extractor could fit on the Basys-3 Artix-7 FPGA and meet timing at the selected 50 MHz internal CNN clock.

## Hybrid FPGA-compatible temporal buffering

| Item | Result |
|---|---:|
| Frames processed per temporal sequence | 4 |
| Feature values per frame | 8,192 |
| Total temporal feature values | 32,768 |
| Feature value type | signed 8-bit |
| Temporal frames captured | 4 |
| Output-stream address errors | 0 |
| Output-stream X/Z values | 0 |
| Output-stream mismatches | 0 |
| Temporal-buffer X/Z values | 0 |
| Temporal-buffer mismatches | 0 |

The four-frame temporal buffer stores the generated CNN feature vectors sequentially:

| Frame | Buffer address range |
|---|---:|
| Frame 0 | 0 to 8,191 |
| Frame 1 | 8,192 to 16,383 |
| Frame 2 | 16,384 to 24,575 |
| Frame 3 | 24,576 to 32,767 |

The temporal buffer creates the FPGA-compatible input representation required for CNN-GRU classification.

## Hybrid CNN-GRU validation

| Item | Original CNN-GRU features | FPGA-compatible reconstructed features |
|---|---:|---:|
| Ground truth | Car present | Car present |
| Predicted class | Car present | Car present |
| Prediction confidence | 96.25% | 96.66% |
| Classification correct | Yes | Yes |
| Final prediction preserved | - | Yes |

The selected four-frame validation sequence preserved the original CNN-GRU decision after FPGA-compatible feature quantization and reconstruction.

## Feature and logit difference

| Comparison metric | Result |
|---|---:|
| Maximum feature difference | 0.0142679811 |
| Mean feature difference | 0.0018423868 |
| Maximum CNN-GRU logit difference | 0.0596141815 |
| Final class prediction preserved | Yes |

The numerical differences were caused by fixed-point quantization and reconstruction. They did not change the final CNN-GRU class prediction.

## Full-test quantization consistency

| Metric | Floating-point features | Quantized/reconstructed features |
|---|---:|---:|
| Test accuracy | 98.80% | 98.80% |
| Precision | 99.56% | 99.56% |
| Recall | 99.12% | 99.12% |
| F1-score | 99.34% | 99.34% |
| Prediction preservation | - | 750 / 750 |

Across all 750 test sequences, feature quantization and reconstruction preserved every CNN-GRU prediction.

## Hybrid FPGA-side implementation

| Resource | Utilisation |
|---|---:|
| LUTs | 4,112 |
| Registers | 786 |
| BRAM tiles | 45 |
| DSP48E1 blocks | 8 |
| Internal CNN clock | 50 MHz |
| Setup slack | 0.698 ns |
| Bitstream generation | Successful |

The hybrid FPGA-side design includes the W8A8 CNN feature extractor, four-frame controller, temporal feature buffer, clock-divider logic, board-level controls, and status-output logic.

The main hardware constraint was block-RAM utilisation, while LUT, register, DSP, and I/O utilisation remained comparatively low.

## Physical Basys-3 validation

| LED signal | Final observed state | Interpretation |
|---|---|---|
| LD0 - Done | ON | Processing completed |
| LD1 - Busy | OFF | Processing no longer active |
| LD2 - Started | ON | Start command accepted |
| LD3 - Pass | ON | Internal board-level verification passed |
| LD4 - Fail | OFF | No failure condition detected |

The physical Basys-3 validation confirmed that the generated bitstream was programmed successfully, accepted reset and start controls, completed the four-frame processing sequence, and reached the expected PASS state.

## Board-level RTL latency estimate

| Measurement item | Result |
|---|---:|
| Start accepted time | 605 ns |
| Done and Pass time | 4,097.578525 ms |
| Total four-frame latency | 4,097.577920 ms |
| Average latency per frame | 1,024.394480 ms/frame |
| Estimated frame throughput | 0.976186 frames/s |
| Final Done state | 1 |
| Final Busy state | 0 |
| Final Started state | 1 |
| Final Pass state | 1 |
| Final Fail state | 0 |

This is an RTL simulation-based board-level latency estimate, not an external physical timing measurement. The physical board validation confirms successful board execution, while the detailed latency value is derived from simulation monitoring of the board-level control signals.

## Main conclusion

The project demonstrates a working hybrid FPGA-CNN-GRU perception workflow:

- CNN-based spatial perception was developed and quantized.
- W8A8 fixed-point preparation was completed for FPGA implementation.
- The Verilog CNN feature extractor generated 8,192 verified feature values per frame.
- Temporal CNN-RNN, CNN-LSTM, and CNN-GRU models were compared.
- CNN-GRU was selected as the strongest balance between recall, F1-score, and complexity.
- Four-frame temporal feature buffering generated a 32,768-value FPGA-compatible sequence.
- CNN-GRU prediction was preserved after feature quantization and reconstruction.
- The FPGA-side design was synthesized, implemented, timing-closed, converted to bitstream, and physically validated on Basys-3.
