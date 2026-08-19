`timescale 1ns / 1ps

module streaming_convolution_maxpool_layer #(
    parameter integer IMAGE_WIDTH          = 64,
    parameter integer IMAGE_HEIGHT         = 64,
    parameter integer INPUT_CHANNELS       = 3,
    parameter integer OUTPUT_CHANNELS      = 16,
    parameter integer OUTPUT_GROUPS        = OUTPUT_CHANNELS / 4,
    parameter integer MIN_GROUP_CYCLES     = 4,
    parameter integer SCALE_MULT           = 1301962,
    parameter integer SCALE_SHIFT          = 30,
    parameter integer METADATA_FIFO_DEPTH  = 32
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    output wire                    input_ready,
    input  wire signed [7:0]       input_value,
    input  wire                    weight_memory_write_enable,
    input  wire [12:0]             weight_memory_write_address,
    input  wire signed [7:0]       weight_memory_write_data,
    input  wire                    bias_memory_write_enable,
    input  wire [5:0]              bias_memory_write_address,
    input  wire signed [31:0]      bias_memory_write_data,
    output wire [7:0]              requested_channel_index,
    output wire signed [7:0]       output_value,
    output wire [7:0]              output_x,
    output wire [7:0]              output_y,
    output wire [7:0]              output_channel_index,
    output wire                    output_valid,
    output wire                    requantize_busy
);
    wire signed [7:0] convolution_output_value;
    wire [7:0]        convolution_output_x;
    wire [7:0]        convolution_output_y;
    wire [7:0]        convolution_output_group_index;
    wire [1:0]        convolution_output_lane_index;
    wire [7:0]        convolution_output_channel_index;
    wire              convolution_output_valid;
    streaming_convolution_layer #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .OUTPUT_CHANNELS(OUTPUT_CHANNELS),
        .OUTPUT_GROUPS(OUTPUT_GROUPS),
        .MIN_GROUP_CYCLES(MIN_GROUP_CYCLES),
        .SCALE_MULT(SCALE_MULT),
        .SCALE_SHIFT(SCALE_SHIFT),
        .METADATA_FIFO_DEPTH(METADATA_FIFO_DEPTH)
    ) convolution_layer_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .input_value(input_value),
        .weight_memory_write_enable(weight_memory_write_enable),
        .weight_memory_write_address(weight_memory_write_address),
        .weight_memory_write_data(weight_memory_write_data),
        .bias_memory_write_enable(bias_memory_write_enable),
        .bias_memory_write_address(bias_memory_write_address),
        .bias_memory_write_data(bias_memory_write_data),
        .requested_channel_index(requested_channel_index),
        .output_value(convolution_output_value),
        .output_x(convolution_output_x),
        .output_y(convolution_output_y),
        .output_group_index(convolution_output_group_index),
        .output_lane_index(convolution_output_lane_index),
        .output_channel_index(convolution_output_channel_index),
        .output_valid(convolution_output_valid),
        .requantize_busy(requantize_busy)
    );
    streaming_maxpool_2x2 #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .CHANNELS(OUTPUT_CHANNELS)
    ) maxpool_inst (
        .clk(clk),
        .reset(reset),
        .input_value(convolution_output_value),
        .input_x(convolution_output_x),
        .input_y(convolution_output_y),
        .input_channel_index(convolution_output_channel_index),
        .input_valid(convolution_output_valid),
        .output_value(output_value),
        .output_x(output_x),
        .output_y(output_y),
        .output_channel_index(output_channel_index),
        .output_valid(output_valid)
    );
    initial begin
        $display(
            "ACTIVE RTL: streaming_convolution_maxpool_layer CANDIDATE-A V1"
        );
        if ((OUTPUT_CHANNELS % 4) != 0) begin
            $display(
                "ERROR: streaming_convolution_maxpool_layer requires OUTPUT_CHANNELS divisible by four."
            );
        end
        if (
            (IMAGE_WIDTH % 2) != 0 ||
            (IMAGE_HEIGHT % 2) != 0
        ) begin
            $display(
                "ERROR: streaming_convolution_maxpool_layer requires even image dimensions."
            );
        end
    end
endmodule