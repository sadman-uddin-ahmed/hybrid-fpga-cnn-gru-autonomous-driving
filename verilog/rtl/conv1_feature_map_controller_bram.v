`timescale 1ns / 1ps

module conv1_feature_map_controller_bram #(
    parameter SCALE_MULT  = 1301962,
    parameter SCALE_SHIFT = 30
)(
    input  wire clk,
    input  wire reset,
    input  wire start,
    output reg  done,
    output wire input_read_enable,
    output wire [13:0] input_read_address,
    input  wire signed [7:0] input_read_data,
    output wire weight_read_enable,
    output wire [8:0] weight_read_address,
    input  wire signed [7:0] weight_read_data,
    output wire bias_read_enable,
    output wire [3:0] bias_read_address,
    input  wire signed [31:0] bias_read_data,
    output reg output_write_enable,
    output reg [15:0] output_write_address,
    output reg signed [7:0] output_write_data
);
    localparam STATE_IDLE         = 3'd0;
    localparam STATE_START_PIXEL  = 3'd1;
    localparam STATE_WAIT_PIXEL   = 3'd2;
    localparam STATE_WRITE_OUTPUT = 3'd3;
    localparam STATE_UPDATE_INDEX = 3'd4;
    localparam STATE_DONE         = 3'd5;
    reg [2:0] current_state;
    reg pixel_start;
    wire pixel_done;
    wire signed [7:0] pixel_output_data;
    reg [5:0] current_pixel_x;
    reg [5:0] current_pixel_y;
    reg [3:0] current_output_channel;
    reg [15:0] calculated_output_address;
    conv1_pixel_mac_bram #(
        .SCALE_MULT(SCALE_MULT),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) conv1_pixel_mac_bram_unit (
        .clk(clk),
        .reset(reset),
        .start(pixel_start),
        .pixel_x(current_pixel_x),
        .pixel_y(current_pixel_y),
        .output_channel(current_output_channel),
        .done(pixel_done),
        .output_pixel(pixel_output_data),
        .input_read_enable(input_read_enable),
        .input_read_address(input_read_address),
        .input_read_data(input_read_data),
        .weight_read_enable(weight_read_enable),
        .weight_read_address(weight_read_address),
        .weight_read_data(weight_read_data),
        .bias_read_enable(bias_read_enable),
        .bias_read_address(bias_read_address),
        .bias_read_data(bias_read_data)
    );
    always @(*) begin
        calculated_output_address =
            (current_output_channel * 16'd4096) +
            (current_pixel_y * 16'd64) +
            current_pixel_x;
    end
    always @(posedge clk) begin
        if (reset) begin
            current_state <= STATE_IDLE;
            done <= 1'b0;
            pixel_start <= 1'b0;
            current_pixel_x <= 6'd0;
            current_pixel_y <= 6'd0;
            current_output_channel <= 4'd0;
            output_write_enable <= 1'b0;
            output_write_address <= 16'd0;
            output_write_data <= 8'sd0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    pixel_start <= 1'b0;
                    output_write_enable <= 1'b0;
                    if (start) begin
                        current_pixel_x <= 6'd0;
                        current_pixel_y <= 6'd0;
                        current_output_channel <= 4'd0;
                        current_state <= STATE_START_PIXEL;
                    end
                end
                STATE_START_PIXEL: begin
                    pixel_start <= 1'b1;
                    output_write_enable <= 1'b0;
                    current_state <= STATE_WAIT_PIXEL;
                end
                STATE_WAIT_PIXEL: begin
                    pixel_start <= 1'b0;
                    output_write_enable <= 1'b0;

                    if (pixel_done) begin
                        current_state <= STATE_WRITE_OUTPUT;
                    end
                end
                STATE_WRITE_OUTPUT: begin
                    output_write_enable <= 1'b1;
                    output_write_address <= calculated_output_address;
                    output_write_data <= pixel_output_data;
                    current_state <= STATE_UPDATE_INDEX;
                end
                STATE_UPDATE_INDEX: begin
                    output_write_enable <= 1'b0;
                    if (current_pixel_x < 6'd63) begin
                        current_pixel_x <= current_pixel_x + 6'd1;
                        current_state <= STATE_START_PIXEL;
                    end else begin
                        current_pixel_x <= 6'd0;
                        if (current_pixel_y < 6'd63) begin
                            current_pixel_y <= current_pixel_y + 6'd1;
                            current_state <= STATE_START_PIXEL;
                        end else begin
                            current_pixel_y <= 6'd0;
                            if (current_output_channel < 4'd15) begin
                                current_output_channel <= current_output_channel + 4'd1;
                                current_state <= STATE_START_PIXEL;
                            end else begin
                                current_output_channel <= 4'd0;
                                current_state <= STATE_DONE;
                            end
                        end
                    end
                end
                STATE_DONE: begin
                    done <= 1'b1;
                    pixel_start <= 1'b0;
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