`timescale 1ns / 1ps

module conv2_feature_map_controller_bram #(
    parameter INPUT_WIDTH        = 32,
    parameter INPUT_HEIGHT       = 32,
    parameter OUTPUT_WIDTH       = 32,
    parameter OUTPUT_HEIGHT      = 32,
    parameter INPUT_CHANNELS     = 16,
    parameter OUTPUT_CHANNELS    = 32,
    parameter SCALE_MULT         = 1516810,
    parameter SCALE_SHIFT        = 30
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,
    output wire [13:0]             input_read_address,
    input  wire signed [7:0]       input_read_data,
    output wire [12:0]             weight_read_address,
    input  wire signed [7:0]       weight_read_data,
    output wire [4:0]              bias_read_address,
    input  wire signed [31:0]      bias_read_data,
    output reg  [14:0]             output_write_address,
    output reg  signed [7:0]       output_write_data,
    output reg                     output_write_enable,
    output reg                     done
);
    localparam STATE_IDLE             = 4'd0;
    localparam STATE_START_PIXEL_MAC  = 4'd1;
    localparam STATE_WAIT_PIXEL_MAC   = 4'd2;
    localparam STATE_WRITE_OUTPUT     = 4'd3;
    localparam STATE_NEXT_PIXEL       = 4'd4;
    localparam STATE_DONE             = 4'd5;
    reg [3:0] current_state;
    reg [4:0] current_pixel_x;
    reg [4:0] current_pixel_y;
    reg [4:0] current_output_channel;
    reg pixel_mac_start;
    wire signed [7:0] pixel_mac_output;
    wire pixel_mac_done;
    conv2_pixel_mac_bram #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INPUT_HEIGHT(INPUT_HEIGHT),
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .OUTPUT_CHANNELS(OUTPUT_CHANNELS),
        .KERNEL_SIZE(3),
        .SCALE_MULT(SCALE_MULT),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) conv2_pixel_mac_inst (
        .clk(clk),
        .rst(rst),
        .start(pixel_mac_start),
        .pixel_x(current_pixel_x),
        .pixel_y(current_pixel_y),
        .output_channel(current_output_channel),
        .input_read_address(input_read_address),
        .input_read_data(input_read_data),
        .weight_read_address(weight_read_address),
        .weight_read_data(weight_read_data),
        .bias_read_address(bias_read_address),
        .bias_read_data(bias_read_data),
        .output_pixel(pixel_mac_output),
        .done(pixel_mac_done)
    );
    always @(posedge clk) begin
        if (rst) begin
            current_state          <= STATE_IDLE;
            current_pixel_x        <= 5'd0;
            current_pixel_y        <= 5'd0;
            current_output_channel <= 5'd0;
            pixel_mac_start        <= 1'b0;
            output_write_address   <= 15'd0;
            output_write_data      <= 8'sd0;
            output_write_enable    <= 1'b0;
            done                   <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    pixel_mac_start     <= 1'b0;
                    output_write_enable <= 1'b0;
                    done                <= 1'b0;
                    if (start) begin
                        current_pixel_x        <= 5'd0;
                        current_pixel_y        <= 5'd0;
                        current_output_channel <= 5'd0;

                        current_state <= STATE_START_PIXEL_MAC;
                    end
                end
                STATE_START_PIXEL_MAC: begin
                    pixel_mac_start     <= 1'b1;
                    output_write_enable <= 1'b0;

                    current_state <= STATE_WAIT_PIXEL_MAC;
                end
                STATE_WAIT_PIXEL_MAC: begin
                    pixel_mac_start <= 1'b0;
                    if (pixel_mac_done) begin
                        current_state <= STATE_WRITE_OUTPUT;
                    end
                end
                STATE_WRITE_OUTPUT: begin
                    output_write_address <=
                        (current_output_channel * OUTPUT_WIDTH * OUTPUT_HEIGHT) +
                        (current_pixel_y * OUTPUT_WIDTH) +
                        current_pixel_x;
                    output_write_data   <= pixel_mac_output;
                    output_write_enable <= 1'b1;
                    current_state <= STATE_NEXT_PIXEL;
                end
                STATE_NEXT_PIXEL: begin
                    output_write_enable <= 1'b0;
                    if (current_pixel_x < OUTPUT_WIDTH - 1) begin
                        current_pixel_x <= current_pixel_x + 1'b1;
                        current_state   <= STATE_START_PIXEL_MAC;
                    end else begin
                        current_pixel_x <= 5'd0;
                        if (current_pixel_y < OUTPUT_HEIGHT - 1) begin
                            current_pixel_y <= current_pixel_y + 1'b1;
                            current_state   <= STATE_START_PIXEL_MAC;
                        end else begin
                            current_pixel_y <= 5'd0;
                            if (current_output_channel < OUTPUT_CHANNELS - 1) begin
                                current_output_channel <= current_output_channel + 1'b1;
                                current_state          <= STATE_START_PIXEL_MAC;
                            end else begin
                                current_state <= STATE_DONE;
                            end
                        end
                    end
                end
                STATE_DONE: begin
                    pixel_mac_start     <= 1'b0;
                    output_write_enable <= 1'b0;
                    done                <= 1'b1;
                    current_state <= STATE_IDLE;
                end
                default: begin
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule