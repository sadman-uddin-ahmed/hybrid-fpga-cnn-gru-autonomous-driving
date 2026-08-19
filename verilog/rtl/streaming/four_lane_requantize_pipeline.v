`timescale 1ns / 1ps

module four_lane_requantize_pipeline #(
    parameter integer SCALE_MULT  = 1301962,
    parameter integer SCALE_SHIFT = 30
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    output wire                    input_ready,
    input  wire signed [63:0]      accumulated_sum_0,
    input  wire signed [63:0]      accumulated_sum_1,
    input  wire signed [63:0]      accumulated_sum_2,
    input  wire signed [63:0]      accumulated_sum_3,
    output wire signed [7:0]       output_value,
    output wire [1:0]              output_lane_index,
    output wire                    output_valid,
    output wire                    busy
);
    wire signed [63:0] requantize_input_value;
    wire [1:0]         requantize_lane_index;
    wire               requantize_input_valid;
    initial begin
        $display("ACTIVE RTL: four_lane_requantize_pipeline SHARED-Q1 V1");
    end
    four_lane_requantize_dispatcher dispatcher_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .accumulated_sum_0(accumulated_sum_0),
        .accumulated_sum_1(accumulated_sum_1),
        .accumulated_sum_2(accumulated_sum_2),
        .accumulated_sum_3(accumulated_sum_3),
        .requantize_input_value(requantize_input_value),
        .requantize_lane_index(requantize_lane_index),
        .requantize_input_valid(requantize_input_valid),
        .busy(busy)
    );
    requantize_relu_pipeline #(
        .SCALE_MULT(SCALE_MULT),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) requantize_pipeline_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(requantize_input_valid),
        .input_lane_index(requantize_lane_index),
        .accumulator_input(requantize_input_value),
        .output_value(output_value),
        .output_lane_index(output_lane_index),
        .output_valid(output_valid)
    );
endmodule