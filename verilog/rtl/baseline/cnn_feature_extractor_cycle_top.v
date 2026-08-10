`timescale 1ns / 1ps

module cnn_feature_extractor_cycle_top (
    input  wire clk,
    input  wire rst,
    input  wire start,
    output reg  done
);
    localparam STATE_IDLE                    = 4'd0;
    localparam STATE_START_CONV1             = 4'd1;
    localparam STATE_WAIT_CONV1              = 4'd2;
    localparam STATE_COPY_CONV1_TO_POOL      = 4'd3;
    localparam STATE_START_POOL1             = 4'd4;
    localparam STATE_WAIT_POOL1              = 4'd5;
    localparam STATE_COPY_POOL1_TO_CONV2     = 4'd6;
    localparam STATE_START_CONV2             = 4'd7;
    localparam STATE_WAIT_CONV2              = 4'd8;
    localparam STATE_COPY_CONV2_TO_POOL      = 4'd9;
    localparam STATE_START_POOL2             = 4'd10;
    localparam STATE_WAIT_POOL2              = 4'd11;
    localparam STATE_DONE                    = 4'd12;
    reg [3:0] current_state;
    reg start_conv1_feature_map;
    reg start_conv1_pool;
    reg start_conv2_feature_map;
    reg start_conv2_pool;
    wire done_conv1_feature_map;
    wire done_conv1_pool;
    wire done_conv2_feature_map;
    wire done_conv2_pool;
    integer memory_copy_index;
    conv1_feature_map_controller conv1_feature_map_controller_inst (
        .clk(clk),
        .rst(rst),
        .start(start_conv1_feature_map),
        .done(done_conv1_feature_map)
    );
    maxpool_controller #(
        .INPUT_CHANNELS(16),
        .INPUT_HEIGHT(64),
        .INPUT_WIDTH(64),
        .OUTPUT_HEIGHT(32),
        .OUTPUT_WIDTH(32),
        .INPUT_SIZE(16 * 64 * 64),
        .OUTPUT_SIZE(16 * 32 * 32)
    ) conv1_pool_controller_inst (
        .clk(clk),
        .rst(rst),
        .start(start_conv1_pool),
        .done(done_conv1_pool)
    );
    conv2_feature_map_controller conv2_feature_map_controller_inst (
        .clk(clk),
        .rst(rst),
        .start(start_conv2_feature_map),
        .done(done_conv2_feature_map)
    );
    maxpool_controller #(
        .INPUT_CHANNELS(32),
        .INPUT_HEIGHT(32),
        .INPUT_WIDTH(32),
        .OUTPUT_HEIGHT(16),
        .OUTPUT_WIDTH(16),
        .INPUT_SIZE(32 * 32 * 32),
        .OUTPUT_SIZE(32 * 16 * 16)
    ) conv2_pool_controller_inst (
        .clk(clk),
        .rst(rst),
        .start(start_conv2_pool),
        .done(done_conv2_pool)
    );
    initial begin
        done = 1'b0;
        current_state = STATE_IDLE;

        start_conv1_feature_map = 1'b0;
        start_conv1_pool = 1'b0;
        start_conv2_feature_map = 1'b0;
        start_conv2_pool = 1'b0;

        memory_copy_index = 0;
    end
    always @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
            current_state <= STATE_IDLE;
            start_conv1_feature_map <= 1'b0;
            start_conv1_pool <= 1'b0;
            start_conv2_feature_map <= 1'b0;
            start_conv2_pool <= 1'b0;
            memory_copy_index <= 0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    start_conv1_feature_map <= 1'b0;
                    start_conv1_pool <= 1'b0;
                    start_conv2_feature_map <= 1'b0;
                    start_conv2_pool <= 1'b0;
                    if (start) begin
                        current_state <= STATE_START_CONV1;
                    end
                end
                STATE_START_CONV1: begin
                    start_conv1_feature_map <= 1'b1;
                    current_state <= STATE_WAIT_CONV1;
                end
                STATE_WAIT_CONV1: begin
                    start_conv1_feature_map <= 1'b0;
                    if (done_conv1_feature_map) begin
                        memory_copy_index <= 0;
                        current_state <= STATE_COPY_CONV1_TO_POOL;
                    end
                end
                STATE_COPY_CONV1_TO_POOL: begin
                    conv1_pool_controller_inst.input_memory[memory_copy_index] <=
                        conv1_feature_map_controller_inst.conv1_output_memory[memory_copy_index];

                    if (memory_copy_index == (16 * 64 * 64) - 1) begin
                        memory_copy_index <= 0;
                        current_state <= STATE_START_POOL1;
                    end else begin
                        memory_copy_index <= memory_copy_index + 1;
                    end
                end
                STATE_START_POOL1: begin
                    start_conv1_pool <= 1'b1;
                    current_state <= STATE_WAIT_POOL1;
                end
                STATE_WAIT_POOL1: begin
                    start_conv1_pool <= 1'b0;
                    if (done_conv1_pool) begin
                        memory_copy_index <= 0;
                        current_state <= STATE_COPY_POOL1_TO_CONV2;
                    end
                end
                STATE_COPY_POOL1_TO_CONV2: begin
                    conv2_feature_map_controller_inst.input_memory[memory_copy_index] <=
                        conv1_pool_controller_inst.output_memory[memory_copy_index];

                    if (memory_copy_index == (16 * 32 * 32) - 1) begin
                        memory_copy_index <= 0;
                        current_state <= STATE_START_CONV2;
                    end else begin
                        memory_copy_index <= memory_copy_index + 1;
                    end
                end
                STATE_START_CONV2: begin
                    start_conv2_feature_map <= 1'b1;
                    current_state <= STATE_WAIT_CONV2;
                end
                STATE_WAIT_CONV2: begin
                    start_conv2_feature_map <= 1'b0;

                    if (done_conv2_feature_map) begin
                        memory_copy_index <= 0;
                        current_state <= STATE_COPY_CONV2_TO_POOL;
                    end
                end
                STATE_COPY_CONV2_TO_POOL: begin
                    conv2_pool_controller_inst.input_memory[memory_copy_index] <=
                        conv2_feature_map_controller_inst.conv2_output_memory[memory_copy_index];
                    if (memory_copy_index == (32 * 32 * 32) - 1) begin
                        memory_copy_index <= 0;
                        current_state <= STATE_START_POOL2;
                    end else begin
                        memory_copy_index <= memory_copy_index + 1;
                    end
                end
                STATE_START_POOL2: begin
                    start_conv2_pool <= 1'b1;
                    current_state <= STATE_WAIT_POOL2;
                end
                STATE_WAIT_POOL2: begin
                    start_conv2_pool <= 1'b0;

                    if (done_conv2_pool) begin
                        current_state <= STATE_DONE;
                    end
                end
                STATE_DONE: begin
                    done <= 1'b1;
                    current_state <= STATE_DONE;
                end
                default: begin
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule