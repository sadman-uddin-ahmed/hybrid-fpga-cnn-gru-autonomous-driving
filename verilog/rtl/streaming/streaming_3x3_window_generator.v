`timescale 1ns / 1ps

module streaming_3x3_window_generator #(
    parameter integer IMAGE_WIDTH  = 64,
    parameter integer IMAGE_HEIGHT = 64
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    output wire                    input_ready,
    input  wire signed [7:0]       input_value,
    output reg  signed [7:0]       window_value_0,
    output reg  signed [7:0]       window_value_1,
    output reg  signed [7:0]       window_value_2,
    output reg  signed [7:0]       window_value_3,
    output reg  signed [7:0]       window_value_4,
    output reg  signed [7:0]       window_value_5,
    output reg  signed [7:0]       window_value_6,
    output reg  signed [7:0]       window_value_7,
    output reg  signed [7:0]       window_value_8,
    output reg  [7:0]              window_x,
    output reg  [7:0]              window_y,
    output reg                     window_valid
);
    localparam integer PADDED_WIDTH  = IMAGE_WIDTH + 2;
    localparam integer PADDED_HEIGHT = IMAGE_HEIGHT + 2;
    (* ram_style = "distributed" *)
    reg signed [7:0] line_buffer_0 [0:PADDED_WIDTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] line_buffer_1 [0:PADDED_WIDTH-1];
    reg [7:0] padded_x;
    reg [7:0] padded_y;
    reg signed [7:0] top_shift_0;
    reg signed [7:0] top_shift_1;
    reg signed [7:0] middle_shift_0;
    reg signed [7:0] middle_shift_1;
    reg signed [7:0] bottom_shift_0;
    reg signed [7:0] bottom_shift_1;
    wire signed [7:0] previous_row_value;
    wire signed [7:0] two_rows_back_value;
    assign previous_row_value =
        line_buffer_0[padded_x];
    assign two_rows_back_value =
        line_buffer_1[padded_x];
    assign input_ready = 1'b1;
    initial begin
        $display("ACTIVE RTL: streaming_3x3_window_generator PADDED-STREAM V1");
    end
    always @(posedge clk) begin
        if (reset) begin
            padded_x <= 8'd0;
            padded_y <= 8'd0;
            top_shift_0    <= 8'sd0;
            top_shift_1    <= 8'sd0;
            middle_shift_0 <= 8'sd0;
            middle_shift_1 <= 8'sd0;
            bottom_shift_0 <= 8'sd0;
            bottom_shift_1 <= 8'sd0;
            window_value_0 <= 8'sd0;
            window_value_1 <= 8'sd0;
            window_value_2 <= 8'sd0;
            window_value_3 <= 8'sd0;
            window_value_4 <= 8'sd0;
            window_value_5 <= 8'sd0;
            window_value_6 <= 8'sd0;
            window_value_7 <= 8'sd0;
            window_value_8 <= 8'sd0;
            window_x     <= 8'd0;
            window_y     <= 8'd0;
            window_valid <= 1'b0;
        end else begin
            window_valid <= 1'b0;
            if (input_valid) begin
                line_buffer_1[padded_x] <=
                    line_buffer_0[padded_x];
                line_buffer_0[padded_x] <=
                    input_value;
                if (padded_x == 8'd0) begin
                    top_shift_0 <= 8'sd0;
                    top_shift_1 <= two_rows_back_value;
                    middle_shift_0 <= 8'sd0;
                    middle_shift_1 <= previous_row_value;
                    bottom_shift_0 <= 8'sd0;
                    bottom_shift_1 <= input_value;
                end else begin
                    if (
                        (padded_x >= 8'd2) &&
                        (padded_y >= 8'd2)
                    ) begin
                        window_value_0 <= top_shift_0;
                        window_value_1 <= top_shift_1;
                        window_value_2 <= two_rows_back_value;
                        window_value_3 <= middle_shift_0;
                        window_value_4 <= middle_shift_1;
                        window_value_5 <= previous_row_value;
                        window_value_6 <= bottom_shift_0;
                        window_value_7 <= bottom_shift_1;
                        window_value_8 <= input_value;
                        window_x <= padded_x - 8'd2;
                        window_y <= padded_y - 8'd2;
                        window_valid <= 1'b1;
                    end
                    top_shift_0 <= top_shift_1;
                    top_shift_1 <= two_rows_back_value;
                    middle_shift_0 <= middle_shift_1;
                    middle_shift_1 <= previous_row_value;
                    bottom_shift_0 <= bottom_shift_1;
                    bottom_shift_1 <= input_value;
                end
                if (padded_x == (PADDED_WIDTH - 1)) begin
                    padded_x <= 8'd0;
                    if (padded_y == (PADDED_HEIGHT - 1)) begin
                        padded_y <= 8'd0;
                    end else begin
                        padded_y <= padded_y + 8'd1;
                    end
                end else begin
                    padded_x <= padded_x + 8'd1;
                end
            end
        end
    end
endmodule