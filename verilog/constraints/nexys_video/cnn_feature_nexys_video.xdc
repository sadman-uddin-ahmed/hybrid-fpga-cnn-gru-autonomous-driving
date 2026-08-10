## Nexys Video constraints
## System clock
## 100 MHz onboard oscillator
set_property -dict { PACKAGE_PIN R4 IOSTANDARD LVCMOS33 } \
    [get_ports {clk}]
create_clock -add -name board_clk \
    -period 10.000 \
    -waveform {0.000 5.000} \
    [get_ports {clk}]
## 50 MHz generated CNN core clock
## The original divide-by-two clocking architecture is unchanged.
create_generated_clock -name cnn_core_clk \
    -source [get_ports {clk}] \
    -divide_by 2 \
    [get_pins {cnn_feature_demo_top_inst/cnn_core_clk_buf/O}]
## Push buttons
## BTNC: synchronous reset input after internal synchronisation
set_property -dict { PACKAGE_PIN B22 IOSTANDARD LVCMOS12 } \
    [get_ports {reset_button}]
## BTNU: start input
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
## LD5: Status/debug bit 0
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS25 } \
    [get_ports {led[5]}]
## LD6: Status/debug bit 1
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS25 } \
    [get_ports {led[6]}]
## LD7: Status/debug bit 2
set_property -dict { PACKAGE_PIN Y13 IOSTANDARD LVCMOS25 } \
    [get_ports {led[7]}]
## Human-speed demonstration I/O timing treatment
## The buttons are asynchronous human-operated inputs and are synchronised internally by cnn_feature_demo_top.
set_false_path -from [get_ports {reset_button}]
set_false_path -from [get_ports {start_button}]
## LEDs are status indicators, not synchronous external interfaces.
set_false_path -to [get_ports {led[*]}]
## Device configuration properties
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
