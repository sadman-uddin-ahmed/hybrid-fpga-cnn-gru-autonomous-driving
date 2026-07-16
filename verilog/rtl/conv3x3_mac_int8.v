`timescale 1ns / 1ps

module conv3x3_mac_int8 (
    input  wire signed [7:0] pixel_00,
    input  wire signed [7:0] pixel_01,
    input  wire signed [7:0] pixel_02,
    input  wire signed [7:0] pixel_10,
    input  wire signed [7:0] pixel_11,
    input  wire signed [7:0] pixel_12,
    input  wire signed [7:0] pixel_20,
    input  wire signed [7:0] pixel_21,
    input  wire signed [7:0] pixel_22,
    input  wire signed [7:0] weight_00,
    input  wire signed [7:0] weight_01,
    input  wire signed [7:0] weight_02,
    input  wire signed [7:0] weight_10,
    input  wire signed [7:0] weight_11,
    input  wire signed [7:0] weight_12,
    input  wire signed [7:0] weight_20,
    input  wire signed [7:0] weight_21,
    input  wire signed [7:0] weight_22,
    output reg signed [31:0] mac_output
);
    always @(*) begin
        mac_output =
            (pixel_00 * weight_00) +
            (pixel_01 * weight_01) +
            (pixel_02 * weight_02) +
            (pixel_10 * weight_10) +
            (pixel_11 * weight_11) +
            (pixel_12 * weight_12) +
            (pixel_20 * weight_20) +
            (pixel_21 * weight_21) +
            (pixel_22 * weight_22);
    end
endmodule