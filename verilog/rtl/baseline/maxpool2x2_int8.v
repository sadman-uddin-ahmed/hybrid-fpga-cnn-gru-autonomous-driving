`timescale 1ns / 1ps

module maxpool2x2_int8 (
    input  wire signed [7:0] pixel_00,
    input  wire signed [7:0] pixel_01,
    input  wire signed [7:0] pixel_10,
    input  wire signed [7:0] pixel_11,
    output reg  signed [7:0] pooled_out
);
    reg signed [7:0] max_top;
    reg signed [7:0] max_bottom;
    always @(*) begin
        if (pixel_00 >= pixel_01) begin
            max_top = pixel_00;
        end else begin
            max_top = pixel_01;
        end
        if (pixel_10 >= pixel_11) begin
            max_bottom = pixel_10;
        end else begin
            max_bottom = pixel_11;
        end
        if (max_top >= max_bottom) begin
            pooled_out = max_top;
        end else begin
            pooled_out = max_bottom;
        end
    end
endmodule