Exported KITTI baseline CNN conv weights for FPGA.
Files:
  conv1_w.txt : int8 weights flattened
  conv1_b.txt : int32 bias (provisional scaling)
  conv2_w.txt : int8 weights flattened
  conv2_b.txt : int32 bias (provisional scaling)
  scales.json : weight scales and layout notes

Weight tensor layout (PyTorch): (out_ch, in_ch, kH, kW)
Flattened in C-order. Verilog must read in same order.
