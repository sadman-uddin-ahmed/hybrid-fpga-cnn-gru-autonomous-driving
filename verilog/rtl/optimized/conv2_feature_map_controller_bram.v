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
    output wire [10:0]             weight_read_address,
    input  wire signed [7:0]       weight_read_data_0,
    input  wire signed [7:0]       weight_read_data_1,
    input  wire signed [7:0]       weight_read_data_2,
    input  wire signed [7:0]       weight_read_data_3,
    output wire [2:0]              bias_read_address,
    input  wire signed [31:0]      bias_read_data_0,
    input  wire signed [31:0]      bias_read_data_1,
    input  wire signed [31:0]      bias_read_data_2,
    input  wire signed [31:0]      bias_read_data_3,
    output reg  [14:0]             output_write_address,
    output reg  signed [7:0]       output_write_data,
    output reg                     output_write_enable,
    output reg                     done
);
    localparam OUTPUT_CHANNEL_GROUPS = OUTPUT_CHANNELS / 4;
    localparam STATE_IDLE             = 4'd0;
    localparam STATE_START_PIXEL_MAC  = 4'd1;
    localparam STATE_WAIT_PIXEL_MAC   = 4'd2;
    localparam STATE_WRITE_OUTPUTS    = 4'd3;
    localparam STATE_NEXT_PIXEL       = 4'd4;
    localparam STATE_DONE             = 4'd5;
    reg [3:0] current_state;
    reg [4:0] current_pixel_x;
    reg [4:0] current_pixel_y;
    reg [2:0] current_output_channel_group;
    reg [1:0] current_write_lane;
    reg pixel_mac_start;
    wire signed [7:0] pixel_mac_output_0;
    wire signed [7:0] pixel_mac_output_1;
    wire signed [7:0] pixel_mac_output_2;
    wire signed [7:0] pixel_mac_output_3;
    wire pixel_mac_done;
    wire [4:0] selected_output_channel;
    assign selected_output_channel = {
        current_output_channel_group,
        current_write_lane
    };
    initial begin
        $display("ACTIVE RTL: conv2_feature_map_controller_bram FOUR-LANE GROUPED OUTPUT V2A");
    end
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
        .output_channel_group(current_output_channel_group),
        .input_read_address(input_read_address),
        .input_read_data(input_read_data),
        .weight_read_address(weight_read_address),
        .weight_read_data_0(weight_read_data_0),
        .weight_read_data_1(weight_read_data_1),
        .weight_read_data_2(weight_read_data_2),
        .weight_read_data_3(weight_read_data_3),
        .bias_read_address(bias_read_address),
        .bias_read_data_0(bias_read_data_0),
        .bias_read_data_1(bias_read_data_1),
        .bias_read_data_2(bias_read_data_2),
        .bias_read_data_3(bias_read_data_3),
        .output_pixel_0(pixel_mac_output_0),
        .output_pixel_1(pixel_mac_output_1),
        .output_pixel_2(pixel_mac_output_2),
        .output_pixel_3(pixel_mac_output_3),
        .done(pixel_mac_done)
    );
    always @(posedge clk) begin
        if (rst) begin
            current_state                <= STATE_IDLE;
            current_pixel_x              <= 5'd0;
            current_pixel_y              <= 5'd0;
            current_output_channel_group <= 3'd0;
            current_write_lane           <= 2'd0;
            pixel_mac_start              <= 1'b0;
            output_write_address         <= 15'd0;
            output_write_data            <= 8'sd0;
            output_write_enable          <= 1'b0;
            done                         <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    pixel_mac_start     <= 1'b0;
                    output_write_enable <= 1'b0;
                    done                <= 1'b0;
                    if (start) begin
                        current_pixel_x              <= 5'd0;
                        current_pixel_y              <= 5'd0;
                        current_output_channel_group <= 3'd0;
                        current_write_lane           <= 2'd0;
                        current_state                <= STATE_START_PIXEL_MAC;
                    end
                end
                STATE_START_PIXEL_MAC: begin
                    pixel_mac_start     <= 1'b1;
                    output_write_enable <= 1'b0;
                    current_state       <= STATE_WAIT_PIXEL_MAC;
                end
                STATE_WAIT_PIXEL_MAC: begin
                    pixel_mac_start <= 1'b0;

                    if (pixel_mac_done) begin
                        current_write_lane <= 2'd0;
                        current_state      <= STATE_WRITE_OUTPUTS;
                    end
                end
                STATE_WRITE_OUTPUTS: begin
                    output_write_address <=
                        (selected_output_channel * OUTPUT_WIDTH * OUTPUT_HEIGHT) +
                        (current_pixel_y * OUTPUT_WIDTH) +
                        current_pixel_x;
                    case (current_write_lane)
                        2'd0: output_write_data <= pixel_mac_output_0;
                        2'd1: output_write_data <= pixel_mac_output_1;
                        2'd2: output_write_data <= pixel_mac_output_2;
                        2'd3: output_write_data <= pixel_mac_output_3;
                        default: output_write_data <= 8'sd0;
                    endcase
                    output_write_enable <= 1'b1;
                    if (current_write_lane < 2'd3) begin
                        current_write_lane <= current_write_lane + 1'b1;
                    end else begin
                        current_write_lane <= 2'd0;
                        current_state      <= STATE_NEXT_PIXEL;
                    end
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
                            if (current_output_channel_group < OUTPUT_CHANNEL_GROUPS - 1) begin
                                current_output_channel_group <=
                                    current_output_channel_group + 1'b1;
                                current_state <= STATE_START_PIXEL_MAC;
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
                    current_state       <= STATE_IDLE;
                end
                default: begin
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule
