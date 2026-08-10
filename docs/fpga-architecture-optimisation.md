# FPGA-Oriented CNN Architecture Optimisation

## Overview

After the Basys-3 to Nexys Video scalability study demonstrated that a larger FPGA did not automatically reduce execution latency, the CNN temporal feature-extraction architecture was redesigned to make better use of FPGA-specific parallelism and pipelining.

The optimisation objective was to reduce execution cycles while preserving:

- the W8A8 quantized CNN model;
- exact fixed-point numerical behaviour;
- four consecutive 64 x 64 RGB input frames;
- 8,192 signed 8-bit CNN features per frame;
- the 32,768-value four-frame temporal feature sequence;
- the 50 MHz CNN core clock.

The optimisation was performed incrementally so that the performance impact of each architectural change could be measured independently.

---

## Starting Point

The original architecture required:

| Metric | Original Architecture |
|---|---:|
| Four-frame latency | 4097.577920 ms |
| Average latency per frame | 1024.394480 ms |
| Throughput | 0.976186 frames/s |
| CNN core clock | 50 MHz |

Cycle-level analysis identified Conv2 as the dominant bottleneck.

Conv2 required approximately:

```text
47,028,224 cycles per frame