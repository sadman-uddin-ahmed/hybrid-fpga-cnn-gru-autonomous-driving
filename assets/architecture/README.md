## Architecture diagrams

The main hybrid processing flow is shown above. Additional architecture diagrams are included in `assets/architecture/` for deeper review of the FPGA-side control flow and host-side classification path.

| Diagram | Purpose |
|---|---|
| [`hybrid-architecture.png`](assets/architecture/hybrid-architecture.png) | Full hybrid FPGA-CNN-GRU processing flow |
| [`fpga-side-architecture.png`](assets/architecture/fpga-side-architecture.png) | FPGA-side bitstream architecture, temporal buffering, board controls, and output status |
| [`four-frame-control-flow.png`](assets/architecture/four-frame-control-flow.png) | Four-frame FPGA control sequence for loading, processing, and storing temporal features |
| [`host-side-classification-chain.png`](assets/architecture/host-side-classification-chain.png) | Host-side feature reconstruction, dequantization, tensor reshaping, and CNN-GRU classification |
