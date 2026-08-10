`timescale 1ns / 1ps

module conv2_maxpool_controller_bram #(
    parameter INPUT_WIDTH      = 32,
    parameter INPUT_HEIGHT     = 32,
    parameter OUTPUT_WIDTH     = 16,
    parameter OUTPUT_HEIGHT    = 16,
    parameter OUTPUT_CHANNELS  = 32
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,
    output reg  [14:0]             input_read_address,
    input  wire signed [7:0]       input_read_data,
    output reg  [12:0]             output_write_address,
    output reg  signed [7:0]       output_write_data,
    output reg                     output_write_enable,
    output reg                     done
);
    localparam STATE_IDLE              = 4'd0;
    localparam STATE_REQUEST_PIXEL_00  = 4'd1;
    localparam STATE_WAIT_PIXEL_00     = 4'd2;
    localparam STATE_CAPTURE_PIXEL_00  = 4'd3;
    localparam STATE_REQUEST_PIXEL_01  = 4'd4;
    localparam STATE_WAIT_PIXEL_01     = 4'd5;
    localparam STATE_CAPTURE_PIXEL_01  = 4'd6;
    localparam STATE_REQUEST_PIXEL_10  = 4'd7;
    localparam STATE_WAIT_PIXEL_10     = 4'd8;
    localparam STATE_CAPTURE_PIXEL_10  = 4'd9;
    localparam STATE_REQUEST_PIXEL_11  = 4'd10;
    localparam STATE_WAIT_PIXEL_11     = 4'd11;
    localparam STATE_CAPTURE_PIXEL_11  = 4'd12;
    localparam STATE_WRITE_OUTPUT      = 4'd13;
    localparam STATE_NEXT_POOL_PIXEL   = 4'd14;
    localparam STATE_DONE              = 4'd15;
    reg [3:0] current_state;
    reg [4:0] current_output_channel;
    reg [3:0] current_pool_x;
    reg [3:0] current_pool_y;
    reg signed [7:0] max_value;
    reg [4:0] source_pixel_x;
    reg [4:0] source_pixel_y;
    always @(posedge clk) begin
        if (rst) begin
            current_state          <= STATE_IDLE;
            current_output_channel <= 5'd0;
            current_pool_x         <= 4'd0;
            current_pool_y         <= 4'd0;
            source_pixel_x         <= 5'd0;
            source_pixel_y         <= 5'd0;
            input_read_address     <= 15'd0;
            output_write_address   <= 13'd0;
            output_write_data      <= 8'sd0;
            output_write_enable    <= 1'b0;
            max_value              <= 8'sd0;
            done                   <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    output_write_enable <= 1'b0;
                    done                <= 1'b0;
                    if (start) begin
                        current_output_channel <= 5'd0;
                        current_pool_x         <= 4'd0;
                        current_pool_y         <= 4'd0;
                        source_pixel_x         <= 5'd0;
                        source_pixel_y         <= 5'd0;
                        current_state <= STATE_REQUEST_PIXEL_00;
                    end
                end
                STATE_REQUEST_PIXEL_00: begin
                    output_write_enable <= 1'b0;
                    source_pixel_x <= current_pool_x * 2;
                    source_pixel_y <= current_pool_y * 2;
                    input_read_address <=
                        (current_output_channel * INPUT_WIDTH * INPUT_HEIGHT) +
                        ((current_pool_y * 2) * INPUT_WIDTH) +
                        (current_pool_x * 2);
                    current_state <= STATE_WAIT_PIXEL_00;
                end
                STATE_WAIT_PIXEL_00: begin
                    current_state <= STATE_CAPTURE_PIXEL_00;
                end
                STATE_CAPTURE_PIXEL_00: begin
                    max_value <= input_read_data;
                    current_state <= STATE_REQUEST_PIXEL_01;
                end
                STATE_REQUEST_PIXEL_01: begin
                    input_read_address <=
                        (current_output_channel * INPUT_WIDTH * INPUT_HEIGHT) +
                        ((current_pool_y * 2) * INPUT_WIDTH) +
                        ((current_pool_x * 2) + 1);
                    current_state <= STATE_WAIT_PIXEL_01;
                end
                STATE_WAIT_PIXEL_01: begin
                    current_state <= STATE_CAPTURE_PIXEL_01;
                end
                STATE_CAPTURE_PIXEL_01: begin
                    if (input_read_data > max_value) begin
                        max_value <= input_read_data;
                    end
                    current_state <= STATE_REQUEST_PIXEL_10;
                end
                STATE_REQUEST_PIXEL_10: begin
                    input_read_address <=
                        (current_output_channel * INPUT_WIDTH * INPUT_HEIGHT) +
                        (((current_pool_y * 2) + 1) * INPUT_WIDTH) +
                        (current_pool_x * 2);
                    current_state <= STATE_WAIT_PIXEL_10;
                end
                STATE_WAIT_PIXEL_10: begin
                    current_state <= STATE_CAPTURE_PIXEL_10;
                end
                STATE_CAPTURE_PIXEL_10: begin
                    if (input_read_data > max_value) begin
                        max_value <= input_read_data;
                    end
                    current_state <= STATE_REQUEST_PIXEL_11;
                end
                STATE_REQUEST_PIXEL_11: begin
                    input_read_address <=
                        (current_output_channel * INPUT_WIDTH * INPUT_HEIGHT) +
                        (((current_pool_y * 2) + 1) * INPUT_WIDTH) +
                        ((current_pool_x * 2) + 1);
                    current_state <= STATE_WAIT_PIXEL_11;
                end
                STATE_WAIT_PIXEL_11: begin
                    current_state <= STATE_CAPTURE_PIXEL_11;
                end
                STATE_CAPTURE_PIXEL_11: begin
                    if (input_read_data > max_value) begin
                        max_value <= input_read_data;
                    end
                    current_state <= STATE_WRITE_OUTPUT;
                end
                STATE_WRITE_OUTPUT: begin
                    output_write_address <=
                        (current_output_channel * OUTPUT_WIDTH * OUTPUT_HEIGHT) +
                        (current_pool_y * OUTPUT_WIDTH) +
                        current_pool_x;
                    if (input_read_data > max_value) begin
                        output_write_data <= input_read_data;
                    end else begin
                        output_write_data <= max_value;
                    end
                    output_write_enable <= 1'b1;
                    current_state <= STATE_NEXT_POOL_PIXEL;
                end
                STATE_NEXT_POOL_PIXEL: begin
                    output_write_enable <= 1'b0;
                    if (current_pool_x < OUTPUT_WIDTH - 1) begin
                        current_pool_x <= current_pool_x + 1'b1;
                        current_state  <= STATE_REQUEST_PIXEL_00;
                    end else begin
                        current_pool_x <= 4'd0;
                        if (current_pool_y < OUTPUT_HEIGHT - 1) begin
                            current_pool_y <= current_pool_y + 1'b1;
                            current_state  <= STATE_REQUEST_PIXEL_00;
                        end else begin
                            current_pool_y <= 4'd0;
                            if (current_output_channel < OUTPUT_CHANNELS - 1) begin
                                current_output_channel <= current_output_channel + 1'b1;
                                current_state          <= STATE_REQUEST_PIXEL_00;
                            end else begin
                                current_state <= STATE_DONE;
                            end
                        end
                    end
                end
                STATE_DONE: begin
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