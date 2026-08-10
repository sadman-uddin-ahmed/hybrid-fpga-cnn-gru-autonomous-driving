`timescale 1ns / 1ps

module relu_quantize_int8 #(
    parameter integer SCALE_MULT  = 1301962,
    parameter integer SCALE_SHIFT = 30
)(
    input  wire signed [31:0] accumulator_in,
    output reg  signed [7:0]  quantized_out
);
    reg signed [31:0] relu_value;
    reg signed [63:0] scaled_product;
    reg signed [63:0] rounded_value;
    reg signed [31:0] shifted_value;
    always @(*) begin
        // ReLU
        if (accumulator_in < 0) begin
            relu_value = 32'sd0;
        end else begin
            relu_value = accumulator_in;
        end
        // Fixed-point scaling:
        // scaled = round(relu_value * SCALE_MULT / 2^SCALE_SHIFT)
        scaled_product = relu_value * SCALE_MULT;
        rounded_value  = scaled_product + (64'sd1 << (SCALE_SHIFT - 1));
        shifted_value  = rounded_value >>> SCALE_SHIFT;
        // Saturation to signed int8
        if (shifted_value > 32'sd127) begin
            quantized_out = 8'sd127;
        end else if (shifted_value < -32'sd128) begin
            quantized_out = -8'sd128;
        end else begin
            quantized_out = shifted_value[7:0];
        end
    end
endmodule