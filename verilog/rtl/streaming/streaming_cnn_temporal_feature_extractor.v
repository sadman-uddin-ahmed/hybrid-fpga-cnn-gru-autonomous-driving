`timescale 1ns / 1ps

module streaming_cnn_temporal_feature_extractor #(
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
    parameter integer CONV2_SCALE_MULT             = 1516810,
    parameter integer CONV2_SCALE_SHIFT            = 30,
    parameter integer CONV2_PADDING_FIFO_DEPTH     =
        (IMAGE_WIDTH / 2) *
        (IMAGE_HEIGHT / 2) *
        CONV1_OUTPUT_CHANNELS,
    parameter integer CONV2_METADATA_FIFO_DEPTH    = 32
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    temporal_capture_reset,
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
    output wire signed [7:0]       feature_stream_value,
    output wire [12:0]             feature_stream_address,
    output wire                    feature_stream_valid,
    output wire                    feature_stream_frame_done,
    input  wire [14:0]             temporal_feature_read_address,
    output wire signed [7:0]       temporal_feature_read_data,
    output wire [2:0]              temporal_captured_frame_count,
    output wire                    temporal_capture_complete,
    output wire                    reorder_capture_busy,
    output wire                    reorder_drain_busy,
    output wire                    conv1_requantize_busy,
    output wire                    conv2_requantize_busy,
    output wire                    conv2_padding_overflow_error,
    output wire                    conv2_padding_sequence_error,
    output wire                    reorder_sequence_error,
    output wire                    reorder_metadata_error,
    output wire                    reorder_overflow_error
);
    streaming_cnn_feature_vector_extractor #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .CONV1_INPUT_CHANNELS(CONV1_INPUT_CHANNELS),
        .CONV1_OUTPUT_CHANNELS(CONV1_OUTPUT_CHANNELS),
        .CONV1_OUTPUT_GROUPS(CONV1_OUTPUT_GROUPS),
        .CONV1_MIN_GROUP_CYCLES(CONV1_MIN_GROUP_CYCLES),
        .CONV1_SCALE_MULT(CONV1_SCALE_MULT),
        .CONV1_SCALE_SHIFT(CONV1_SCALE_SHIFT),
        .CONV1_METADATA_FIFO_DEPTH(
            CONV1_METADATA_FIFO_DEPTH
        ),
        .CONV2_OUTPUT_CHANNELS(CONV2_OUTPUT_CHANNELS),
        .CONV2_OUTPUT_GROUPS(CONV2_OUTPUT_GROUPS),
        .CONV2_MIN_GROUP_CYCLES(CONV2_MIN_GROUP_CYCLES),
        .CONV2_SCALE_MULT(CONV2_SCALE_MULT),
        .CONV2_SCALE_SHIFT(CONV2_SCALE_SHIFT),
        .CONV2_PADDING_FIFO_DEPTH(
            CONV2_PADDING_FIFO_DEPTH
        ),
        .CONV2_METADATA_FIFO_DEPTH(
            CONV2_METADATA_FIFO_DEPTH
        )
    ) feature_vector_extractor_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .input_value(input_value),
        .conv1_weight_memory_write_enable(
            conv1_weight_memory_write_enable
        ),
        .conv1_weight_memory_write_address(
            conv1_weight_memory_write_address
        ),
        .conv1_weight_memory_write_data(
            conv1_weight_memory_write_data
        ),
        .conv1_bias_memory_write_enable(
            conv1_bias_memory_write_enable
        ),
        .conv1_bias_memory_write_address(
            conv1_bias_memory_write_address
        ),
        .conv1_bias_memory_write_data(
            conv1_bias_memory_write_data
        ),
        .conv2_weight_memory_write_enable(
            conv2_weight_memory_write_enable
        ),
        .conv2_weight_memory_write_address(
            conv2_weight_memory_write_address
        ),
        .conv2_weight_memory_write_data(
            conv2_weight_memory_write_data
        ),
        .conv2_bias_memory_write_enable(
            conv2_bias_memory_write_enable
        ),
        .conv2_bias_memory_write_address(
            conv2_bias_memory_write_address
        ),
        .conv2_bias_memory_write_data(
            conv2_bias_memory_write_data
        ),
        .conv1_requested_channel_index(
            conv1_requested_channel_index
        ),
        .conv2_requested_channel_index(
            conv2_requested_channel_index
        ),
        .output_value(feature_stream_value),
        .output_address(feature_stream_address),
        .output_valid(feature_stream_valid),
        .output_frame_done(feature_stream_frame_done),
        .reorder_capture_busy(reorder_capture_busy),
        .reorder_drain_busy(reorder_drain_busy),
        .conv1_requantize_busy(conv1_requantize_busy),
        .conv2_requantize_busy(conv2_requantize_busy),
        .conv2_padding_overflow_error(
            conv2_padding_overflow_error
        ),
        .conv2_padding_sequence_error(
            conv2_padding_sequence_error
        ),
        .reorder_sequence_error(reorder_sequence_error),
        .reorder_metadata_error(reorder_metadata_error),
        .reorder_overflow_error(reorder_overflow_error)
    );
    temporal_feature_buffer temporal_feature_buffer_inst (
        .clk(clk),
        .rst(reset),
        .capture_reset(
            temporal_capture_reset
        ),
        .feature_write_address(
            feature_stream_address
        ),
        .feature_write_data(
            feature_stream_value
        ),
        .feature_write_enable(
            feature_stream_valid
        ),
        .feature_read_address(
            temporal_feature_read_address
        ),
        .feature_read_data(
            temporal_feature_read_data
        ),
        .captured_frame_count(
            temporal_captured_frame_count
        ),
        .capture_complete(
            temporal_capture_complete
        )
    );
    initial begin
        $display(
            "ACTIVE RTL: streaming_cnn_temporal_feature_extractor FOUR-FRAME V1"
        );
    end
endmodule