## Nexys Video constraints
## Target: xc7a200tsbg484-1
## Top: cnn_feature_streaming_nexys_video_top
## 100 MHz onboard system clock
set_property -dict { PACKAGE_PIN R4 IOSTANDARD LVCMOS33 } \
    [get_ports {clk}]
create_clock -add -name board_clk \
    -period 10.000 \
    -waveform {0.000 5.000} \
    [get_ports {clk}]
## 50 MHz generated CNN core clock
## clk_div2_ff divides the 100 MHz board clock by two,
## And cnn_core_clk_buf distributes it through a BUFG.
create_generated_clock -name cnn_core_clk \
    -source [get_ports {clk}] \
    -divide_by 2 \
    [get_pins {cnn_core_clk_buf/O}]
## Push buttons
## BTNC: reset
set_property -dict { PACKAGE_PIN B22 IOSTANDARD LVCMOS12 } \
    [get_ports {reset_button}]
## BTNU: start
set_property -dict { PACKAGE_PIN F15 IOSTANDARD LVCMOS12 } \
    [get_ports {start_button}]
## User LEDs
## LD0: Done
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS25 } \
    [get_ports {led[0]}]
## LD1: Busy
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS25 } \
    [get_ports {led[1]}]
## LD2: Started
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS25 } \
    [get_ports {led[2]}]
## LD3: Pass
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS25 } \
    [get_ports {led[3]}]
## LD4: Fail
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS25 } \
    [get_ports {led[4]}]
## LD5: temporal_capture_complete
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS25 } \
    [get_ports {led[5]}]
## LD6: captured-frame-count status
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS25 } \
    [get_ports {led[6]}]
## LD7: live / temporal feature-data parity
set_property -dict { PACKAGE_PIN Y13 IOSTANDARD LVCMOS25 } \
    [get_ports {led[7]}]
## Human-operated asynchronous controls are synchronized internally.
set_false_path -from [get_ports {reset_button}]
set_false_path -from [get_ports {start_button}]
## LEDs are status/debug outputs rather than synchronous external interfaces.
set_false_path -to [get_ports {led[*]}]
## Device configuration properties
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]