`timescale 1ns / 1ps

module maxpool_controller_bram #(
    parameter INPUT_WIDTH   = 64,
    parameter INPUT_HEIGHT  = 64,
    parameter OUTPUT_WIDTH  = 32,
    parameter OUTPUT_HEIGHT = 32,
    parameter CHANNELS      = 16
)(
    input  wire clk,
    input  wire reset,
    input  wire start,
    output reg  done,
    output reg input_read_enable,
    output reg [15:0] input_read_address,
    input  wire signed [7:0] input_read_data,
    output reg output_write_enable,
    output reg [13:0] output_write_address,
    output reg signed [7:0] output_write_data
);
    localparam STATE_IDLE = 5'd0;
    localparam STATE_REQUEST_TOP_LEFT    = 5'd1;
    localparam STATE_WAIT_TOP_LEFT       = 5'd2;
    localparam STATE_CAPTURE_TOP_LEFT    = 5'd3;
    localparam STATE_REQUEST_TOP_RIGHT   = 5'd4;
    localparam STATE_WAIT_TOP_RIGHT      = 5'd5;
    localparam STATE_CAPTURE_TOP_RIGHT   = 5'd6;
    localparam STATE_REQUEST_BOTTOM_LEFT = 5'd7;
    localparam STATE_WAIT_BOTTOM_LEFT    = 5'd8;
    localparam STATE_CAPTURE_BOTTOM_LEFT = 5'd9;
    localparam STATE_REQUEST_BOTTOM_RIGHT = 5'd10;
    localparam STATE_WAIT_BOTTOM_RIGHT    = 5'd11;
    localparam STATE_CAPTURE_BOTTOM_RIGHT = 5'd12;
    localparam STATE_WRITE_OUTPUT = 5'd13;
    localparam STATE_UPDATE_INDEX = 5'd14;
    localparam STATE_DONE         = 5'd15;
    reg [4:0] current_state;
    reg [3:0] current_channel;
    reg [4:0] output_pixel_x;
    reg [4:0] output_pixel_y;
    reg [6:0] input_top_left_x;
    reg [6:0] input_top_left_y;
    reg signed [7:0] current_max_value;
    reg [15:0] calculated_input_top_left_address;
    reg [15:0] calculated_input_top_right_address;
    reg [15:0] calculated_input_bottom_left_address;
    reg [15:0] calculated_input_bottom_right_address;
    reg [13:0] calculated_output_address;
    always @(*) begin
        input_top_left_x = {1'b0, output_pixel_x, 1'b0};
        input_top_left_y = {1'b0, output_pixel_y, 1'b0};
        calculated_input_top_left_address =
            (current_channel * 16'd4096) +
            (input_top_left_y * 16'd64) +
            input_top_left_x;
        calculated_input_top_right_address =
            (current_channel * 16'd4096) +
            (input_top_left_y * 16'd64) +
            (input_top_left_x + 7'd1);
        calculated_input_bottom_left_address =
            (current_channel * 16'd4096) +
            ((input_top_left_y + 7'd1) * 16'd64) +
            input_top_left_x;
        calculated_input_bottom_right_address =
            (current_channel * 16'd4096) +
            ((input_top_left_y + 7'd1) * 16'd64) +
            (input_top_left_x + 7'd1);
        calculated_output_address =
            (current_channel * 14'd1024) +
            (output_pixel_y * 14'd32) +
            output_pixel_x;
    end
    always @(posedge clk) begin
        if (reset) begin
            current_state <= STATE_IDLE;
            done <= 1'b0;
            input_read_enable <= 1'b0;
            input_read_address <= 16'd0;
            output_write_enable <= 1'b0;
            output_write_address <= 14'd0;
            output_write_data <= 8'sd0;
            current_channel <= 4'd0;
            output_pixel_x <= 5'd0;
            output_pixel_y <= 5'd0;
            current_max_value <= 8'sd0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    input_read_enable <= 1'b0;
                    output_write_enable <= 1'b0;
                    if (start) begin
                        current_channel <= 4'd0;
                        output_pixel_x <= 5'd0;
                        output_pixel_y <= 5'd0;
                        current_max_value <= 8'sd0;
                        current_state <= STATE_REQUEST_TOP_LEFT;
                    end
                end
                STATE_REQUEST_TOP_LEFT: begin
                    input_read_enable <= 1'b1;
                    input_read_address <= calculated_input_top_left_address;
                    output_write_enable <= 1'b0;
                    current_state <= STATE_WAIT_TOP_LEFT;
                end
                STATE_WAIT_TOP_LEFT: begin
                    input_read_enable <= 1'b0;
                    current_state <= STATE_CAPTURE_TOP_LEFT;
                end
                STATE_CAPTURE_TOP_LEFT: begin
                    current_max_value <= input_read_data;
                    current_state <= STATE_REQUEST_TOP_RIGHT;
                end
                STATE_REQUEST_TOP_RIGHT: begin
                    input_read_enable <= 1'b1;
                    input_read_address <= calculated_input_top_right_address;
                    current_state <= STATE_WAIT_TOP_RIGHT;
                end
                STATE_WAIT_TOP_RIGHT: begin
                    input_read_enable <= 1'b0;
                    current_state <= STATE_CAPTURE_TOP_RIGHT;
                end
                STATE_CAPTURE_TOP_RIGHT: begin
                    if (input_read_data > current_max_value) begin
                        current_max_value <= input_read_data;
                    end
                    current_state <= STATE_REQUEST_BOTTOM_LEFT;
                end
                STATE_REQUEST_BOTTOM_LEFT: begin
                    input_read_enable <= 1'b1;
                    input_read_address <= calculated_input_bottom_left_address;
                    current_state <= STATE_WAIT_BOTTOM_LEFT;
                end
                STATE_WAIT_BOTTOM_LEFT: begin
                    input_read_enable <= 1'b0;
                    current_state <= STATE_CAPTURE_BOTTOM_LEFT;
                end
                STATE_CAPTURE_BOTTOM_LEFT: begin
                    if (input_read_data > current_max_value) begin
                        current_max_value <= input_read_data;
                    end
                    current_state <= STATE_REQUEST_BOTTOM_RIGHT;
                end
                STATE_REQUEST_BOTTOM_RIGHT: begin
                    input_read_enable <= 1'b1;
                    input_read_address <= calculated_input_bottom_right_address;

                    current_state <= STATE_WAIT_BOTTOM_RIGHT;
                end
                STATE_WAIT_BOTTOM_RIGHT: begin
                    input_read_enable <= 1'b0;

                    current_state <= STATE_CAPTURE_BOTTOM_RIGHT;
                end
                STATE_CAPTURE_BOTTOM_RIGHT: begin
                    if (input_read_data > current_max_value) begin
                        current_max_value <= input_read_data;
                    end
                    current_state <= STATE_WRITE_OUTPUT;
                end
                STATE_WRITE_OUTPUT: begin
                    output_write_enable <= 1'b1;
                    output_write_address <= calculated_output_address;
                    output_write_data <= current_max_value;

                    current_state <= STATE_UPDATE_INDEX;
                end
                STATE_UPDATE_INDEX: begin
                    output_write_enable <= 1'b0;
                    if (output_pixel_x < 5'd31) begin
                        output_pixel_x <= output_pixel_x + 5'd1;
                        current_state <= STATE_REQUEST_TOP_LEFT;
                    end else begin
                        output_pixel_x <= 5'd0;
                        if (output_pixel_y < 5'd31) begin
                            output_pixel_y <= output_pixel_y + 5'd1;
                            current_state <= STATE_REQUEST_TOP_LEFT;
                        end else begin
                            output_pixel_y <= 5'd0;
                            if (current_channel < 4'd15) begin
                                current_channel <= current_channel + 4'd1;
                                current_state <= STATE_REQUEST_TOP_LEFT;
                            end else begin
                                current_channel <= 4'd0;
                                current_state <= STATE_DONE;
                            end
                        end
                    end
                end
                STATE_DONE: begin
                    done <= 1'b1;
                    input_read_enable <= 1'b0;
                    output_write_enable <= 1'b0;
                    current_state <= STATE_IDLE;
                end
                default: begin
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule