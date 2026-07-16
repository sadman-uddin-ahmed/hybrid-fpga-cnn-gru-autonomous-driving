`timescale 1ns / 1ps

module conv1_pixel_compute #(
    parameter integer SCALE_MULT  = 1301962,
    parameter integer SCALE_SHIFT = 30
)(
    // Channel 0 pixels
    input wire signed [7:0] ch0_pixel_00,
    input wire signed [7:0] ch0_pixel_01,
    input wire signed [7:0] ch0_pixel_02,
    input wire signed [7:0] ch0_pixel_10,
    input wire signed [7:0] ch0_pixel_11,
    input wire signed [7:0] ch0_pixel_12,
    input wire signed [7:0] ch0_pixel_20,
    input wire signed [7:0] ch0_pixel_21,
    input wire signed [7:0] ch0_pixel_22,
    // Channel 1 pixels
    input wire signed [7:0] ch1_pixel_00,
    input wire signed [7:0] ch1_pixel_01,
    input wire signed [7:0] ch1_pixel_02,
    input wire signed [7:0] ch1_pixel_10,
    input wire signed [7:0] ch1_pixel_11,
    input wire signed [7:0] ch1_pixel_12,
    input wire signed [7:0] ch1_pixel_20,
    input wire signed [7:0] ch1_pixel_21,
    input wire signed [7:0] ch1_pixel_22,
    // Channel 2 pixels
    input wire signed [7:0] ch2_pixel_00,
    input wire signed [7:0] ch2_pixel_01,
    input wire signed [7:0] ch2_pixel_02,
    input wire signed [7:0] ch2_pixel_10,
    input wire signed [7:0] ch2_pixel_11,
    input wire signed [7:0] ch2_pixel_12,
    input wire signed [7:0] ch2_pixel_20,
    input wire signed [7:0] ch2_pixel_21,
    input wire signed [7:0] ch2_pixel_22,
    // Channel 0 weights
    input wire signed [7:0] ch0_weight_00,
    input wire signed [7:0] ch0_weight_01,
    input wire signed [7:0] ch0_weight_02,
    input wire signed [7:0] ch0_weight_10,
    input wire signed [7:0] ch0_weight_11,
    input wire signed [7:0] ch0_weight_12,
    input wire signed [7:0] ch0_weight_20,
    input wire signed [7:0] ch0_weight_21,
    input wire signed [7:0] ch0_weight_22,
    // Channel 1 weights
    input wire signed [7:0] ch1_weight_00,
    input wire signed [7:0] ch1_weight_01,
    input wire signed [7:0] ch1_weight_02,
    input wire signed [7:0] ch1_weight_10,
    input wire signed [7:0] ch1_weight_11,
    input wire signed [7:0] ch1_weight_12,
    input wire signed [7:0] ch1_weight_20,
    input wire signed [7:0] ch1_weight_21,
    input wire signed [7:0] ch1_weight_22,
    // Channel 2 weights
    input wire signed [7:0] ch2_weight_00,
    input wire signed [7:0] ch2_weight_01,
    input wire signed [7:0] ch2_weight_02,
    input wire signed [7:0] ch2_weight_10,
    input wire signed [7:0] ch2_weight_11,
    input wire signed [7:0] ch2_weight_12,
    input wire signed [7:0] ch2_weight_20,
    input wire signed [7:0] ch2_weight_21,
    input wire signed [7:0] ch2_weight_22,
    input wire signed [31:0] bias_value,
    output wire signed [31:0] accumulator_output,
    output wire signed [7:0]  quantized_output
);
    wire signed [31:0] channel0_mac_output;
    wire signed [31:0] channel1_mac_output;
    wire signed [31:0] channel2_mac_output;
    assign accumulator_output =
        bias_value +
        channel0_mac_output +
        channel1_mac_output +
        channel2_mac_output;
    conv3x3_mac_int8 channel0_mac (
        .pixel_00(ch0_pixel_00),
        .pixel_01(ch0_pixel_01),
        .pixel_02(ch0_pixel_02),
        .pixel_10(ch0_pixel_10),
        .pixel_11(ch0_pixel_11),
        .pixel_12(ch0_pixel_12),
        .pixel_20(ch0_pixel_20),
        .pixel_21(ch0_pixel_21),
        .pixel_22(ch0_pixel_22),
        .weight_00(ch0_weight_00),
        .weight_01(ch0_weight_01),
        .weight_02(ch0_weight_02),
        .weight_10(ch0_weight_10),
        .weight_11(ch0_weight_11),
        .weight_12(ch0_weight_12),
        .weight_20(ch0_weight_20),
        .weight_21(ch0_weight_21),
        .weight_22(ch0_weight_22),
        .mac_output(channel0_mac_output)
    );
    conv3x3_mac_int8 channel1_mac (
        .pixel_00(ch1_pixel_00),
        .pixel_01(ch1_pixel_01),
        .pixel_02(ch1_pixel_02),
        .pixel_10(ch1_pixel_10),
        .pixel_11(ch1_pixel_11),
        .pixel_12(ch1_pixel_12),
        .pixel_20(ch1_pixel_20),
        .pixel_21(ch1_pixel_21),
        .pixel_22(ch1_pixel_22),
        .weight_00(ch1_weight_00),
        .weight_01(ch1_weight_01),
        .weight_02(ch1_weight_02),
        .weight_10(ch1_weight_10),
        .weight_11(ch1_weight_11),
        .weight_12(ch1_weight_12),
        .weight_20(ch1_weight_20),
        .weight_21(ch1_weight_21),
        .weight_22(ch1_weight_22),
        .mac_output(channel1_mac_output)
    );
    conv3x3_mac_int8 channel2_mac (
        .pixel_00(ch2_pixel_00),
        .pixel_01(ch2_pixel_01),
        .pixel_02(ch2_pixel_02),
        .pixel_10(ch2_pixel_10),
        .pixel_11(ch2_pixel_11),
        .pixel_12(ch2_pixel_12),
        .pixel_20(ch2_pixel_20),
        .pixel_21(ch2_pixel_21),
        .pixel_22(ch2_pixel_22),
        .weight_00(ch2_weight_00),
        .weight_01(ch2_weight_01),
        .weight_02(ch2_weight_02),
        .weight_10(ch2_weight_10),
        .weight_11(ch2_weight_11),
        .weight_12(ch2_weight_12),
        .weight_20(ch2_weight_20),
        .weight_21(ch2_weight_21),
        .weight_22(ch2_weight_22),
        .mac_output(channel2_mac_output)
    );
    relu_quantize_int8 #(
        .SCALE_MULT(SCALE_MULT),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) output_quantizer (
        .accumulator_in(accumulator_output),
        .quantized_out(quantized_output)
    );
endmodule