`timescale 1ns / 1ps

module conv1_pool_bram_core #(
    parameter SCALE_MULT  = 1301962,
    parameter SCALE_SHIFT = 30
)(
    input  wire clk,
    input  wire reset,
    input  wire start,
    output reg  done,
    output wire input_read_enable,
    output wire [13:0] input_read_address,
    input  wire signed [7:0] input_read_data,
    output wire weight_read_enable,
    output wire [8:0] weight_read_address,
    input  wire signed [7:0] weight_read_data,
    output wire bias_read_enable,
    output wire [3:0] bias_read_address,
    input  wire signed [31:0] bias_read_data,
    output wire pooled_output_write_enable,
    output wire [13:0] pooled_output_write_address,
    output wire signed [7:0] pooled_output_write_data
);
    localparam STATE_IDLE              = 3'd0;
    localparam STATE_RUN_CONV1         = 3'd1;
    localparam STATE_WAIT_CONV1_DONE   = 3'd2;
    localparam STATE_RUN_MAXPOOL       = 3'd3;
    localparam STATE_WAIT_MAXPOOL_DONE = 3'd4;
    localparam STATE_DONE              = 3'd5;
    reg [2:0] current_state;
    reg conv1_feature_start;
    reg maxpool_start;
    wire conv1_feature_done;
    wire maxpool_done;
    wire conv1_raw_write_enable;
    wire [15:0] conv1_raw_write_address;
    wire signed [7:0] conv1_raw_write_data;
    wire maxpool_input_read_enable;
    wire [15:0] maxpool_input_read_address;
    wire signed [7:0] maxpool_input_read_data;
    conv1_feature_map_controller_bram #(
        .SCALE_MULT(SCALE_MULT),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) conv1_feature_map_controller_bram_inst (
        .clk(clk),
        .reset(reset),
        .start(conv1_feature_start),
        .done(conv1_feature_done),
        .input_read_enable(input_read_enable),
        .input_read_address(input_read_address),
        .input_read_data(input_read_data),
        .weight_read_enable(weight_read_enable),
        .weight_read_address(weight_read_address),
        .weight_read_data(weight_read_data),
        .bias_read_enable(bias_read_enable),
        .bias_read_address(bias_read_address),
        .bias_read_data(bias_read_data),
        .output_write_enable(conv1_raw_write_enable),
        .output_write_address(conv1_raw_write_address),
        .output_write_data(conv1_raw_write_data)
    );
    bram_sdp_int8 #(
        .ADDR_WIDTH(16),
        .DATA_WIDTH(8)
    ) conv1_raw_output_bram_inst (
        .clk(clk),
        .write_enable(conv1_raw_write_enable),
        .write_address(conv1_raw_write_address),
        .write_data(conv1_raw_write_data),
        .read_enable(maxpool_input_read_enable),
        .read_address(maxpool_input_read_address),
        .read_data(maxpool_input_read_data)
    );
    maxpool_controller_bram #(
        .INPUT_WIDTH(64),
        .INPUT_HEIGHT(64),
        .OUTPUT_WIDTH(32),
        .OUTPUT_HEIGHT(32),
        .CHANNELS(16)
    ) maxpool_controller_bram_inst (
        .clk(clk),
        .reset(reset),
        .start(maxpool_start),
        .done(maxpool_done),
        .input_read_enable(maxpool_input_read_enable),
        .input_read_address(maxpool_input_read_address),
        .input_read_data(maxpool_input_read_data),
        .output_write_enable(pooled_output_write_enable),
        .output_write_address(pooled_output_write_address),
        .output_write_data(pooled_output_write_data)
    );
    always @(posedge clk) begin
        if (reset) begin
            current_state       <= STATE_IDLE;
            conv1_feature_start <= 1'b0;
            maxpool_start       <= 1'b0;
            done                <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    conv1_feature_start <= 1'b0;
                    maxpool_start       <= 1'b0;
                    done                <= 1'b0;
                    if (start) begin
                        current_state <= STATE_RUN_CONV1;
                    end
                end
                STATE_RUN_CONV1: begin
                    conv1_feature_start <= 1'b1;
                    maxpool_start       <= 1'b0;
                    done                <= 1'b0;
                    current_state <= STATE_WAIT_CONV1_DONE;
                end
                STATE_WAIT_CONV1_DONE: begin
                    conv1_feature_start <= 1'b0;
                    maxpool_start       <= 1'b0;
                    if (conv1_feature_done) begin
                        current_state <= STATE_RUN_MAXPOOL;
                    end
                end
                STATE_RUN_MAXPOOL: begin
                    conv1_feature_start <= 1'b0;
                    maxpool_start       <= 1'b1;
                    current_state <= STATE_WAIT_MAXPOOL_DONE;
                end
                STATE_WAIT_MAXPOOL_DONE: begin
                    maxpool_start <= 1'b0;
                    if (maxpool_done) begin
                        current_state <= STATE_DONE;
                    end
                end
                STATE_DONE: begin
                    conv1_feature_start <= 1'b0;
                    maxpool_start       <= 1'b0;
                    done                <= 1'b1;
                    current_state <= STATE_IDLE;
                end
                default: begin
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule