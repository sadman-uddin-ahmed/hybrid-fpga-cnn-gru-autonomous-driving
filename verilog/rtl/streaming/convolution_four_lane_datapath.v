`timescale 1ns / 1ps

module convolution_four_lane_datapath #(
    parameter integer INPUT_CHANNELS   = 3,
    parameter integer MIN_GROUP_CYCLES = 4,
    parameter integer SCALE_MULT       = 1301962,
    parameter integer SCALE_SHIFT      = 30
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    output wire                    input_ready,
    input  wire                    first_input_channel,
    input  wire                    last_input_channel,
    input  wire signed [7:0]       input_value_0,
    input  wire signed [7:0]       input_value_1,
    input  wire signed [7:0]       input_value_2,
    input  wire signed [7:0]       input_value_3,
    input  wire signed [7:0]       input_value_4,
    input  wire signed [7:0]       input_value_5,
    input  wire signed [7:0]       input_value_6,
    input  wire signed [7:0]       input_value_7,
    input  wire signed [7:0]       input_value_8,
    input  wire signed [7:0]       weight_lane_0_value_0,
    input  wire signed [7:0]       weight_lane_0_value_1,
    input  wire signed [7:0]       weight_lane_0_value_2,
    input  wire signed [7:0]       weight_lane_0_value_3,
    input  wire signed [7:0]       weight_lane_0_value_4,
    input  wire signed [7:0]       weight_lane_0_value_5,
    input  wire signed [7:0]       weight_lane_0_value_6,
    input  wire signed [7:0]       weight_lane_0_value_7,
    input  wire signed [7:0]       weight_lane_0_value_8,
    input  wire signed [7:0]       weight_lane_1_value_0,
    input  wire signed [7:0]       weight_lane_1_value_1,
    input  wire signed [7:0]       weight_lane_1_value_2,
    input  wire signed [7:0]       weight_lane_1_value_3,
    input  wire signed [7:0]       weight_lane_1_value_4,
    input  wire signed [7:0]       weight_lane_1_value_5,
    input  wire signed [7:0]       weight_lane_1_value_6,
    input  wire signed [7:0]       weight_lane_1_value_7,
    input  wire signed [7:0]       weight_lane_1_value_8,
    input  wire signed [7:0]       weight_lane_2_value_0,
    input  wire signed [7:0]       weight_lane_2_value_1,
    input  wire signed [7:0]       weight_lane_2_value_2,
    input  wire signed [7:0]       weight_lane_2_value_3,
    input  wire signed [7:0]       weight_lane_2_value_4,
    input  wire signed [7:0]       weight_lane_2_value_5,
    input  wire signed [7:0]       weight_lane_2_value_6,
    input  wire signed [7:0]       weight_lane_2_value_7,
    input  wire signed [7:0]       weight_lane_2_value_8,
    input  wire signed [7:0]       weight_lane_3_value_0,
    input  wire signed [7:0]       weight_lane_3_value_1,
    input  wire signed [7:0]       weight_lane_3_value_2,
    input  wire signed [7:0]       weight_lane_3_value_3,
    input  wire signed [7:0]       weight_lane_3_value_4,
    input  wire signed [7:0]       weight_lane_3_value_5,
    input  wire signed [7:0]       weight_lane_3_value_6,
    input  wire signed [7:0]       weight_lane_3_value_7,
    input  wire signed [7:0]       weight_lane_3_value_8,
    input  wire signed [31:0]      bias_value_0,
    input  wire signed [31:0]      bias_value_1,
    input  wire signed [31:0]      bias_value_2,
    input  wire signed [31:0]      bias_value_3,
    output wire signed [7:0]       output_value,
    output wire [1:0]              output_lane_index,
    output wire                    output_valid,
    output wire                    requantize_busy
);
    wire cadence_output_valid;
    wire cadence_first_input_channel;
    wire cadence_last_input_channel;
    wire signed [63:0] accumulated_sum_0;
    wire signed [63:0] accumulated_sum_1;
    wire signed [63:0] accumulated_sum_2;
    wire signed [63:0] accumulated_sum_3;
    wire               accumulated_sum_valid;
    wire requantize_input_ready;
    initial begin
        $display("ACTIVE RTL: convolution_four_lane_datapath CANDIDATE-A V1");
    end
    convolution_group_cadence_controller #(
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .MIN_GROUP_CYCLES(MIN_GROUP_CYCLES)
    ) cadence_controller_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .first_input_channel(first_input_channel),
        .last_input_channel(last_input_channel),
        .output_valid(cadence_output_valid),
        .output_first_input_channel(
            cadence_first_input_channel
        ),
        .output_last_input_channel(
            cadence_last_input_channel
        )
    );
    conv3x3_four_lane_channel_engine channel_engine_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(cadence_output_valid),
        .first_input_channel(
            cadence_first_input_channel
        ),
        .last_input_channel(
            cadence_last_input_channel
        ),
        .input_value_0(input_value_0),
        .input_value_1(input_value_1),
        .input_value_2(input_value_2),
        .input_value_3(input_value_3),
        .input_value_4(input_value_4),
        .input_value_5(input_value_5),
        .input_value_6(input_value_6),
        .input_value_7(input_value_7),
        .input_value_8(input_value_8),
        .weight_lane_0_value_0(weight_lane_0_value_0),
        .weight_lane_0_value_1(weight_lane_0_value_1),
        .weight_lane_0_value_2(weight_lane_0_value_2),
        .weight_lane_0_value_3(weight_lane_0_value_3),
        .weight_lane_0_value_4(weight_lane_0_value_4),
        .weight_lane_0_value_5(weight_lane_0_value_5),
        .weight_lane_0_value_6(weight_lane_0_value_6),
        .weight_lane_0_value_7(weight_lane_0_value_7),
        .weight_lane_0_value_8(weight_lane_0_value_8),
        .weight_lane_1_value_0(weight_lane_1_value_0),
        .weight_lane_1_value_1(weight_lane_1_value_1),
        .weight_lane_1_value_2(weight_lane_1_value_2),
        .weight_lane_1_value_3(weight_lane_1_value_3),
        .weight_lane_1_value_4(weight_lane_1_value_4),
        .weight_lane_1_value_5(weight_lane_1_value_5),
        .weight_lane_1_value_6(weight_lane_1_value_6),
        .weight_lane_1_value_7(weight_lane_1_value_7),
        .weight_lane_1_value_8(weight_lane_1_value_8),
        .weight_lane_2_value_0(weight_lane_2_value_0),
        .weight_lane_2_value_1(weight_lane_2_value_1),
        .weight_lane_2_value_2(weight_lane_2_value_2),
        .weight_lane_2_value_3(weight_lane_2_value_3),
        .weight_lane_2_value_4(weight_lane_2_value_4),
        .weight_lane_2_value_5(weight_lane_2_value_5),
        .weight_lane_2_value_6(weight_lane_2_value_6),
        .weight_lane_2_value_7(weight_lane_2_value_7),
        .weight_lane_2_value_8(weight_lane_2_value_8),
        .weight_lane_3_value_0(weight_lane_3_value_0),
        .weight_lane_3_value_1(weight_lane_3_value_1),
        .weight_lane_3_value_2(weight_lane_3_value_2),
        .weight_lane_3_value_3(weight_lane_3_value_3),
        .weight_lane_3_value_4(weight_lane_3_value_4),
        .weight_lane_3_value_5(weight_lane_3_value_5),
        .weight_lane_3_value_6(weight_lane_3_value_6),
        .weight_lane_3_value_7(weight_lane_3_value_7),
        .weight_lane_3_value_8(weight_lane_3_value_8),
        .bias_value_0(bias_value_0),
        .bias_value_1(bias_value_1),
        .bias_value_2(bias_value_2),
        .bias_value_3(bias_value_3),
        .accumulated_sum_0(accumulated_sum_0),
        .accumulated_sum_1(accumulated_sum_1),
        .accumulated_sum_2(accumulated_sum_2),
        .accumulated_sum_3(accumulated_sum_3),
        .accumulated_sum_valid(accumulated_sum_valid)
    );
    four_lane_requantize_pipeline #(
        .SCALE_MULT(SCALE_MULT),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) requantize_pipeline_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(accumulated_sum_valid),
        .input_ready(requantize_input_ready),
        .accumulated_sum_0(accumulated_sum_0),
        .accumulated_sum_1(accumulated_sum_1),
        .accumulated_sum_2(accumulated_sum_2),
        .accumulated_sum_3(accumulated_sum_3),
        .output_value(output_value),
        .output_lane_index(output_lane_index),
        .output_valid(output_valid),
        .busy(requantize_busy)
    );
endmodule