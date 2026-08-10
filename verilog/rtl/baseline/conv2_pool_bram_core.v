`timescale 1ns / 1ps

module conv2_pool_bram_core #(
    parameter CONV2_RAW_TOTAL_VALUES    = 32768,
    parameter CONV2_POOL_TOTAL_VALUES   = 8192
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,
    output wire [13:0]             input_read_address,
    input  wire signed [7:0]       input_read_data,
    output wire [12:0]             weight_read_address,
    input  wire signed [7:0]       weight_read_data,
    output wire [4:0]              bias_read_address,
    input  wire signed [31:0]      bias_read_data,
    output wire [12:0]             pooled_output_write_address,
    output wire signed [7:0]       pooled_output_write_data,
    output wire                    pooled_output_write_enable,
    output reg                     done
);
    localparam STATE_IDLE              = 3'd0;
    localparam STATE_RUN_CONV2         = 3'd1;
    localparam STATE_WAIT_CONV2_DONE   = 3'd2;
    localparam STATE_RUN_MAXPOOL       = 3'd3;
    localparam STATE_WAIT_MAXPOOL_DONE = 3'd4;
    localparam STATE_DONE              = 3'd5;
    reg [2:0] current_state;
    reg conv2_feature_start;
    reg conv2_maxpool_start;
    wire conv2_feature_done;
    wire conv2_maxpool_done;
    wire [14:0] conv2_raw_write_address;
    wire signed [7:0] conv2_raw_write_data;
    wire conv2_raw_write_enable;
    wire [14:0] conv2_raw_read_address;
    reg signed [7:0] conv2_raw_read_data;
    (* ram_style = "block" *) reg signed [7:0] conv2_raw_memory_array [0:CONV2_RAW_TOTAL_VALUES-1];
    conv2_feature_map_controller_bram conv2_feature_map_controller_inst (
        .clk(clk),
        .rst(rst),
        .start(conv2_feature_start),
        .input_read_address(input_read_address),
        .input_read_data(input_read_data),
        .weight_read_address(weight_read_address),
        .weight_read_data(weight_read_data),
        .bias_read_address(bias_read_address),
        .bias_read_data(bias_read_data),
        .output_write_address(conv2_raw_write_address),
        .output_write_data(conv2_raw_write_data),
        .output_write_enable(conv2_raw_write_enable),
        .done(conv2_feature_done)
    );
    conv2_maxpool_controller_bram conv2_maxpool_controller_inst (
        .clk(clk),
        .rst(rst),
        .start(conv2_maxpool_start),
        .input_read_address(conv2_raw_read_address),
        .input_read_data(conv2_raw_read_data),
        .output_write_address(pooled_output_write_address),
        .output_write_data(pooled_output_write_data),
        .output_write_enable(pooled_output_write_enable),
        .done(conv2_maxpool_done)
    );
    always @(posedge clk) begin
        if (conv2_raw_write_enable) begin
            conv2_raw_memory_array[conv2_raw_write_address] <= conv2_raw_write_data;
        end
        conv2_raw_read_data <= conv2_raw_memory_array[conv2_raw_read_address];
    end
    always @(posedge clk) begin
        if (rst) begin
            current_state       <= STATE_IDLE;
            conv2_feature_start <= 1'b0;
            conv2_maxpool_start <= 1'b0;
            done                <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    conv2_feature_start <= 1'b0;
                    conv2_maxpool_start <= 1'b0;
                    done                <= 1'b0;
                    if (start) begin
                        current_state <= STATE_RUN_CONV2;
                    end
                end
                STATE_RUN_CONV2: begin
                    conv2_feature_start <= 1'b1;
                    conv2_maxpool_start <= 1'b0;
                    current_state <= STATE_WAIT_CONV2_DONE;
                end
                STATE_WAIT_CONV2_DONE: begin
                    conv2_feature_start <= 1'b0;
                    if (conv2_feature_done) begin
                        current_state <= STATE_RUN_MAXPOOL;
                    end
                end
                STATE_RUN_MAXPOOL: begin
                    conv2_feature_start <= 1'b0;
                    conv2_maxpool_start <= 1'b1;
                    current_state <= STATE_WAIT_MAXPOOL_DONE;
                end
                STATE_WAIT_MAXPOOL_DONE: begin
                    conv2_maxpool_start <= 1'b0;
                    if (conv2_maxpool_done) begin
                        current_state <= STATE_DONE;
                    end
                end
                STATE_DONE: begin
                    conv2_feature_start <= 1'b0;
                    conv2_maxpool_start <= 1'b0;
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