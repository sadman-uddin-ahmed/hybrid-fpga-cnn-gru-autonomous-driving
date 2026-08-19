# Streaming Architecture Verification

Selected self-checking Verilog testbenches for the FPGA-native streaming/dataflow CNN architecture.

The verification set covers:

- final Nexys Video board-wrapper latency regression
- exact four-frame temporal feature verification
- full streaming CNN regression
- spatial window replay and backpressure handling
- streaming SAME-padding behaviour
- final feature reordering
- four-lane convolution datapath operation

The complete regression uses the curated CNN parameters, input frames, and expected feature vectors provided under `verilog/verification_data/`.

Development-only and redundant intermediate testbenches are intentionally omitted from the public portfolio.