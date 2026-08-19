`timescale 1ns / 1ps

module requantize_relu_pipeline #(
    parameter integer SCALE_MULT  = 1301962,
    parameter integer SCALE_SHIFT = 30
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    input  wire [1:0]              input_lane_index,
    input  wire signed [63:0]      accumulator_input,
    output reg  signed [7:0]       output_value,
    output reg  [1:0]              output_lane_index,
    output reg                     output_valid
);
    localparam signed [63:0] SCALE_MULT_64 = SCALE_MULT;
    reg signed [63:0] quantized_product;
    reg signed [63:0] quantized_rounded_product;
    reg signed [63:0] quantized_shifted_value;
    reg valid_stage_0;
    reg valid_stage_1;
    reg valid_stage_2;
    reg [1:0] lane_index_stage_0;
    reg [1:0] lane_index_stage_1;
    reg [1:0] lane_index_stage_2;
    initial begin
        $display("ACTIVE RTL: requantize_relu_pipeline II1 V1");
    end
    always @(posedge clk) begin
        if (reset) begin
            quantized_product         <= 64'sd0;
            quantized_rounded_product <= 64'sd0;
            quantized_shifted_value   <= 64'sd0;
            valid_stage_0 <= 1'b0;
            valid_stage_1 <= 1'b0;
            valid_stage_2 <= 1'b0;
            lane_index_stage_0 <= 2'd0;
            lane_index_stage_1 <= 2'd0;
            lane_index_stage_2 <= 2'd0;
            output_value      <= 8'sd0;
            output_lane_index <= 2'd0;
            output_valid      <= 1'b0;
        end else begin
            // Multiply by the fixed requantisation scale.
            quantized_product <=
                accumulator_input * SCALE_MULT_64;
            // Preserve the Stage-06 positive-only rounding rule.
            if (quantized_product > 64'sd0) begin
                quantized_rounded_product <=
                    quantized_product +
                    (64'sd1 <<< (SCALE_SHIFT - 1));
            end else begin
                quantized_rounded_product <=
                    quantized_product;
            end
            // Preserve the Stage-06 signed arithmetic shift.
            quantized_shifted_value <=
                quantized_rounded_product >>> SCALE_SHIFT;
            // ReLU and signed int8 positive saturation.
            if (quantized_shifted_value <= 64'sd0) begin
                output_value <= 8'sd0;
            end else if (quantized_shifted_value > 64'sd127) begin
                output_value <= 8'sd127;
            end else begin
                output_value <=
                    quantized_shifted_value[7:0];
            end
            valid_stage_0 <= input_valid;
            valid_stage_1 <= valid_stage_0;
            valid_stage_2 <= valid_stage_1;
            output_valid  <= valid_stage_2;
            lane_index_stage_0 <= input_lane_index;
            lane_index_stage_1 <= lane_index_stage_0;
            lane_index_stage_2 <= lane_index_stage_1;
            output_lane_index  <= lane_index_stage_2;
        end
    end
endmodule