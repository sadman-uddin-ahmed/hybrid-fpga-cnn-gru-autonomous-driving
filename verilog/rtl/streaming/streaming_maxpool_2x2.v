`timescale 1ns / 1ps

module streaming_maxpool_2x2 #(
    parameter integer IMAGE_WIDTH  = 64,
    parameter integer IMAGE_HEIGHT = 64,
    parameter integer CHANNELS     = 16
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire signed [7:0]       input_value,
    input  wire [7:0]              input_x,
    input  wire [7:0]              input_y,
    input  wire [7:0]              input_channel_index,
    input  wire                    input_valid,
    output reg  signed [7:0]       output_value,
    output reg  [7:0]              output_x,
    output reg  [7:0]              output_y,
    output reg  [7:0]              output_channel_index,
    output reg                     output_valid
);
    localparam integer POOLED_WIDTH = IMAGE_WIDTH / 2;
    localparam integer TOP_PAIR_COUNT = POOLED_WIDTH * CHANNELS;
    reg signed [7:0] horizontal_left_value [0:CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] top_pair_max_memory [0:TOP_PAIR_COUNT-1];
    wire signed [7:0] horizontal_pair_max;
    wire signed [7:0] pooled_pair_max;
    integer top_pair_address;
    assign horizontal_pair_max =
        ($signed(horizontal_left_value[input_channel_index]) >=
         $signed(input_value)) ?
        horizontal_left_value[input_channel_index] :
        input_value;
    assign pooled_pair_max =
        ($signed(top_pair_max_memory[top_pair_address]) >=
         $signed(horizontal_pair_max)) ?
        top_pair_max_memory[top_pair_address] :
        horizontal_pair_max;
    always @(*) begin
        top_pair_address =
            ((input_x >> 1) * CHANNELS) +
            input_channel_index;
    end
    always @(posedge clk) begin
        if (reset) begin
            output_value         <= 8'sd0;
            output_x             <= 8'd0;
            output_y             <= 8'd0;
            output_channel_index <= 8'd0;
            output_valid         <= 1'b0;
        end else begin
            output_valid <= 1'b0;
            if (input_valid) begin
                if (input_x[0] == 1'b0) begin
                    horizontal_left_value[input_channel_index] <=
                        input_value;
                end else begin
                    if (input_y[0] == 1'b0) begin
                        top_pair_max_memory[top_pair_address] <=
                            horizontal_pair_max;
                    end else begin
                        output_value <= pooled_pair_max;
                        output_x <= input_x >> 1;
                        output_y <= input_y >> 1;
                        output_channel_index <=
                            input_channel_index;
                        output_valid <= 1'b1;
                    end
                end
            end
        end
    end
    initial begin
        $display(
            "ACTIVE RTL: streaming_maxpool_2x2 NONOVERLAP V1"
        );
        if (
            (IMAGE_WIDTH % 2) != 0 ||
            (IMAGE_HEIGHT % 2) != 0
        ) begin
            $display(
                "ERROR: streaming_maxpool_2x2 requires even image dimensions."
            );
        end
    end
endmodule