# FPGA-Oriented CNN Architecture Optimisation

## Overview

After the Basys-3 to Nexys Video scalability study demonstrated that a larger FPGA did not automatically reduce execution latency, the CNN temporal feature-extraction architecture was redesigned to make better use of FPGA-specific parallelism and pipelining.

The optimisation objective was to reduce execution cycles while preserving:

- the W8A8 quantized CNN model
- exact fixed-point numerical behaviour
- four consecutive 64 × 64 RGB input frames
- 8,192 signed 8-bit CNN features per frame
- the 32,768-value four-frame temporal feature sequence
- the 50 MHz CNN core clock

The optimisation was performed incrementally so that the performance impact of each architectural change could be measured independently.

---

## Starting Point

The original architecture required:

| Metric | Original Architecture |
| --- | ---: |
| Four-frame latency | 4097.577920 ms |
| Average latency per frame | 1024.394480 ms |
| Throughput | 0.976186 frames/s |
| CNN core clock | 50 MHz |

Cycle-level analysis identified Conv2 as the dominant bottleneck.

Conv2 required approximately:

```text
47,028,224 cycles per frame
```

corresponding to approximately:

```text
940.564480 ms per frame
```

at 50 MHz.

This represented approximately 91.82% of the original frame latency.

The performance limitation was therefore primarily architectural rather than a consequence of insufficient FPGA capacity.

---

## Optimisation Strategy

Three progressive architectural changes were investigated:

1. pipelined Conv2 multiply-accumulate processing
2. four-output-channel parallel Conv2 execution with banked parameter memory
3. four-output-channel parallel Conv1 execution with banked parameter storage

Each accepted architecture had to preserve the exact fixed-point CNN output sequence before further optimisation was performed.

---

## Iteration 1: Pipelined Conv2 MAC

### Original Problem

The original Conv2 controller performed memory access, operand preparation, multiplication and accumulation using a highly sequential state-machine schedule.

Only a limited amount of arithmetic work was therefore completed during each clock cycle.

### Architectural Change

The Conv2 MAC datapath was reorganised around registered arithmetic so that multiplication and accumulation no longer required the same highly separated control-state sequence.

The optimisation preserved:

- signed W8A8 operands
- Conv2 output ordering
- per-output accumulation order
- fixed-point requantisation
- ReLU behaviour
- saturation behaviour
- Conv2 max pooling

### Result

| Metric | Original | Pipelined Conv2 |
| --- | ---: | ---: |
| Four-frame latency | 4097.577920 ms | 752.128960 ms |
| Average per frame | 1024.394480 ms | 188.032240 ms |
| Throughput | 0.976186 fps | 5.318237 fps |
| Speedup | 1.00x | 5.45x |

This demonstrated that a large part of the original latency came from RTL scheduling rather than the CNN computation itself.

---

## Iteration 2: Four-Lane Conv2

Conv2 remained the largest execution component after pipelining, so the next optimisation introduced output-channel parallelism.

### Four-Lane Processing

Instead of calculating one Conv2 output channel at a time, four independent output channels were processed concurrently.

A shared input feature was broadcast to four MAC lanes.

Each lane used:

- its own Conv2 weight
- an independent accumulator
- an independent output channel

This allowed four output channels at the same spatial location to progress simultaneously.

### Banked Parameter Memory

The Conv2 weight memory was divided into four banks to provide the bandwidth required by the four parallel MAC lanes.

Output channels were assigned using:

```text
Bank = Output Channel mod 4
```

The resulting architecture used:

- four parallel W8A8 multiplication paths
- four independent accumulation paths
- four Conv2 weight banks
- four bias banks
- shared input-feature access
- preserved per-channel accumulation order

The complete input feature memory did not need to be replicated.

### Result

| Metric | Pipelined Conv2 | Four-Lane Conv2 |
| --- | ---: | ---: |
| Four-frame latency | 752.128960 ms | 449.352640 ms |
| Average per frame | 188.032240 ms | 112.338160 ms |
| Throughput | 5.318237 fps | 8.901695 fps |
| Speedup vs original | 5.45x | 9.12x |

Conv2 acceleration changed the system bottleneck. Conv1 subsequently became the dominant remaining processing stage.

---

## Conv1 Design-Space Analysis

The remaining Conv1 implementation generated one pooled output channel at a time.

The previous Conv1 schedule required approximately:

```text
3,981,312 cycles per frame
```

or:

```text
79.626240 ms per frame
```

at 50 MHz.

Output-channel parallelism was therefore evaluated for Conv1.

Three candidate architectures were analysed:

| Conv1 Parallelism | Predicted Conv1 Latency | Predicted Four-Frame Latency | Predicted Throughput |
| --- | ---: | ---: | ---: |
| 2 lanes | 42.598400 ms/frame | 301.241280 ms | 13.278393 fps |
| 4 lanes | 24.084480 ms/frame | 227.185600 ms | 17.606750 fps |
| 8 lanes | 14.827520 ms/frame | 190.157760 ms | 21.035166 fps |

The eight-lane architecture offered further performance improvement, but the additional reduction in complete system latency was relatively small compared with the increase in:

- DSP consumption
- accumulator and register count
- activation fan-out
- weight-bank connectivity
- routing pressure
- verification complexity

The four-lane architecture was therefore selected as the design-space knee for this optimisation stage.

---

## Current Four-Lane Conv1 Architecture

The current optimized Conv1 architecture processes four output channels concurrently.

A single signed 8-bit input activation is broadcast to four independent MAC lanes.

Each lane maintains:

- its own signed weight
- a registered signed multiplication result
- an independent signed 64-bit accumulator
- independent pooling state

For each output channel, the original Conv1 arithmetic order remains unchanged.

Each output still accumulates:

```text
3 × 3 × 3 = 27 signed products
```

in the established sequence.

Parallelism therefore changes when independent output channels are calculated, not how an individual output value is calculated.

A shared requantisation datapath was retained to avoid unnecessary replication of the more expensive fixed-point scaling hardware.

---

## Numerical Equivalence

Exact fixed-point equivalence was treated as a mandatory requirement throughout the optimisation.

The current architecture preserves:

- signed 8-bit activations
- signed 8-bit weights
- registered signed multiplication
- original per-channel accumulation order
- signed 64-bit accumulation
- fixed-point scale multiplication
- arithmetic shifting
- rounding behaviour
- ReLU
- positive saturation
- 2 × 2 max pooling

The complete four-frame temporal regression produced:

| Verification Metric | Result |
| --- | ---: |
| Temporal frames | 4 |
| CNN features streamed | 32,768 |
| Stream address errors | 0 |
| Stream X/Z values | 0 |
| Stream mismatches | 0 |
| Temporal-buffer X/Z values | 0 |
| Temporal-buffer mismatches | 0 |
| Regression result | PASS |

All 32,768 streamed and stored CNN feature values remained bit-exact with the established reference vectors.

---

## Complete Performance Progression

| Architecture | Four-Frame Latency | Average per Frame | Throughput | Speedup |
| --- | ---: | ---: | ---: | ---: |
| Original architecture | 4097.577920 ms | 1024.394480 ms | 0.976186 fps | 1.00x |
| Pipelined Conv2 MAC | 752.128960 ms | 188.032240 ms | 5.318237 fps | 5.45x |
| Four-lane Conv2 | 449.352640 ms | 112.338160 ms | 8.901695 fps | 9.12x |
| Four-lane Conv1 + Conv2 | 227.185600 ms | 56.796400 ms | 17.606750 fps | 18.04x |

The overall four-frame latency was reduced from:

```text
4097.577920 ms
```

to:

```text
227.185600 ms
```

corresponding to approximately:

```text
94.46% latency reduction
```

and:

```text
18.04x speedup
```

The CNN core remained at 50 MHz throughout the controlled comparison.

The improvement therefore resulted primarily from reducing architectural execution cycles rather than increasing clock frequency.

---

## FPGA Resource Utilisation

The optimized architecture was implemented on both the Basys-3 and Nexys Video.

| Resource | Basys-3 XC7A35T | Nexys Video XC7A200T |
| --- | ---: | ---: |
| Slice LUTs | 4,876 / 20,800 = 23.44% | 4,859 / 133,800 = 3.63% |
| Slice Registers | 1,206 / 41,600 = 2.90% | 1,206 / 267,600 = 0.45% |
| Block RAM | 44.5 / 50 = 89.00% | 44.5 / 365 = 12.19% |
| DSP48E1 | 16 / 90 = 17.78% | 16 / 740 = 2.16% |

The current architecture uses 16 DSP48E1 blocks, divided between the parallel Conv1 and Conv2 processing structures.

Importantly, the Conv1 optimisation increased arithmetic parallelism without increasing total block-RAM consumption.

Relative to the preceding four-lane Conv2 implementation:

```text
DSP48E1: 13 -> 16
BRAM:    44.5 -> 44.5 tiles
```

while four-frame latency decreased by approximately 49.44%.

---

## Routed Timing

Both FPGA implementations closed timing at the retained 50 MHz CNN core frequency.

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

Both implementations also completed synthesis, placement, routing, design-rule checking and bitstream generation successfully.

The Nexys Video critical setup path remained within the Conv1 hierarchy and was predominantly routing-limited, reflecting the increased fan-out and connectivity introduced by parallel MAC processing.

---

## Engineering Result

The optimisation demonstrates that the original CNN latency was principally a consequence of the hardware processing strategy rather than insufficient FPGA resources.

The progression was:

```text
Serial processing
      |
      v
Pipelined Conv2 MAC
      |
      v
Four-lane Conv2 + banked parameters
      |
      v
Four-lane Conv1 + four-lane Conv2
      |
      v
18.04x architectural speedup
```

Moving the unchanged architecture to a larger FPGA provided resource headroom.

Using that headroom through pipelining, parallel MAC execution and memory banking produced the actual performance improvement.

This distinction between device scaling and architecture scaling is one of the principal engineering findings of the FPGA implementation.

---

## Current Limitations

The current result should be interpreted within the following scope:

- latency is obtained from board-level RTL simulation rather than direct physical timing instrumentation
- the controlled optimisation comparison uses a 50 MHz CNN core clock
- maximum achievable clock frequency has not yet been explored
- power results are Vivado post-route vectorless estimates
- only the CNN temporal feature extractor is implemented in FPGA programmable logic
- the complete CNN-GRU inference pipeline is not currently executed entirely on the FPGA

The current architecture therefore represents a major reduction in FPGA-side CNN feature-extraction latency while leaving additional opportunities for deeper streaming, further parallelism, clock-frequency exploration and end-to-end hardware integration.