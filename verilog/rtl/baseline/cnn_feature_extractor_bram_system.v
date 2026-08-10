`timescale 1ns / 1ps

module cnn_feature_extractor_bram_system (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,
    // Image input memory loading port
    input  wire                    image_memory_write_enable,
    input  wire [13:0]             image_memory_write_address,
    input  wire signed [7:0]       image_memory_write_data,
    // Conv1 weight memory loading port
    input  wire                    conv1_weight_memory_write_enable,
    input  wire [8:0]              conv1_weight_memory_write_address,
    input  wire signed [7:0]       conv1_weight_memory_write_data,
    // Conv1 bias memory loading port
    input  wire                    conv1_bias_memory_write_enable,
    input  wire [3:0]              conv1_bias_memory_write_address,
    input  wire signed [31:0]      conv1_bias_memory_write_data,
    // Conv2 weight memory loading port
    input  wire                    conv2_weight_memory_write_enable,
    input  wire [12:0]             conv2_weight_memory_write_address,
    input  wire signed [7:0]       conv2_weight_memory_write_data,
    // Conv2 bias memory loading port
    input  wire                    conv2_bias_memory_write_enable,
    input  wire [4:0]              conv2_bias_memory_write_address,
    input  wire signed [31:0]      conv2_bias_memory_write_data,
    // Final Conv2 pooled output read port
    input  wire [12:0]             conv2_pooled_output_read_address,
    output reg  signed [7:0]       conv2_pooled_output_read_data,
    // Final Conv2 pooled write-stream monitor
    output reg  [12:0]             conv2_pooled_output_write_address_monitor,
    output reg  signed [7:0]       conv2_pooled_output_write_data_monitor,
    output reg                     conv2_pooled_output_write_enable_monitor,
    output reg                     done
);
    localparam CONV1_POOLED_TOTAL_VALUES        = 16384;
    localparam CONV2_WEIGHT_TOTAL_VALUES        = 4608;
    localparam CONV2_BIAS_TOTAL_VALUES          = 32;
    localparam CONV2_POOLED_OUTPUT_TOTAL_VALUES = 8192;
    localparam STATE_IDLE                    = 4'd0;
    localparam STATE_RUN_CONV1               = 4'd1;
    localparam STATE_WAIT_CONV1_DONE         = 4'd2;
    localparam STATE_COPY_CONV1_REQUEST      = 4'd3;
    localparam STATE_COPY_CONV1_WAIT_1       = 4'd4;
    localparam STATE_COPY_CONV1_WAIT_2       = 4'd5;
    localparam STATE_COPY_CONV1_CAPTURE      = 4'd6;
    localparam STATE_COPY_CONV1_NEXT         = 4'd7;
    localparam STATE_RUN_CONV2               = 4'd8;
    localparam STATE_WAIT_CONV2_DONE         = 4'd9;
    localparam STATE_DONE                    = 4'd10;
    reg [3:0] current_state;
    reg conv1_start;
    reg conv2_start;
    wire conv1_done;
    wire conv2_done;
    reg [13:0] conv1_pooled_output_read_address;
    wire signed [7:0] conv1_pooled_output_read_data;
    wire [13:0] conv1_pooled_write_address_monitor_unused;
    wire signed [7:0] conv1_pooled_write_data_monitor_unused;
    wire conv1_pooled_write_enable_monitor_unused;
    reg [13:0] conv1_to_conv2_copy_index;
    wire [13:0] conv2_input_read_address;
    reg signed [7:0] conv2_input_read_data;
    wire [12:0] conv2_weight_read_address;
    reg signed [7:0] conv2_weight_read_data;
    wire [4:0] conv2_bias_read_address;
    reg signed [31:0] conv2_bias_read_data;
    wire [12:0] conv2_pooled_output_write_address;
    wire signed [7:0] conv2_pooled_output_write_data;
    wire conv2_pooled_output_write_enable;
    (* ram_style = "block" *) reg signed [7:0] conv1_to_conv2_memory_array [0:CONV1_POOLED_TOTAL_VALUES-1];
    (* ram_style = "block" *) reg signed [7:0] conv2_weight_memory_array [0:CONV2_WEIGHT_TOTAL_VALUES-1];
    (* ram_style = "block" *) reg signed [31:0] conv2_bias_memory_array [0:CONV2_BIAS_TOTAL_VALUES-1];
    (* ram_style = "block" *) reg signed [7:0] conv2_pooled_output_memory_array [0:CONV2_POOLED_OUTPUT_TOTAL_VALUES-1];
    initial begin
        $display("ACTIVE RTL: cnn_feature_extractor_bram_system V3 COPY CONV1 READBACK TO CONV2");
    end
    conv1_pool_bram_system conv1_pool_bram_system_inst (
        .clk(clk),
        .reset(rst),
        .start(conv1_start),
        .input_memory_write_enable(image_memory_write_enable),
        .input_memory_write_address(image_memory_write_address),
        .input_memory_write_data(image_memory_write_data),
        .weight_memory_write_enable(conv1_weight_memory_write_enable),
        .weight_memory_write_address(conv1_weight_memory_write_address),
        .weight_memory_write_data(conv1_weight_memory_write_data),
        .bias_memory_write_enable(conv1_bias_memory_write_enable),
        .bias_memory_write_address(conv1_bias_memory_write_address),
        .bias_memory_write_data(conv1_bias_memory_write_data),
        .pooled_output_read_address(conv1_pooled_output_read_address),
        .pooled_output_read_data(conv1_pooled_output_read_data),
        .pooled_output_write_address_monitor(conv1_pooled_write_address_monitor_unused),
        .pooled_output_write_data_monitor(conv1_pooled_write_data_monitor_unused),
        .pooled_output_write_enable_monitor(conv1_pooled_write_enable_monitor_unused),
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
            conv2_input_read_data <= 8'sd0;
        end else begin
            conv2_input_read_data <= conv1_to_conv2_memory_array[conv2_input_read_address];
        end
    end
    always @(posedge clk) begin
        if (conv2_weight_memory_write_enable) begin
            conv2_weight_memory_array[conv2_weight_memory_write_address] <= conv2_weight_memory_write_data;
        end
        conv2_weight_read_data <= conv2_weight_memory_array[conv2_weight_read_address];
    end
    always @(posedge clk) begin
        if (conv2_bias_memory_write_enable) begin
            conv2_bias_memory_array[conv2_bias_memory_write_address] <= conv2_bias_memory_write_data;
        end
        conv2_bias_read_data <= conv2_bias_memory_array[conv2_bias_read_address];
    end
    always @(posedge clk) begin
        if (rst) begin
            conv2_pooled_output_read_data <= 8'sd0;
            conv2_pooled_output_write_address_monitor <= 13'd0;
            conv2_pooled_output_write_data_monitor    <= 8'sd0;
            conv2_pooled_output_write_enable_monitor  <= 1'b0;
        end else begin
            if (conv2_pooled_output_write_enable) begin
                conv2_pooled_output_memory_array[conv2_pooled_output_write_address] <= conv2_pooled_output_write_data;
                conv2_pooled_output_write_address_monitor <= conv2_pooled_output_write_address;
                conv2_pooled_output_write_data_monitor    <= conv2_pooled_output_write_data;
                conv2_pooled_output_write_enable_monitor  <= 1'b1;
            end else begin
                conv2_pooled_output_write_enable_monitor <= 1'b0;
            end
            conv2_pooled_output_read_data <= conv2_pooled_output_memory_array[conv2_pooled_output_read_address];
        end
    end
    always @(posedge clk) begin
        if (rst) begin
            current_state <= STATE_IDLE;
            conv1_start <= 1'b0;
            conv2_start <= 1'b0;
            conv1_pooled_output_read_address <= 14'd0;
            conv1_to_conv2_copy_index        <= 14'd0;
            done <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    conv1_start <= 1'b0;
                    conv2_start <= 1'b0;
                    done        <= 1'b0;
                    conv1_pooled_output_read_address <= 14'd0;
                    conv1_to_conv2_copy_index        <= 14'd0;
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
                        conv1_to_conv2_copy_index        <= 14'd0;
                        conv1_pooled_output_read_address <= 14'd0;
                        current_state                    <= STATE_COPY_CONV1_REQUEST;
                    end
                end
                STATE_COPY_CONV1_REQUEST: begin
                    conv1_pooled_output_read_address <= conv1_to_conv2_copy_index;
                    current_state                    <= STATE_COPY_CONV1_WAIT_1;
                end
                STATE_COPY_CONV1_WAIT_1: begin
                    current_state <= STATE_COPY_CONV1_WAIT_2;
                end
                STATE_COPY_CONV1_WAIT_2: begin
                    current_state <= STATE_COPY_CONV1_CAPTURE;
                end
                STATE_COPY_CONV1_CAPTURE: begin
                    conv1_to_conv2_memory_array[conv1_to_conv2_copy_index] <= conv1_pooled_output_read_data;
                    current_state <= STATE_COPY_CONV1_NEXT;
                end
                STATE_COPY_CONV1_NEXT: begin
                    if (conv1_to_conv2_copy_index < CONV1_POOLED_TOTAL_VALUES - 1) begin
                        conv1_to_conv2_copy_index <= conv1_to_conv2_copy_index + 1'b1;
                        current_state             <= STATE_COPY_CONV1_REQUEST;
                    end else begin
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