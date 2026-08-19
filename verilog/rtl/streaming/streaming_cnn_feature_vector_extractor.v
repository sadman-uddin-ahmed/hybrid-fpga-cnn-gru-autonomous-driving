`timescale 1ns / 1ps

module streaming_cnn_feature_vector_extractor #(
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
    output wire [12:0]             output_address,
    output wire                    output_valid,
    output wire                    output_frame_done,
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
    localparam integer FINAL_FEATURE_WIDTH =
        IMAGE_WIDTH / 4;
    localparam integer FINAL_FEATURE_HEIGHT =
        IMAGE_HEIGHT / 4;
    localparam integer FEATURES_PER_FRAME =
        FINAL_FEATURE_WIDTH *
        FINAL_FEATURE_HEIGHT *
        CONV2_OUTPUT_CHANNELS;
    wire signed [7:0] cnn_output_value;
    wire [7:0]        cnn_output_x;
    wire [7:0]        cnn_output_y;
    wire [7:0]        cnn_output_channel_index;
    wire              cnn_output_valid;
    streaming_cnn_feature_extractor #(
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
    ) cnn_feature_extractor_inst (
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
        .output_value(cnn_output_value),
        .output_x(cnn_output_x),
        .output_y(cnn_output_y),
        .output_channel_index(
            cnn_output_channel_index
        ),
        .output_valid(cnn_output_valid),

        .conv1_requantize_busy(
            conv1_requantize_busy
        ),
        .conv2_requantize_busy(
            conv2_requantize_busy
        ),
        .conv2_padding_overflow_error(
            conv2_padding_overflow_error
        ),
        .conv2_padding_sequence_error(
            conv2_padding_sequence_error
        )
    );
    streaming_feature_reorder_buffer #(
        .FEATURE_WIDTH(FINAL_FEATURE_WIDTH),
        .FEATURE_HEIGHT(FINAL_FEATURE_HEIGHT),
        .FEATURE_CHANNELS(CONV2_OUTPUT_CHANNELS),
        .FEATURES_PER_FRAME(FEATURES_PER_FRAME)
    ) feature_reorder_inst (
        .clk(clk),
        .reset(reset),
        .input_value(cnn_output_value),
        .input_x(cnn_output_x),
        .input_y(cnn_output_y),
        .input_channel_index(
            cnn_output_channel_index
        ),
        .input_valid(cnn_output_valid),
        .output_value(output_value),
        .output_address(output_address),
        .output_valid(output_valid),
        .output_frame_done(output_frame_done),
        .capture_busy(reorder_capture_busy),
        .drain_busy(reorder_drain_busy),
        .sequence_error(reorder_sequence_error),
        .metadata_error(reorder_metadata_error),
        .overflow_error(reorder_overflow_error)
    );
    initial begin
        $display(
            "ACTIVE RTL: streaming_cnn_feature_vector_extractor CHANNEL-MAJOR V1"
        );
        if (
            (IMAGE_WIDTH % 4) != 0 ||
            (IMAGE_HEIGHT % 4) != 0
        ) begin
            $display(
                "ERROR: streaming_cnn_feature_vector_extractor requires IMAGE_WIDTH and IMAGE_HEIGHT divisible by four."
            );
        end
        if (FEATURES_PER_FRAME > 8192) begin
            $display(
                "ERROR: streaming_cnn_feature_vector_extractor output address width supports at most 8192 features."
            );
        end
    end
endmodule