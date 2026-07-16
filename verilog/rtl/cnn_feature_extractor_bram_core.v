`timescale 1ns / 1ps

module cnn_feature_extractor_bram_core (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,
    // Original input image memory: 3 x 64 x 64 = 12288 values
    output wire [13:0]             image_read_address,
    input  wire signed [7:0]       image_read_data,
    // Conv1 weights: 16 x 3 x 3 x 3 = 432 values
    output wire [8:0]              conv1_weight_read_address,
    input  wire signed [7:0]       conv1_weight_read_data,
    // Conv1 bias: 16 values
    output wire [3:0]              conv1_bias_read_address,
    input  wire signed [31:0]      conv1_bias_read_data,
    // Conv2 weights: 32 x 16 x 3 x 3 = 4608 values
    output wire [12:0]             conv2_weight_read_address,
    input  wire signed [7:0]       conv2_weight_read_data,
    // Conv2 bias: 32 values
    output wire [4:0]              conv2_bias_read_address,
    input  wire signed [31:0]      conv2_bias_read_data,
    // Final Conv2 pooled output: 32 x 16 x 16 = 8192 values
    output wire [12:0]             conv2_pooled_output_write_address,
    output wire signed [7:0]       conv2_pooled_output_write_data,
    output wire                    conv2_pooled_output_write_enable,
    output reg                     done
);
    localparam CONV1_POOLED_TOTAL_VALUES = 16384;
    localparam STATE_IDLE              = 3'd0;
    localparam STATE_RUN_CONV1         = 3'd1;
    localparam STATE_WAIT_CONV1_DONE   = 3'd2;
    localparam STATE_RUN_CONV2         = 3'd3;
    localparam STATE_WAIT_CONV2_DONE   = 3'd4;
    localparam STATE_DONE              = 3'd5;
    reg [2:0] current_state;
    reg conv1_start;
    reg conv2_start;
    wire conv1_done;
    wire conv2_done;
    wire [13:0] conv1_pooled_write_address;
    wire signed [7:0] conv1_pooled_write_data;
    wire conv1_pooled_write_enable;
    reg [13:0] conv1_pooled_write_address_delayed;
    reg signed [7:0] conv1_pooled_write_data_delayed;
    reg conv1_pooled_write_enable_delayed;
    wire [13:0] conv2_input_read_address;
    reg signed [7:0] conv2_input_read_data;
    (* ram_style = "block" *) reg signed [7:0] conv1_pooled_memory_array [0:CONV1_POOLED_TOTAL_VALUES-1];
    conv1_pool_bram_core conv1_pool_bram_core_inst (
        .clk(clk),
        .reset(rst),
        .start(conv1_start),
        .input_read_address(image_read_address),
        .input_read_data(image_read_data),
        .weight_read_address(conv1_weight_read_address),
        .weight_read_data(conv1_weight_read_data),
        .bias_read_address(conv1_bias_read_address),
        .bias_read_data(conv1_bias_read_data),
        .pooled_output_write_address(conv1_pooled_write_address),
        .pooled_output_write_data(conv1_pooled_write_data),
        .pooled_output_write_enable(conv1_pooled_write_enable),
        .done(conv1_done)
    );
    conv2_pool_bram_core conv2_pool_bram_core_inst (
        .clk(clk),
        .rst(rst),
        .start(conv2_start),
        .input_read_address(conv2_input_read_address),
        .input_read_data(conv2_input_read_data),
        .weight_read_address(conv2_weight_read_address),
        .weight_read_data(conv2_weight_read_data),
        .bias_read_address(conv2_bias_read_address),
        .bias_read_data(conv2_bias_read_data),
        .pooled_output_write_address(conv2_pooled_output_write_address),
        .pooled_output_write_data(conv2_pooled_output_write_data),
        .pooled_output_write_enable(conv2_pooled_output_write_enable),
        .done(conv2_done)
    );
    always @(posedge clk) begin
        if (rst) begin
            conv1_pooled_write_address_delayed <= 14'd0;
            conv1_pooled_write_data_delayed    <= 8'sd0;
            conv1_pooled_write_enable_delayed  <= 1'b0;
            conv2_input_read_data              <= 8'sd0;
        end else begin
            conv1_pooled_write_address_delayed <= conv1_pooled_write_address;
            conv1_pooled_write_data_delayed    <= conv1_pooled_write_data;
            conv1_pooled_write_enable_delayed  <= conv1_pooled_write_enable;
            if (conv1_pooled_write_enable_delayed) begin
                conv1_pooled_memory_array[conv1_pooled_write_address_delayed] <= conv1_pooled_write_data_delayed;
            end
            conv2_input_read_data <= conv1_pooled_memory_array[conv2_input_read_address];
        end
    end
    always @(posedge clk) begin
        if (rst) begin
            current_state <= STATE_IDLE;
            conv1_start   <= 1'b0;
            conv2_start   <= 1'b0;
            done          <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    conv1_start <= 1'b0;
                    conv2_start <= 1'b0;
                    done        <= 1'b0;
                    if (start) begin
                        current_state <= STATE_RUN_CONV1;
                    end
                end
                STATE_RUN_CONV1: begin
                    conv1_start <= 1'b1;
                    conv2_start <= 1'b0;
                    current_state <= STATE_WAIT_CONV1_DONE;
                end
                STATE_WAIT_CONV1_DONE: begin
                    conv1_start <= 1'b0;
                    if (conv1_done) begin
                        current_state <= STATE_RUN_CONV2;
                    end
                end
                STATE_RUN_CONV2: begin
                    conv1_start <= 1'b0;
                    conv2_start <= 1'b1;
                    current_state <= STATE_WAIT_CONV2_DONE;
                end
                STATE_WAIT_CONV2_DONE: begin
                    conv2_start <= 1'b0;
                    if (conv2_done) begin
                        current_state <= STATE_DONE;
                    end
                end
                STATE_DONE: begin
                    conv1_start <= 1'b0;
                    conv2_start <= 1'b0;
                    done        <= 1'b1;
                    current_state <= STATE_IDLE;
                end
                default: begin
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule