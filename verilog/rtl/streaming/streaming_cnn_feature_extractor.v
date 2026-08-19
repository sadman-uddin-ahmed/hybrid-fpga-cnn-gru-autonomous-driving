`timescale 1ns / 1ps

module streaming_cnn_feature_extractor #(
    parameter integer IMAGE_WIDTH                  = 64,
    parameter integer IMAGE_HEIGHT                 = 64,
    parameter integer CONV1_INPUT_CHANNELS         = 3,
    parameter integer CONV1_OUTPUT_CHANNELS        = 16,
    parameter integer CONV1_OUTPUT_GROUPS          = CONV1_OUTPUT_CHANNELS / 4,
    parameter integer CONV1_MIN_GROUP_CYCLES       = 4,
    parameter integer CONV1_SCALE_MULT             = 1301962,
    parameter integer CONV1_SCALE_SHIFT            = 30,
    parameter integer CONV1_METADATA_FIFO_DEPTH    = 32,
    parameter integer CONV2_OUTPUT_CHANNELS        = 32,
    parameter integer CONV2_OUTPUT_GROUPS          = CONV2_OUTPUT_CHANNELS / 4,
    parameter integer CONV2_MIN_GROUP_CYCLES       = 16,
    parameter integer CONV2_SCALE_MULT             = 1620513,
    parameter integer CONV2_SCALE_SHIFT            = 27,
    parameter integer CONV2_PADDING_FIFO_DEPTH     =
        (IMAGE_WIDTH / 2) * (IMAGE_HEIGHT / 2) * CONV1_OUTPUT_CHANNELS,
    parameter integer CONV2_METADATA_FIFO_DEPTH    = 32
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    output wire                    input_ready,
    input  wire signed [7:0]       input_value,
    input  wire                    conv1_weight_memory_write_enable,
    input  wire [12:0]             conv1_weight_memory_write_address,
    input  wire signed [7:0]       conv1_weight_memory_write_data,
    input  wire                    conv1_bias_memory_write_enable,
    input  wire [5:0]              conv1_bias_memory_write_address,
    input  wire signed [31:0]      conv1_bias_memory_write_data,
    input  wire                    conv2_weight_memory_write_enable,
    input  wire [12:0]             conv2_weight_memory_write_address,
    input  wire signed [7:0]       conv2_weight_memory_write_data,
    input  wire                    conv2_bias_memory_write_enable,
    input  wire [5:0]              conv2_bias_memory_write_address,
    input  wire signed [31:0]      conv2_bias_memory_write_data,
    output wire [7:0]              conv1_requested_channel_index,
    output wire [7:0]              conv2_requested_channel_index,
    output wire signed [7:0]       output_value,
    output wire [7:0]              output_x,
    output wire [7:0]              output_y,
    output wire [7:0]              output_channel_index,
    output wire                    output_valid,
    output wire                    conv1_requantize_busy,
    output wire                    conv2_requantize_busy,
    output wire                    conv2_padding_overflow_error,
    output wire                    conv2_padding_sequence_error
);
    localparam integer CONV1_POOLED_WIDTH  = IMAGE_WIDTH / 2;
    localparam integer CONV1_POOLED_HEIGHT = IMAGE_HEIGHT / 2;
    wire signed [7:0] conv1_pooled_value;
    wire [7:0]        conv1_pooled_x;
    wire [7:0]        conv1_pooled_y;
    wire [7:0]        conv1_pooled_channel_index;
    wire              conv1_pooled_valid;
    streaming_convolution_maxpool_layer #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .INPUT_CHANNELS(CONV1_INPUT_CHANNELS),
        .OUTPUT_CHANNELS(CONV1_OUTPUT_CHANNELS),
        .OUTPUT_GROUPS(CONV1_OUTPUT_GROUPS),
        .MIN_GROUP_CYCLES(CONV1_MIN_GROUP_CYCLES),
        .SCALE_MULT(CONV1_SCALE_MULT),
        .SCALE_SHIFT(CONV1_SCALE_SHIFT),
        .METADATA_FIFO_DEPTH(CONV1_METADATA_FIFO_DEPTH)
    ) conv1_maxpool_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .input_value(input_value),
        .weight_memory_write_enable(
            conv1_weight_memory_write_enable
        ),
        .weight_memory_write_address(
            conv1_weight_memory_write_address
        ),
        .weight_memory_write_data(
            conv1_weight_memory_write_data
        ),
        .bias_memory_write_enable(
            conv1_bias_memory_write_enable
        ),
        .bias_memory_write_address(
            conv1_bias_memory_write_address
        ),
        .bias_memory_write_data(
            conv1_bias_memory_write_data
        ),
        .requested_channel_index(
            conv1_requested_channel_index
        ),
        .output_value(conv1_pooled_value),
        .output_x(conv1_pooled_x),
        .output_y(conv1_pooled_y),
        .output_channel_index(
            conv1_pooled_channel_index
        ),
        .output_valid(conv1_pooled_valid),

        .requantize_busy(conv1_requantize_busy)
    );
    streaming_conv2_maxpool_layer #(
        .IMAGE_WIDTH(CONV1_POOLED_WIDTH),
        .IMAGE_HEIGHT(CONV1_POOLED_HEIGHT),
        .INPUT_CHANNELS(CONV1_OUTPUT_CHANNELS),
        .OUTPUT_CHANNELS(CONV2_OUTPUT_CHANNELS),
        .OUTPUT_GROUPS(CONV2_OUTPUT_GROUPS),
        .MIN_GROUP_CYCLES(CONV2_MIN_GROUP_CYCLES),
        .SCALE_MULT(CONV2_SCALE_MULT),
        .SCALE_SHIFT(CONV2_SCALE_SHIFT),
        .PADDING_FIFO_DEPTH(CONV2_PADDING_FIFO_DEPTH),
        .METADATA_FIFO_DEPTH(CONV2_METADATA_FIFO_DEPTH)
    ) conv2_maxpool_inst (
        .clk(clk),
        .reset(reset),
        .input_value(conv1_pooled_value),
        .input_x(conv1_pooled_x),
        .input_y(conv1_pooled_y),
        .input_channel_index(
            conv1_pooled_channel_index
        ),
        .input_valid(conv1_pooled_valid),
        .weight_memory_write_enable(
            conv2_weight_memory_write_enable
        ),
        .weight_memory_write_address(
            conv2_weight_memory_write_address
        ),
        .weight_memory_write_data(
            conv2_weight_memory_write_data
        ),
        .bias_memory_write_enable(
            conv2_bias_memory_write_enable
        ),
        .bias_memory_write_address(
            conv2_bias_memory_write_address
        ),
        .bias_memory_write_data(
            conv2_bias_memory_write_data
        ),
        .requested_channel_index(
            conv2_requested_channel_index
        ),
        .output_value(output_value),
        .output_x(output_x),
        .output_y(output_y),
        .output_channel_index(output_channel_index),
        .output_valid(output_valid),
        .requantize_busy(conv2_requantize_busy),
        .padding_overflow_error(
            conv2_padding_overflow_error
        ),
        .padding_sequence_error(
            conv2_padding_sequence_error
        )
    );
    initial begin
        $display(
            "ACTIVE RTL: streaming_cnn_feature_extractor FULL-CNN CANDIDATE-A V1"
        );
        if (
            (IMAGE_WIDTH % 4) != 0 ||
            (IMAGE_HEIGHT % 4) != 0
        ) begin
            $display(
                "ERROR: streaming_cnn_feature_extractor requires IMAGE_WIDTH and IMAGE_HEIGHT divisible by four."
            );
        end
        if (CONV1_INPUT_CHANNELS != 3) begin
            $display(
                "WARNING: streaming_cnn_feature_extractor is intended for three Conv1 input channels."
            );
        end
        if (CONV1_OUTPUT_CHANNELS != 16) begin
            $display(
                "WARNING: streaming_cnn_feature_extractor is intended for 16 Conv1 output channels."
            );
        end
        if (CONV2_OUTPUT_CHANNELS != 32) begin
            $display(
                "WARNING: streaming_cnn_feature_extractor is intended for 32 Conv2 output channels."
            );
        end
        if (
            (CONV1_OUTPUT_CHANNELS % 4) != 0 ||
            (CONV2_OUTPUT_CHANNELS % 4) != 0
        ) begin
            $display(
                "ERROR: streaming_cnn_feature_extractor output-channel counts must be divisible by four."
            );
        end
    end
endmodule