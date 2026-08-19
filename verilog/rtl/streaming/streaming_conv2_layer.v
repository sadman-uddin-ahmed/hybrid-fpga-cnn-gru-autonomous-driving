`timescale 1ns / 1ps

module streaming_conv2_layer #(
    parameter integer IMAGE_WIDTH          = 32,
    parameter integer IMAGE_HEIGHT         = 32,
    parameter integer INPUT_CHANNELS       = 16,
    parameter integer OUTPUT_CHANNELS      = 32,
    parameter integer OUTPUT_GROUPS        = OUTPUT_CHANNELS / 4,
    parameter integer MIN_GROUP_CYCLES     = 16,
    parameter integer SCALE_MULT           = 1620513,
    parameter integer SCALE_SHIFT          = 27,
    parameter integer PADDING_FIFO_DEPTH   = IMAGE_WIDTH * IMAGE_HEIGHT * INPUT_CHANNELS,
    parameter integer METADATA_FIFO_DEPTH  = 32
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire signed [7:0]       input_value,
    input  wire [7:0]              input_x,
    input  wire [7:0]              input_y,
    input  wire [7:0]              input_channel_index,
    input  wire                    input_valid,
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
    output wire [7:0]              output_group_index,
    output wire [1:0]              output_lane_index,
    output wire [7:0]              output_channel_index,
    output wire                    output_valid,
    output wire                    requantize_busy,
    output wire                    padding_overflow_error,
    output wire                    padding_sequence_error
);
    wire signed [7:0] padded_stream_value;
    wire [7:0]        padded_stream_x;
    wire [7:0]        padded_stream_y;
    wire [7:0]        padded_stream_channel_index;
    wire              padded_stream_valid;
    wire              padded_stream_ready;
    streaming_same_padding_adapter #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .CHANNELS(INPUT_CHANNELS),
        .FIFO_DEPTH(PADDING_FIFO_DEPTH)
    ) padding_adapter_inst (
        .clk(clk),
        .reset(reset),
        .input_value(input_value),
        .input_x(input_x),
        .input_y(input_y),
        .input_channel_index(input_channel_index),
        .input_valid(input_valid),
        .output_value(padded_stream_value),
        .output_padded_x(padded_stream_x),
        .output_padded_y(padded_stream_y),
        .output_channel_index(padded_stream_channel_index),
        .output_valid(padded_stream_valid),
        .output_ready(padded_stream_ready),
        .overflow_error(padding_overflow_error),
        .sequence_error(padding_sequence_error)
    );
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
        .input_valid(padded_stream_valid),
        .input_ready(padded_stream_ready),
        .input_value(padded_stream_value),
        .weight_memory_write_enable(
            weight_memory_write_enable
        ),
        .weight_memory_write_address(
            weight_memory_write_address
        ),
        .weight_memory_write_data(
            weight_memory_write_data
        ),
        .bias_memory_write_enable(
            bias_memory_write_enable
        ),
        .bias_memory_write_address(
            bias_memory_write_address
        ),
        .bias_memory_write_data(
            bias_memory_write_data
        ),

        .requested_channel_index(
            requested_channel_index
        ),
        .output_value(output_value),
        .output_x(output_x),
        .output_y(output_y),
        .output_group_index(output_group_index),
        .output_lane_index(output_lane_index),
        .output_channel_index(output_channel_index),
        .output_valid(output_valid),
        .requantize_busy(requantize_busy)
    );
    initial begin
        $display(
            "ACTIVE RTL: streaming_conv2_layer PADDED-CANDIDATE-A V1"
        );

        if (INPUT_CHANNELS != 16) begin
            $display(
                "WARNING: streaming_conv2_layer is intended for the 16-channel Conv1-MaxPool stream."
            );
        end
        if (OUTPUT_CHANNELS != 32) begin
            $display(
                "WARNING: streaming_conv2_layer is intended for 32 Conv2 output channels."
            );
        end
        if ((OUTPUT_CHANNELS % 4) != 0) begin
            $display(
                "ERROR: streaming_conv2_layer OUTPUT_CHANNELS must be divisible by four."
            );
        end
    end
endmodule