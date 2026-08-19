`timescale 1ns / 1ps

module conv_four_lane_channel_accumulator (
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    partial_sum_valid,
    input  wire                    first_input_channel,
    input  wire                    last_input_channel,
    input  wire signed [31:0]      bias_value_0,
    input  wire signed [31:0]      bias_value_1,
    input  wire signed [31:0]      bias_value_2,
    input  wire signed [31:0]      bias_value_3,
    input  wire signed [63:0]      partial_sum_0,
    input  wire signed [63:0]      partial_sum_1,
    input  wire signed [63:0]      partial_sum_2,
    input  wire signed [63:0]      partial_sum_3,
    output reg  signed [63:0]      accumulated_sum_0,
    output reg  signed [63:0]      accumulated_sum_1,
    output reg  signed [63:0]      accumulated_sum_2,
    output reg  signed [63:0]      accumulated_sum_3,
    output reg                     accumulated_sum_valid
);
    reg signed [63:0] accumulator_0;
    reg signed [63:0] accumulator_1;
    reg signed [63:0] accumulator_2;
    reg signed [63:0] accumulator_3;
    wire signed [63:0] bias_extended_0;
    wire signed [63:0] bias_extended_1;
    wire signed [63:0] bias_extended_2;
    wire signed [63:0] bias_extended_3;
    assign bias_extended_0 =
        {{32{bias_value_0[31]}}, bias_value_0};
    assign bias_extended_1 =
        {{32{bias_value_1[31]}}, bias_value_1};
    assign bias_extended_2 =
        {{32{bias_value_2[31]}}, bias_value_2};
    assign bias_extended_3 =
        {{32{bias_value_3[31]}}, bias_value_3};
    initial begin
        $display("ACTIVE RTL: conv_four_lane_channel_accumulator FOUR-LANE V1");
    end
    always @(posedge clk) begin
        if (reset) begin
            accumulator_0        <= 64'sd0;
            accumulator_1        <= 64'sd0;
            accumulator_2        <= 64'sd0;
            accumulator_3        <= 64'sd0;
            accumulated_sum_0    <= 64'sd0;
            accumulated_sum_1    <= 64'sd0;
            accumulated_sum_2    <= 64'sd0;
            accumulated_sum_3    <= 64'sd0;
            accumulated_sum_valid <= 1'b0;
        end else begin
            accumulated_sum_valid <= 1'b0;
            if (partial_sum_valid) begin
                if (first_input_channel) begin
                    if (last_input_channel) begin
                        accumulated_sum_0 <=
                            bias_extended_0 + partial_sum_0;
                        accumulated_sum_1 <=
                            bias_extended_1 + partial_sum_1;
                        accumulated_sum_2 <=
                            bias_extended_2 + partial_sum_2;
                        accumulated_sum_3 <=
                            bias_extended_3 + partial_sum_3;
                        accumulator_0 <= 64'sd0;
                        accumulator_1 <= 64'sd0;
                        accumulator_2 <= 64'sd0;
                        accumulator_3 <= 64'sd0;
                        accumulated_sum_valid <= 1'b1;
                    end else begin
                        accumulator_0 <=
                            bias_extended_0 + partial_sum_0;
                        accumulator_1 <=
                            bias_extended_1 + partial_sum_1;
                        accumulator_2 <=
                            bias_extended_2 + partial_sum_2;
                        accumulator_3 <=
                            bias_extended_3 + partial_sum_3;
                    end
                end else if (last_input_channel) begin
                    accumulated_sum_0 <=
                        accumulator_0 + partial_sum_0;
                    accumulated_sum_1 <=
                        accumulator_1 + partial_sum_1;
                    accumulated_sum_2 <=
                        accumulator_2 + partial_sum_2;
                    accumulated_sum_3 <=
                        accumulator_3 + partial_sum_3;
                    accumulator_0 <= 64'sd0;
                    accumulator_1 <= 64'sd0;
                    accumulator_2 <= 64'sd0;
                    accumulator_3 <= 64'sd0;
                    accumulated_sum_valid <= 1'b1;
                end else begin
                    accumulator_0 <=
                        accumulator_0 + partial_sum_0;
                    accumulator_1 <=
                        accumulator_1 + partial_sum_1;
                    accumulator_2 <=
                        accumulator_2 + partial_sum_2;
                    accumulator_3 <=
                        accumulator_3 + partial_sum_3;
                end
            end
        end
    end
endmodule
