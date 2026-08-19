`timescale 1ns / 1ps

module conv3x3_parallel_dot_product (
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    input_valid,
    input  wire signed [7:0]       input_value_0,
    input  wire signed [7:0]       input_value_1,
    input  wire signed [7:0]       input_value_2,
    input  wire signed [7:0]       input_value_3,
    input  wire signed [7:0]       input_value_4,
    input  wire signed [7:0]       input_value_5,
    input  wire signed [7:0]       input_value_6,
    input  wire signed [7:0]       input_value_7,
    input  wire signed [7:0]       input_value_8,
    input  wire signed [7:0]       weight_value_0,
    input  wire signed [7:0]       weight_value_1,
    input  wire signed [7:0]       weight_value_2,
    input  wire signed [7:0]       weight_value_3,
    input  wire signed [7:0]       weight_value_4,
    input  wire signed [7:0]       weight_value_5,
    input  wire signed [7:0]       weight_value_6,
    input  wire signed [7:0]       weight_value_7,
    input  wire signed [7:0]       weight_value_8,
    output reg  signed [63:0]      partial_sum,
    output reg                     partial_sum_valid
);
    reg product_valid;
    reg sum_stage_1_valid;
    reg sum_stage_2_valid;
    reg sum_stage_3_valid;
    // Nine parallel registered W8A8 products.
    reg signed [15:0] registered_product_0;
    reg signed [15:0] registered_product_1;
    reg signed [15:0] registered_product_2;
    reg signed [15:0] registered_product_3;
    reg signed [15:0] registered_product_4;
    reg signed [15:0] registered_product_5;
    reg signed [15:0] registered_product_6;
    reg signed [15:0] registered_product_7;
    reg signed [15:0] registered_product_8;
    // Registered multi-level reduction tree.
    reg signed [31:0] sum_stage_1_0;
    reg signed [31:0] sum_stage_1_1;
    reg signed [31:0] sum_stage_1_2;
    reg signed [31:0] sum_stage_1_3;
    reg signed [15:0] product_8_stage_1;
    reg signed [31:0] sum_stage_2_0;
    reg signed [31:0] sum_stage_2_1;
    reg signed [15:0] product_8_stage_2;
    reg signed [31:0] sum_stage_3_0;
    reg signed [15:0] product_8_stage_3;
    wire signed [31:0] registered_product_extended_0;
    wire signed [31:0] registered_product_extended_1;
    wire signed [31:0] registered_product_extended_2;
    wire signed [31:0] registered_product_extended_3;
    wire signed [31:0] registered_product_extended_4;
    wire signed [31:0] registered_product_extended_5;
    wire signed [31:0] registered_product_extended_6;
    wire signed [31:0] registered_product_extended_7;
    wire signed [31:0] product_8_stage_3_extended;
    wire signed [31:0] final_sum_32;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_0;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_1;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_2;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_3;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_4;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_5;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_6;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_7;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_8;
    assign multiplier_result_0 =
        input_value_0 * weight_value_0;
    assign multiplier_result_1 =
        input_value_1 * weight_value_1;
    assign multiplier_result_2 =
        input_value_2 * weight_value_2;
    assign multiplier_result_3 =
        input_value_3 * weight_value_3;
    assign multiplier_result_4 =
        input_value_4 * weight_value_4;
    assign multiplier_result_5 =
        input_value_5 * weight_value_5;
    assign multiplier_result_6 =
        input_value_6 * weight_value_6;
    assign multiplier_result_7 =
        input_value_7 * weight_value_7;
    assign multiplier_result_8 =
        input_value_8 * weight_value_8;
    // Explicit sign extension prevents intermediate-width truncation.
    assign registered_product_extended_0 =
        {{16{registered_product_0[15]}}, registered_product_0};
    assign registered_product_extended_1 =
        {{16{registered_product_1[15]}}, registered_product_1};
    assign registered_product_extended_2 =
        {{16{registered_product_2[15]}}, registered_product_2};
    assign registered_product_extended_3 =
        {{16{registered_product_3[15]}}, registered_product_3};
    assign registered_product_extended_4 =
        {{16{registered_product_4[15]}}, registered_product_4};
    assign registered_product_extended_5 =
        {{16{registered_product_5[15]}}, registered_product_5};
    assign registered_product_extended_6 =
        {{16{registered_product_6[15]}}, registered_product_6};
    assign registered_product_extended_7 =
        {{16{registered_product_7[15]}}, registered_product_7};
    assign product_8_stage_3_extended =
        {{16{product_8_stage_3[15]}}, product_8_stage_3};
    assign final_sum_32 =
        sum_stage_3_0 +
        product_8_stage_3_extended;
    initial begin
        $display(
            "ACTIVE RTL: conv3x3_parallel_dot_product NINE-TAP PIPELINED V1"
        );
    end
    always @(posedge clk) begin
        if (rst) begin
            product_valid        <= 1'b0;
            sum_stage_1_valid    <= 1'b0;
            sum_stage_2_valid    <= 1'b0;
            sum_stage_3_valid    <= 1'b0;
            partial_sum_valid    <= 1'b0;
            registered_product_0 <= 16'sd0;
            registered_product_1 <= 16'sd0;
            registered_product_2 <= 16'sd0;
            registered_product_3 <= 16'sd0;
            registered_product_4 <= 16'sd0;
            registered_product_5 <= 16'sd0;
            registered_product_6 <= 16'sd0;
            registered_product_7 <= 16'sd0;
            registered_product_8 <= 16'sd0;
            sum_stage_1_0        <= 32'sd0;
            sum_stage_1_1        <= 32'sd0;
            sum_stage_1_2        <= 32'sd0;
            sum_stage_1_3        <= 32'sd0;
            product_8_stage_1    <= 16'sd0;
            sum_stage_2_0        <= 32'sd0;
            sum_stage_2_1        <= 32'sd0;
            product_8_stage_2    <= 16'sd0;
            sum_stage_3_0        <= 32'sd0;
            product_8_stage_3    <= 16'sd0;
            partial_sum          <= 64'sd0;
        end else begin
            product_valid     <= input_valid;
            sum_stage_1_valid <= product_valid;
            sum_stage_2_valid <= sum_stage_1_valid;
            sum_stage_3_valid <= sum_stage_2_valid;
            partial_sum_valid <= sum_stage_3_valid;
            // Stage 0: nine W8A8 products are evaluated concurrently.
            if (input_valid) begin
                registered_product_0 <= multiplier_result_0;
                registered_product_1 <= multiplier_result_1;
                registered_product_2 <= multiplier_result_2;
                registered_product_3 <= multiplier_result_3;
                registered_product_4 <= multiplier_result_4;
                registered_product_5 <= multiplier_result_5;
                registered_product_6 <= multiplier_result_6;
                registered_product_7 <= multiplier_result_7;
                registered_product_8 <= multiplier_result_8;
            end else begin
                registered_product_0 <= 16'sd0;
                registered_product_1 <= 16'sd0;
                registered_product_2 <= 16'sd0;
                registered_product_3 <= 16'sd0;
                registered_product_4 <= 16'sd0;
                registered_product_5 <= 16'sd0;
                registered_product_6 <= 16'sd0;
                registered_product_7 <= 16'sd0;
                registered_product_8 <= 16'sd0;
            end
            // Stage 1: nine products are reduced to four pairs plus tap 8.
            if (product_valid) begin
                sum_stage_1_0 <=
                    registered_product_extended_0 +
                    registered_product_extended_1;
                sum_stage_1_1 <=
                    registered_product_extended_2 +
                    registered_product_extended_3;
                sum_stage_1_2 <=
                    registered_product_extended_4 +
                    registered_product_extended_5;
                sum_stage_1_3 <=
                    registered_product_extended_6 +
                    registered_product_extended_7;
                product_8_stage_1 <=
                    registered_product_8;
            end else begin
                sum_stage_1_0     <= 32'sd0;
                sum_stage_1_1     <= 32'sd0;
                sum_stage_1_2     <= 32'sd0;
                sum_stage_1_3     <= 32'sd0;
                product_8_stage_1 <= 16'sd0;
            end
            // Stage 2: four pair sums are reduced to two partial sums.
            if (sum_stage_1_valid) begin
                sum_stage_2_0 <=
                    sum_stage_1_0 +
                    sum_stage_1_1;
                sum_stage_2_1 <=
                    sum_stage_1_2 +
                    sum_stage_1_3;
                product_8_stage_2 <=
                    product_8_stage_1;
            end else begin
                sum_stage_2_0     <= 32'sd0;
                sum_stage_2_1     <= 32'sd0;
                product_8_stage_2 <= 16'sd0;
            end
            // Stage 3: eight products are combined while tap 8 is aligned.
            if (sum_stage_2_valid) begin
                sum_stage_3_0 <=
                    sum_stage_2_0 +
                    sum_stage_2_1;
                product_8_stage_3 <=
                    product_8_stage_2;
            end else begin
                sum_stage_3_0     <= 32'sd0;
                product_8_stage_3 <= 16'sd0;
            end
            // Final stage: the ninth product completes the exact dot product.
            if (sum_stage_3_valid) begin
                partial_sum <=
                    {{32{final_sum_32[31]}}, final_sum_32};
            end else begin
                partial_sum <= 64'sd0;
            end
        end
    end
endmodule
