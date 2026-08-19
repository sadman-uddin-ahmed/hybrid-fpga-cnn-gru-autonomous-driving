`timescale 1ns / 1ps

module conv3x3_four_lane_channel_engine (
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    input  wire                    first_input_channel,
    input  wire                    last_input_channel,
    input  wire signed [7:0]       input_value_0,
    input  wire signed [7:0]       input_value_1,
    input  wire signed [7:0]       input_value_2,
    input  wire signed [7:0]       input_value_3,
    input  wire signed [7:0]       input_value_4,
    input  wire signed [7:0]       input_value_5,
    input  wire signed [7:0]       input_value_6,
    input  wire signed [7:0]       input_value_7,
    input  wire signed [7:0]       input_value_8,
    input  wire signed [7:0]       weight_lane_0_value_0,
    input  wire signed [7:0]       weight_lane_0_value_1,
    input  wire signed [7:0]       weight_lane_0_value_2,
    input  wire signed [7:0]       weight_lane_0_value_3,
    input  wire signed [7:0]       weight_lane_0_value_4,
    input  wire signed [7:0]       weight_lane_0_value_5,
    input  wire signed [7:0]       weight_lane_0_value_6,
    input  wire signed [7:0]       weight_lane_0_value_7,
    input  wire signed [7:0]       weight_lane_0_value_8,
    input  wire signed [7:0]       weight_lane_1_value_0,
    input  wire signed [7:0]       weight_lane_1_value_1,
    input  wire signed [7:0]       weight_lane_1_value_2,
    input  wire signed [7:0]       weight_lane_1_value_3,
    input  wire signed [7:0]       weight_lane_1_value_4,
    input  wire signed [7:0]       weight_lane_1_value_5,
    input  wire signed [7:0]       weight_lane_1_value_6,
    input  wire signed [7:0]       weight_lane_1_value_7,
    input  wire signed [7:0]       weight_lane_1_value_8,
    input  wire signed [7:0]       weight_lane_2_value_0,
    input  wire signed [7:0]       weight_lane_2_value_1,
    input  wire signed [7:0]       weight_lane_2_value_2,
    input  wire signed [7:0]       weight_lane_2_value_3,
    input  wire signed [7:0]       weight_lane_2_value_4,
    input  wire signed [7:0]       weight_lane_2_value_5,
    input  wire signed [7:0]       weight_lane_2_value_6,
    input  wire signed [7:0]       weight_lane_2_value_7,
    input  wire signed [7:0]       weight_lane_2_value_8,
    input  wire signed [7:0]       weight_lane_3_value_0,
    input  wire signed [7:0]       weight_lane_3_value_1,
    input  wire signed [7:0]       weight_lane_3_value_2,
    input  wire signed [7:0]       weight_lane_3_value_3,
    input  wire signed [7:0]       weight_lane_3_value_4,
    input  wire signed [7:0]       weight_lane_3_value_5,
    input  wire signed [7:0]       weight_lane_3_value_6,
    input  wire signed [7:0]       weight_lane_3_value_7,
    input  wire signed [7:0]       weight_lane_3_value_8,
    input  wire signed [31:0]      bias_value_0,
    input  wire signed [31:0]      bias_value_1,
    input  wire signed [31:0]      bias_value_2,
    input  wire signed [31:0]      bias_value_3,
    output wire signed [63:0]      accumulated_sum_0,
    output wire signed [63:0]      accumulated_sum_1,
    output wire signed [63:0]      accumulated_sum_2,
    output wire signed [63:0]      accumulated_sum_3,
    output wire                    accumulated_sum_valid
);
    wire signed [63:0] partial_sum_0;
    wire signed [63:0] partial_sum_1;
    wire signed [63:0] partial_sum_2;
    wire signed [63:0] partial_sum_3;
    wire               partial_sum_valid;
    reg first_input_channel_delay_0;
    reg first_input_channel_delay_1;
    reg first_input_channel_delay_2;
    reg first_input_channel_delay_3;
    reg first_input_channel_delay_4;
    reg last_input_channel_delay_0;
    reg last_input_channel_delay_1;
    reg last_input_channel_delay_2;
    reg last_input_channel_delay_3;
    reg last_input_channel_delay_4;
    reg signed [31:0] bias_value_0_delay_0;
    reg signed [31:0] bias_value_0_delay_1;
    reg signed [31:0] bias_value_0_delay_2;
    reg signed [31:0] bias_value_0_delay_3;
    reg signed [31:0] bias_value_0_delay_4;
    reg signed [31:0] bias_value_1_delay_0;
    reg signed [31:0] bias_value_1_delay_1;
    reg signed [31:0] bias_value_1_delay_2;
    reg signed [31:0] bias_value_1_delay_3;
    reg signed [31:0] bias_value_1_delay_4;
    reg signed [31:0] bias_value_2_delay_0;
    reg signed [31:0] bias_value_2_delay_1;
    reg signed [31:0] bias_value_2_delay_2;
    reg signed [31:0] bias_value_2_delay_3;
    reg signed [31:0] bias_value_2_delay_4;
    reg signed [31:0] bias_value_3_delay_0;
    reg signed [31:0] bias_value_3_delay_1;
    reg signed [31:0] bias_value_3_delay_2;
    reg signed [31:0] bias_value_3_delay_3;
    reg signed [31:0] bias_value_3_delay_4;
    initial begin
        $display("ACTIVE RTL: conv3x3_four_lane_channel_engine FOUR-LANE CHANNEL ENGINE V2");
    end
    // Align channel control and biases with the registered 3x3 results.
    always @(posedge clk) begin
        if (reset) begin
            first_input_channel_delay_0 <= 1'b0;
            first_input_channel_delay_1 <= 1'b0;
            first_input_channel_delay_2 <= 1'b0;
            first_input_channel_delay_3 <= 1'b0;
            first_input_channel_delay_4 <= 1'b0;
            last_input_channel_delay_0 <= 1'b0;
            last_input_channel_delay_1 <= 1'b0;
            last_input_channel_delay_2 <= 1'b0;
            last_input_channel_delay_3 <= 1'b0;
            last_input_channel_delay_4 <= 1'b0;
            bias_value_0_delay_0 <= 32'sd0;
            bias_value_0_delay_1 <= 32'sd0;
            bias_value_0_delay_2 <= 32'sd0;
            bias_value_0_delay_3 <= 32'sd0;
            bias_value_0_delay_4 <= 32'sd0;
            bias_value_1_delay_0 <= 32'sd0;
            bias_value_1_delay_1 <= 32'sd0;
            bias_value_1_delay_2 <= 32'sd0;
            bias_value_1_delay_3 <= 32'sd0;
            bias_value_1_delay_4 <= 32'sd0;
            bias_value_2_delay_0 <= 32'sd0;
            bias_value_2_delay_1 <= 32'sd0;
            bias_value_2_delay_2 <= 32'sd0;
            bias_value_2_delay_3 <= 32'sd0;
            bias_value_2_delay_4 <= 32'sd0;
            bias_value_3_delay_0 <= 32'sd0;
            bias_value_3_delay_1 <= 32'sd0;
            bias_value_3_delay_2 <= 32'sd0;
            bias_value_3_delay_3 <= 32'sd0;
            bias_value_3_delay_4 <= 32'sd0;
        end else begin
            first_input_channel_delay_0 <=
                input_valid && first_input_channel;
            first_input_channel_delay_1 <=
                first_input_channel_delay_0;
            first_input_channel_delay_2 <=
                first_input_channel_delay_1;
            first_input_channel_delay_3 <=
                first_input_channel_delay_2;
            first_input_channel_delay_4 <=
                first_input_channel_delay_3;
            last_input_channel_delay_0 <=
                input_valid && last_input_channel;
            last_input_channel_delay_1 <=
                last_input_channel_delay_0;
            last_input_channel_delay_2 <=
                last_input_channel_delay_1;
            last_input_channel_delay_3 <=
                last_input_channel_delay_2;
            last_input_channel_delay_4 <=
                last_input_channel_delay_3;
            bias_value_0_delay_0 <= bias_value_0;
            bias_value_0_delay_1 <= bias_value_0_delay_0;
            bias_value_0_delay_2 <= bias_value_0_delay_1;
            bias_value_0_delay_3 <= bias_value_0_delay_2;
            bias_value_0_delay_4 <= bias_value_0_delay_3;
            bias_value_1_delay_0 <= bias_value_1;
            bias_value_1_delay_1 <= bias_value_1_delay_0;
            bias_value_1_delay_2 <= bias_value_1_delay_1;
            bias_value_1_delay_3 <= bias_value_1_delay_2;
            bias_value_1_delay_4 <= bias_value_1_delay_3;
            bias_value_2_delay_0 <= bias_value_2;
            bias_value_2_delay_1 <= bias_value_2_delay_0;
            bias_value_2_delay_2 <= bias_value_2_delay_1;
            bias_value_2_delay_3 <= bias_value_2_delay_2;
            bias_value_2_delay_4 <= bias_value_2_delay_3;
            bias_value_3_delay_0 <= bias_value_3;
            bias_value_3_delay_1 <= bias_value_3_delay_0;
            bias_value_3_delay_2 <= bias_value_3_delay_1;
            bias_value_3_delay_3 <= bias_value_3_delay_2;
            bias_value_3_delay_4 <= bias_value_3_delay_3;
        end
    end
    conv3x3_four_lane_parallel parallel_dot_product_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(input_valid),
        .input_value_0(input_value_0),
        .input_value_1(input_value_1),
        .input_value_2(input_value_2),
        .input_value_3(input_value_3),
        .input_value_4(input_value_4),
        .input_value_5(input_value_5),
        .input_value_6(input_value_6),
        .input_value_7(input_value_7),
        .input_value_8(input_value_8),
        .weight_lane_0_value_0(weight_lane_0_value_0),
        .weight_lane_0_value_1(weight_lane_0_value_1),
        .weight_lane_0_value_2(weight_lane_0_value_2),
        .weight_lane_0_value_3(weight_lane_0_value_3),
        .weight_lane_0_value_4(weight_lane_0_value_4),
        .weight_lane_0_value_5(weight_lane_0_value_5),
        .weight_lane_0_value_6(weight_lane_0_value_6),
        .weight_lane_0_value_7(weight_lane_0_value_7),
        .weight_lane_0_value_8(weight_lane_0_value_8),
        .weight_lane_1_value_0(weight_lane_1_value_0),
        .weight_lane_1_value_1(weight_lane_1_value_1),
        .weight_lane_1_value_2(weight_lane_1_value_2),
        .weight_lane_1_value_3(weight_lane_1_value_3),
        .weight_lane_1_value_4(weight_lane_1_value_4),
        .weight_lane_1_value_5(weight_lane_1_value_5),
        .weight_lane_1_value_6(weight_lane_1_value_6),
        .weight_lane_1_value_7(weight_lane_1_value_7),
        .weight_lane_1_value_8(weight_lane_1_value_8),
        .weight_lane_2_value_0(weight_lane_2_value_0),
        .weight_lane_2_value_1(weight_lane_2_value_1),
        .weight_lane_2_value_2(weight_lane_2_value_2),
        .weight_lane_2_value_3(weight_lane_2_value_3),
        .weight_lane_2_value_4(weight_lane_2_value_4),
        .weight_lane_2_value_5(weight_lane_2_value_5),
        .weight_lane_2_value_6(weight_lane_2_value_6),
        .weight_lane_2_value_7(weight_lane_2_value_7),
        .weight_lane_2_value_8(weight_lane_2_value_8),
        .weight_lane_3_value_0(weight_lane_3_value_0),
        .weight_lane_3_value_1(weight_lane_3_value_1),
        .weight_lane_3_value_2(weight_lane_3_value_2),
        .weight_lane_3_value_3(weight_lane_3_value_3),
        .weight_lane_3_value_4(weight_lane_3_value_4),
        .weight_lane_3_value_5(weight_lane_3_value_5),
        .weight_lane_3_value_6(weight_lane_3_value_6),
        .weight_lane_3_value_7(weight_lane_3_value_7),
        .weight_lane_3_value_8(weight_lane_3_value_8),
        .partial_sum_0(partial_sum_0),
        .partial_sum_1(partial_sum_1),
        .partial_sum_2(partial_sum_2),
        .partial_sum_3(partial_sum_3),
        .partial_sum_valid(partial_sum_valid)
    );
    conv_four_lane_channel_accumulator channel_accumulator_inst (
        .clk(clk),
        .reset(reset),
        .partial_sum_valid(partial_sum_valid),
        .first_input_channel(first_input_channel_delay_4),
        .last_input_channel(last_input_channel_delay_4),
        .bias_value_0(bias_value_0_delay_4),
        .bias_value_1(bias_value_1_delay_4),
        .bias_value_2(bias_value_2_delay_4),
        .bias_value_3(bias_value_3_delay_4),
        .partial_sum_0(partial_sum_0),
        .partial_sum_1(partial_sum_1),
        .partial_sum_2(partial_sum_2),
        .partial_sum_3(partial_sum_3),
        .accumulated_sum_0(accumulated_sum_0),
        .accumulated_sum_1(accumulated_sum_1),
        .accumulated_sum_2(accumulated_sum_2),
        .accumulated_sum_3(accumulated_sum_3),
        .accumulated_sum_valid(accumulated_sum_valid)
    );
endmodule