# FPGA Device Scalability: Basys-3 to Nexys Video

## Overview

The validated W8A8 CNN temporal feature-extraction architecture was ported from the Digilent Basys-3 to the higher-capacity Digilent Nexys Video FPGA platform.

The purpose of this experiment was to separate two different questions:
1. Does a larger FPGA provide greater implementation headroom?
2. Does moving the unchanged RTL architecture to a larger FPGA automatically reduce execution latency?

To make the comparison controlled, the CNN architecture, quantized parameters, fixed-point arithmetic, four-frame temporal buffering, processing schedule, and 50 MHz internal CNN clock were preserved.

The result was clear:

> The Nexys Video substantially improved resource scalability, but the unchanged RTL architecture did not become faster.

---

## FPGA Platforms
| Platform | FPGA Family / Device | CNN Core Clock |
| --- | --- | ---: |
| Digilent Basys-3 | Xilinx Artix-7 XC7A35T | 50 MHz |
| Digilent Nexys Video | Xilinx Artix-7 XC7A200T | 50 MHz |

The Nexys Video provides substantially greater FPGA capacity than the Basys-3, allowing the same architecture to occupy a much smaller fraction of the available resources.

---

## Functional Equivalence

The Nexys Video port retained the same:

- W8A8 quantized CNN arithmetic
- Conv1, ReLU and MaxPool processing
- Conv2, ReLU and MaxPool processing
- 8,192 signed 8-bit output features per frame
- four-frame temporal sequence
- 32,768-value temporal feature buffer
- fixed-point requantization behaviour
- 50 MHz CNN core clock

A complete four-frame RTL regression confirmed numerical equivalence.

### Regression Result

| Verification Item | Result |
| --- | ---: |
| Frames processed | 4 |
| Features per frame | 8,192 |
| Total temporal features | 32,768 |
| Address errors | 0 |
| Unknown X/Z values | 0 |
| Stream mismatches | 0 |
| Temporal-buffer mismatches | 0 |

The FPGA device change therefore did not alter the numerical CNN feature sequence.

---

## Resource Scalability

The principal benefit of the Nexys Video was the reduction in percentage utilisation.

| Resource | Basys-3 | Nexys Video |
| --- | ---: | ---: |
| Slice LUTs | 19.77% | 3.06% |
| Slice Registers | 1.89% | 0.27% |
| Block RAM | 90.00% | 12.33% |
| DSP48E1 | 8.89% | 1.08% |

The unchanged architecture continued to require approximately the same absolute hardware resources, including 45 block-RAM tiles and 8 DSP48E1 blocks.

The important difference was therefore not that the computation became smaller, but that the larger FPGA provided substantially more unused capacity.

In particular, reducing BRAM utilisation from 90.00% to 12.33% removed the most significant resource-capacity constraint of the Basys-3 implementation.

This additional headroom made later architectural techniques such as memory banking, parallel MAC execution and deeper pipelining practical.

---

## Timing Closure

Both implementations met timing at the controlled 50 MHz CNN core frequency.

| Platform | Target Period | Setup WNS |
| --- | ---: | ---: |
| Basys-3 | 20 ns | +0.698 ns |
| Nexys Video | 20 ns | +0.222 ns |

The Nexys Video implementation therefore met the required timing constraint, but the unchanged architecture did not gain sufficient timing margin for a direct transition to a 100 MHz CNN core.

The implemented Nexys Video critical path was approximately 18.880 ns, while a 100 MHz clock would require a path of approximately 10 ns or less.

A higher-capacity FPGA therefore did not eliminate the architectural critical path.

---

## Latency Comparison

The board-level RTL simulation latency remained identical on both devices.

| Metric | Basys-3 | Nexys Video |
| --- | ---: | ---: |
| Four-frame latency | 4097.577920 ms | 4097.577920 ms |
| Average latency per frame | 1024.394480 ms | 1024.394480 ms |
| Estimated throughput | 0.976186 frames/s | 0.976186 frames/s |

There was therefore:

```text
0% latency improvement from the device migration alone
```

at the controlled 50 MHz CNN core clock.

This result was important because it demonstrated that the approximately one-second-per-frame limitation was not primarily caused by insufficient FPGA resources.

---

## Bottleneck Analysis

Cycle-level analysis identified Conv2 as the dominant execution bottleneck.

Conv2 required approximately:

```text
47,028,224 cycles per frame
```

At 50 MHz, this corresponds to approximately:

```text
940.564480 ms per frame
```

This represented approximately:

```text
91.82% of total frame latency
```

The architecture was therefore dominated by the serial Conv2 processing schedule rather than by FPGA device capacity.

A separate limitation was the long Conv1 arithmetic path, which restricted straightforward clock-frequency scaling.

---

## Physical Nexys Video Validation

The Nexys Video implementation successfully completed:

- synthesis
- placement
- routing
- timing analysis
- bitstream generation
- FPGA programming
- physical board execution

During physical execution, the design entered the expected processing state and subsequently completed with the expected success indication.

This confirmed that the port was not limited to RTL simulation or Vivado implementation reports.

---

## Key Engineering Finding

The device-scaling experiment demonstrated an important FPGA design principle:

> More FPGA resources do not automatically produce lower latency. The additional resources must be exploited through architectural parallelism, pipelining and memory restructuring.

The Nexys Video solved the immediate resource-capacity problem, particularly the high Basys-3 BRAM utilisation, but it did not change the number of processing cycles required by the existing serial RTL state machines.

The additional Nexys Video headroom therefore became an architectural opportunity rather than an automatic performance improvement.

This finding motivated the subsequent FPGA-oriented architecture optimisation work.

---

## Measurement Note

The reported execution latency values are derived from board-level RTL simulation using the FPGA top-level architecture.

Physical FPGA programming and execution were independently demonstrated on the Nexys Video, but the latency was not directly measured using an on-board cycle counter, UART timing output, Integrated Logic Analyzer, external timing pin, or oscilloscope.

The latency figures should therefore be interpreted as **board-level RTL simulation estimates**, not direct physical timing measurements.