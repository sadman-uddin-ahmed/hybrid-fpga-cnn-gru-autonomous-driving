`timescale 1ns / 1ps

module conv2_pool_bram_system (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,
    input  wire                    input_memory_write_enable,
    input  wire [13:0]             input_memory_write_address,
    input  wire signed [7:0]       input_memory_write_data,
    input  wire                    weight_memory_write_enable,
    input  wire [12:0]             weight_memory_write_address,
    input  wire signed [7:0]       weight_memory_write_data,
    input  wire                    bias_memory_write_enable,
    input  wire [4:0]              bias_memory_write_address,
    input  wire signed [31:0]      bias_memory_write_data,
    input  wire [12:0]             pooled_output_read_address,
    output reg  signed [7:0]       pooled_output_read_data,
    output wire                    done
);
    localparam INPUT_TOTAL_VALUES         = 16384;
    localparam WEIGHT_TOTAL_VALUES        = 4608;
    localparam BIAS_TOTAL_VALUES          = 32;
    localparam POOLED_OUTPUT_TOTAL_VALUES = 8192;
    wire [13:0] core_input_read_address;
    reg signed [7:0] core_input_read_data;
    wire [12:0] core_weight_read_address;
    reg signed [7:0] core_weight_read_data;
    wire [4:0] core_bias_read_address;
    reg signed [31:0] core_bias_read_data;
    wire [12:0] core_pooled_output_write_address;
    wire signed [7:0] core_pooled_output_write_data;
    wire core_pooled_output_write_enable;
    (* ram_style = "block" *) reg signed [7:0] input_memory_array [0:INPUT_TOTAL_VALUES-1];
    (* ram_style = "block" *) reg signed [7:0] weight_memory_array [0:WEIGHT_TOTAL_VALUES-1];
    (* ram_style = "block" *) reg signed [31:0] bias_memory_array [0:BIAS_TOTAL_VALUES-1];
    (* ram_style = "block" *) reg signed [7:0] pooled_output_memory_array [0:POOLED_OUTPUT_TOTAL_VALUES-1];
    conv2_pool_bram_core conv2_pool_bram_core_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_read_address(core_input_read_address),
        .input_read_data(core_input_read_data),
        .weight_read_address(core_weight_read_address),
        .weight_read_data(core_weight_read_data),
        .bias_read_address(core_bias_read_address),
        .bias_read_data(core_bias_read_data),
        .pooled_output_write_address(core_pooled_output_write_address),
        .pooled_output_write_data(core_pooled_output_write_data),
        .pooled_output_write_enable(core_pooled_output_write_enable),
        .done(done)
    );
    always @(posedge clk) begin
        if (input_memory_write_enable) begin
            input_memory_array[input_memory_write_address] <= input_memory_write_data;
        end
        core_input_read_data <= input_memory_array[core_input_read_address];
    end
    always @(posedge clk) begin
        if (weight_memory_write_enable) begin
            weight_memory_array[weight_memory_write_address] <= weight_memory_write_data;
        end
        core_weight_read_data <= weight_memory_array[core_weight_read_address];
    end
    always @(posedge clk) begin
        if (bias_memory_write_enable) begin
            bias_memory_array[bias_memory_write_address] <= bias_memory_write_data;
        end
        core_bias_read_data <= bias_memory_array[core_bias_read_address];
    end
    always @(posedge clk) begin
        if (core_pooled_output_write_enable) begin
            pooled_output_memory_array[core_pooled_output_write_address] <= core_pooled_output_write_data;
        end
        pooled_output_read_data <= pooled_output_memory_array[pooled_output_read_address];
    end
endmodule