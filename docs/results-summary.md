# Results Summary

This document summarises the principal results obtained during the development, quantisation, temporal-model evaluation, FPGA implementation, architectural optimisation, and physical validation of the autonomous-driving perception system.

---

## Project Configuration

| Item | Configuration |
|---|---:|
| Application | Autonomous-driving perception |
| Input | Four consecutive RGB frames |
| Input resolution | 64 × 64 |
| CNN quantisation | W8A8 |
| CNN structure | Conv1 → ReLU → MaxPool → Conv2 → ReLU → MaxPool |
| CNN features per frame | 8,192 signed 8-bit values |
| Temporal features | 32,768 signed 8-bit values |
| FPGA RTL language | Verilog |
| Final FPGA board | Digilent Nexys Video |
| Final FPGA device | `xc7a200tsbg484-1` |
| External board clock | 100 MHz |
| CNN core clock | 50 MHz |
| FPGA tool | Vivado 2025.1 |

The CNN numerical behaviour and W8A8 feature representation were kept fixed during the FPGA architectural optimisation work.

---

# CNN and Temporal-Model Results

## CNN Baseline

The CNN provides the spatial feature-extraction stage used throughout the project.

After the second convolution, ReLU, and 2 × 2 MaxPool stage, each frame produces:

```text
32 × 16 × 16 = 8,192 features
```

These 8,192 values form the FPGA-compatible CNN feature vector.

For a four-frame temporal sequence:

```text
4 × 8,192 = 32,768 temporal features
```

---

## W8A8 Quantisation

The CNN was converted to an 8-bit weight and 8-bit activation representation for FPGA implementation.

The selected W8A8 configuration preserves the required CNN behaviour while allowing the feature-extraction datapath to be represented using fixed-point arithmetic in Verilog RTL.

The FPGA feature stream therefore consists of signed 8-bit output values.

---

## Temporal Model Comparison

Three recurrent temporal models were evaluated using four-frame CNN feature sequences.

| Model | Test Accuracy | Recall | F1-score |
|---|---:|---:|---:|
| CNN-RNN | 98.40% | 99.41% | 99.12% |
| CNN-LSTM | 99.07% | 99.56% | 99.49% |
| CNN-GRU | **99.07%** | **99.85%** | **99.49%** |

CNN-GRU was selected as the temporal model because it matched the CNN-LSTM test accuracy and F1-score while achieving the highest recall.

---

## Hybrid CNN-GRU Validation

The FPGA-compatible W8A8 CNN feature representation was reconstructed and supplied to the host-side CNN-GRU model.

The hybrid validation preserved:

```text
750 / 750 test predictions
```

This demonstrated that the FPGA-compatible quantised CNN features retained the temporal-classification behaviour required by the CNN-GRU stage.

---

# FPGA Functional Verification

The CNN feature extractor was implemented in Verilog RTL and verified against Python-generated expected vectors.

For each frame:

```text
8,192 signed 8-bit CNN features
```

are generated.

Across four frames:

```text
32,768 signed 8-bit temporal features
```

are stored.

The required temporal address ranges are:

| Frame | Address Range |
|---|---:|
| Frame 0 | 0 to 8,191 |
| Frame 1 | 8,192 to 16,383 |
| Frame 2 | 16,384 to 24,575 |
| Frame 3 | 24,576 to 32,767 |

Exact expected-vector agreement is mandatory for the FPGA implementation.

---

# Original FPGA Architecture

The original FPGA implementation used a substantially serialized controller-based execution strategy.

At the fixed 50 MHz CNN core clock, its measured board-wrapper RTL latency was:

| Metric | Original Architecture |
|---|---:|
| Four-frame latency | **4097.577920 ms** |
| Average latency per frame | **1024.394480 ms** |
| Throughput | **0.976186 fps** |
| CNN core clock | 50 MHz |

This implementation was functionally correct but exhibited approximately one second of latency per frame.

---

# FPGA Device Scalability

The validated design was ported from the Basys-3 to the larger Nexys Video while deliberately retaining the same CNN architecture, W8A8 arithmetic, processing schedule, and 50 MHz CNN core clock.

The larger FPGA provided substantially more available resources, but the execution latency remained unchanged.

| Metric | Basys-3 | Nexys Video |
|---|---:|---:|
| Four-frame latency | 4097.577920 ms | 4097.577920 ms |
| Average latency/frame | 1024.394480 ms | 1024.394480 ms |
| Throughput | 0.976186 fps | 0.976186 fps |

This demonstrated that FPGA capacity alone was not the dominant performance limitation.

---

# Latency Bottleneck Analysis

Cycle-level analysis showed that Conv2 dominated the original implementation latency.

| Conv2 Metric | Result |
|---|---:|
| Approximate cycles/frame | 47,028,224 |
| Approximate latency at 50 MHz | 940.564480 ms |
| Share of frame latency | 91.82% |

The dominant issue was the serialized execution strategy used for memory access, multiplication, accumulation, channel processing, and output generation.

This motivated architectural optimisation rather than simply moving to a larger FPGA.

---

# Scheduled FPGA Architectural Optimisation

The first architectural optimisation phase retained the existing general execution structure while progressively increasing useful arithmetic concurrency.

## Optimisation Progression

| Architecture | Four-Frame Latency | Average Latency/Frame | Throughput | Speedup vs Original |
|---|---:|---:|---:|---:|
| Original scheduled architecture | 4097.577920 ms | 1024.394480 ms | 0.976186 fps | 1.00× |
| Pipelined Conv2 MAC | 752.128960 ms | 188.032240 ms | 5.318237 fps | 5.45× |
| Four-lane Conv2 | 449.352640 ms | 112.338160 ms | 8.901695 fps | 9.12× |
| Four-lane Conv1 + Conv2 | **227.185600 ms** | **56.796400 ms** | **17.606750 fps** | **18.04×** |

The final scheduled four-lane architecture therefore achieved:

```text
4097.577920 ms → 227.185600 ms
```

at the same 50 MHz CNN core clock.

This represented:

```text
18.04× speedup
```

relative to the original implementation.

---

# FPGA-Native Streaming/Dataflow Architecture

The next optimisation phase redesigned the CNN around a substantially more FPGA-oriented streaming/dataflow execution model.

The final processing architecture is:

```text
Padded RGB input stream
        |
        v
Multichannel streaming 3 × 3 window generation
        |
        v
Spatial window-set replay buffering
        |
        v
Four-lane convolution
        |
        v
Channel accumulation
        |
        v
Shared pipelined requantisation
        |
        v
ReLU
        |
        v
Streaming 2 × 2 MaxPool
        |
        v
Streaming SAME-padding
        |
        v
Four-lane Conv2
        |
        v
ReLU
        |
        v
Streaming 2 × 2 MaxPool
        |
        v
Raw feature stream
        |
        v
Feature reorder buffer
        |
        v
8,192-value channel-major frame vector
        |
        v
Four-frame temporal BRAM
        |
        v
32,768 temporal features
```

The architecture uses ready/valid flow control so that backpressure can propagate safely through the streaming pipeline.

Full technical details are available in:

[FPGA-Native Streaming Dataflow Architecture](fpga-streaming-dataflow.md)

---

## Streaming Window Generation

The architecture converts the incoming feature stream into 3 × 3 spatial windows.

Spatial window data is retained and replayed for groups of output channels instead of repeatedly rebuilding the same neighbourhood.

Relevant RTL includes:

```text
streaming_spatial_frontend.v
streaming_multichannel_3x3_window_generator.v
streaming_3x3_window_generator.v
spatial_window_set_replay_buffer.v
```

This reduces unnecessary data movement and enables greater processing overlap.

---

## Four-Lane Convolution

The principal convolution datapath processes four output channels concurrently.

Each lane evaluates a complete 3 × 3 kernel containing nine multiplications.

Therefore:

```text
4 lanes × 9 multiplications = 36 kernel multiplications
```

can be active during four-lane convolution processing.

Relevant RTL includes:

```text
convolution_four_lane_datapath.v
conv3x3_four_lane_channel_engine.v
conv3x3_four_lane_parallel.v
conv3x3_parallel_dot_product.v
conv_four_lane_channel_accumulator.v
convolution_group_cadence_controller.v
```

---

## Parameter Banking and Requantisation

Parallel convolution processing requires multiple parameters and accumulated results to be handled concurrently.

The final design therefore includes parameter banking and pipelined requantisation logic.

Relevant RTL includes:

```text
streaming_convolution_parameter_bank.v
four_lane_requantize_pipeline.v
four_lane_requantize_dispatcher.v
requantize_relu_pipeline.v
```

The architectural redesign changes the hardware execution strategy while preserving the validated W8A8 numerical behaviour.

---

## Streaming MaxPool and SAME Padding

Conv1 and Conv2 are connected through streaming processing stages rather than waiting for an entire intermediate feature map to complete before downstream processing begins.

Relevant modules include:

```text
streaming_maxpool_2x2.v
streaming_same_padding_adapter.v
streaming_convolution_maxpool_layer.v
streaming_conv2_maxpool_layer.v
streaming_conv2_layer.v
```

---

## Feature Reordering

The natural feature ordering produced by the streaming CNN differs from the established channel-major temporal interface.

The final architecture therefore includes:

```text
streaming_feature_reorder_buffer.v
```

For the final 32 × 16 × 16 CNN output, the required channel-major address is:

```text
feature_address =
    output_channel × 256
    + y × 16
    + x
```

This restores the original 8,192-value feature ordering before temporal buffering.

---

# Final Streaming Functional Verification

The complete four-frame streaming regression verified both architectural behaviour and exact numerical equivalence.

| Verification Metric | Result |
|---|---:|
| Frames processed | 4 |
| Accepted padded input values | 52,272 |
| Raw CNN features generated | 32,768 |
| Reordered features generated | 32,768 |
| Expected-vector comparisons | **32,768** |
| Expected-vector mismatches | **0** |
| Duplicate feature addresses | 0 |
| Missing feature addresses | 0 |
| Address/frame-index errors | 0 |
| X/Z feature errors | 0 |
| Frame completion pulses | 4 |
| Temporal frames captured | 4 |
| `temporal_capture_complete` | 1 |
| Final regression | **PASS** |

The final architecture therefore reproduced:

```text
32,768 / 32,768 expected values
```

with:

```text
0 mismatches
```

---

# Final Streaming Latency

The final board-wrapper regression includes:

```text
100 MHz external board clock
50 MHz generated CNN core clock
parameter loading
four-frame input feeding
streaming CNN execution
feature reordering
temporal feature capture
completion/status logic
```

The measured result was:

| Metric | Final Streaming Result |
|---|---:|
| Four-frame execution cycles | 578,873 |
| Four-frame latency | **11.577460 ms** |
| Average latency/frame | **2.894365 ms** |
| Throughput | **345.498926 fps** |
| CNN core clock | **50 MHz** |

---

## Improvement over the Previous Architecture

The preceding scheduled four-lane architecture achieved:

```text
227.185600 ms / four frames
```

The final streaming architecture achieved:

```text
11.577460 ms / four frames
```

Therefore:

| Metric | Result |
|---|---:|
| Speedup vs preceding architecture | **19.623095×** |
| Latency reduction vs preceding architecture | **94.903964%** |
| CNN core frequency increase | **None** |

The performance gain was therefore achieved by architectural redesign rather than clock-frequency scaling.

---

## Improvement over the Original Architecture

The complete FPGA architecture progression is:

| Architecture | Four-Frame Latency | Throughput |
|---|---:|---:|
| Original scheduled architecture | 4097.577920 ms | 0.976186 fps |
| Pipelined Conv2 MAC | 752.128960 ms | 5.318237 fps |
| Four-lane Conv2 | 449.352640 ms | 8.901695 fps |
| Four-lane Conv1 + Conv2 | 227.185600 ms | 17.606750 fps |
| **FPGA-native streaming/dataflow** | **11.577460 ms** | **345.498926 fps** |

Relative to the original architecture, the final implementation provides approximately:

```text
353.93× speedup
99.717% latency reduction
```

with the CNN core clock remaining fixed at 50 MHz throughout the controlled comparison.

---

# Per-Frame Streaming Measurements

The four processed frames showed consistent timing behaviour.

| Measurement | Result |
|---|---:|
| First accepted input → first raw CNN output | 0.168300 ms |
| First accepted input → final raw CNN output | 2.705000 ms |
| Final raw output → reordered frame completion | 0.163860 ms |
| First accepted input → frame completion | 2.868860 ms |

The complete four-frame average of 2.894365 ms/frame also includes board-wrapper and parameter-loading overhead.

The regression additionally exercised downstream backpressure during execution.

---

# Final Nexys Video Implementation

The streaming design was synthesised, placed, routed, and used for bitstream generation on:

```text
Digilent Nexys Video
Xilinx Artix-7 XC7A200T
xc7a200tsbg484-1
Vivado 2025.1
```

---

## Post-Implementation Resource Utilisation

| Resource | Used | Available | Utilisation |
|---|---:|---:|---:|
| Slice LUTs | 11,194 | 133,800 | **8.37%** |
| LUTs as logic | 5,672 | 133,800 | 4.24% |
| LUTs as memory | 5,522 | - | - |
| Distributed RAM LUTs | 5,400 | - | - |
| Slice Registers | 6,223 | 267,600 | **2.33%** |
| Block RAM | 28.5 | 365 | **7.81%** |
| DSP48E1 | 104 | 740 | **14.05%** |
| BUFGCTRL | 2 | 32 | **6.25%** |

Despite the increased streaming concurrency and arithmetic parallelism, the final architecture retains substantial resource headroom on the Nexys Video.

---

# Routed Timing

The final implementation closes timing at the controlled 50 MHz CNN core clock.

| Timing Metric | Result |
|---|---:|
| Required CNN clock period | 20.000 ns |
| WNS | **+0.680 ns** |
| TNS | **0.000 ns** |
| WHS | **+0.047 ns** |
| THS | **0.000 ns** |
| Setup violations | **0** |
| Hold violations | **0** |
| Routable nets | 19,109 |
| Fully routed nets | 19,109 |
| Routing errors | **0** |

The worst reported setup path was dominated by routing delay rather than logic delay.

---

# Power Estimate

Vivado post-route vectorless power analysis estimated:

| Metric | Result |
|---|---:|
| Total on-chip power | **0.213 W** |
| Dynamic power | 0.077 W |
| Static power | 0.136 W |
| Estimated junction temperature | 25.7 °C |
| Confidence | Medium |

These values are Vivado implementation estimates and are not direct physical measurements of board power consumption.

---

# Bitstream Generation

The final streaming implementation completed:

```text
Synthesis       PASS
Implementation  PASS
Timing          PASS
Routing         PASS
Bitstream       PASS
```

This confirms that the architecture is not limited to behavioural simulation and can be mapped successfully onto the target Nexys Video FPGA.

---

# Physical Nexys Video Validation

The generated bitstream was programmed onto the physical Digilent Nexys Video board.

The board-level top provides status outputs for:

```text
Done
Busy
Started
Pass
Fail
temporal_capture_complete
captured frame-count status
feature-data parity/debug status
```

The final physical execution reached the expected:

```text
Done = asserted
Busy = deasserted
Started = asserted
Pass = asserted
Fail = deasserted
temporal_capture_complete = asserted
```

This validates successful execution of the implemented streaming architecture on the physical FPGA.

The physical LED validation confirms board-level execution and completion status.

Exact 32,768-value numerical equivalence is established by the RTL regression rather than by the LED outputs.

---

# Final Performance Summary

| Metric | Final Result |
|---|---:|
| FPGA board | Digilent Nexys Video |
| FPGA | XC7A200T |
| Device | `xc7a200tsbg484-1` |
| External clock | 100 MHz |
| CNN core clock | 50 MHz |
| Quantisation | W8A8 |
| Frames/sequence | 4 |
| Features/frame | 8,192 |
| Temporal features | 32,768 |
| Four-frame execution cycles | 578,873 |
| Four-frame latency | **11.577460 ms** |
| Average latency/frame | **2.894365 ms** |
| Throughput | **345.498926 fps** |
| Speedup vs preceding architecture | **19.623095×** |
| Latency reduction vs preceding architecture | **94.903964%** |
| Speedup vs original architecture | **353.93×** |
| Total latency reduction vs original | **99.717%** |
| Expected-vector comparisons | **32,768** |
| Feature mismatches | **0** |
| Slice LUT utilisation | **8.37%** |
| Slice Register utilisation | **2.33%** |
| BRAM utilisation | **7.81%** |
| DSP48E1 utilisation | **14.05%** |
| WNS | **+0.680 ns** |
| WHS | **+0.047 ns** |
| Routing errors | **0** |
| Bitstream generation | **PASS** |
| Physical FPGA execution | **PASS** |

---

# Main Engineering Result

The FPGA development demonstrates the following progression:

```text
Original serialized RTL
        |
        | 4097.577920 ms
        v
Pipelined Conv2
        |
        | 752.128960 ms
        v
Four-lane Conv2
        |
        | 449.352640 ms
        v
Four-lane Conv1 + Conv2
        |
        | 227.185600 ms
        v
FPGA-native streaming/dataflow
        |
        | 11.577460 ms
        v
Final validated architecture
```

The central engineering result is that substantially greater performance was obtained by changing the FPGA execution architecture rather than by simply increasing FPGA capacity or clock frequency.

The final design achieves:

```text
4097.577920 ms → 11.577460 ms
```

while retaining:

```text
50 MHz CNN core clock
W8A8 numerical behaviour
32,768 / 32,768 expected features
0 mismatches
successful synthesis
successful implementation
successful timing closure
successful routing
successful bitstream generation
successful physical Nexys Video execution
```

---

# Measurement Scope

The reported latency values are obtained from board-wrapper RTL simulation using the implemented top-level clocking and control structure.

The physical Nexys Video implementation validates successful FPGA execution, completion, temporal capture, and PASS status.

The reported:

```text
11.577460 ms
```

should therefore be interpreted as the verified board-wrapper RTL execution latency rather than a direct oscilloscope, ILA, UART, or external hardware-counter measurement.

Likewise, the Vivado power result is an implementation estimate rather than direct physical board-power measurement.

---

# Supporting Documentation

Detailed project documentation is available in:

- [FPGA-Native Streaming Dataflow Architecture](fpga-streaming-dataflow.md)
- [FPGA Architecture Optimisation](fpga-architecture-optimisation.md)
- [FPGA Device Scalability](fpga-device-scalability.md)
- [Temporal Model Comparison](temporal-model-comparison.md)
- [Dataset and Artifact Notes](dataset-and-artifact-notes.md)

---

# Public Repository Scope

The public repository contains selected:
- Python model-development scripts
- fixed-point quantisation scripts
- hybrid-validation scripts
- Verilog RTL
- self-checking testbenches
- curated verification vectors
- Basys-3 and Nexys Video constraints
- architecture documentation
- simulation evidence
- Vivado implementation evidence
- physical FPGA validation evidence

The repository intentionally excludes:
- full raw datasets
- trained model checkpoints
- bulk generated feature tensors
- complete Vivado build directories
- Vivado cache files
- implementation checkpoints
- generated bitstreams
- full Vivado project archives
- full dissertation reports
- assessment material
- supervisor correspondence