`timescale 1ns / 1ps

module conv1_pixel_mac_bram #(
    parameter SCALE_MULT  = 1301962,
    parameter SCALE_SHIFT = 30
)(
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire [5:0] pixel_x,
    input  wire [5:0] pixel_y,
    input  wire [3:0] output_channel,
    output reg done,
    output reg signed [7:0] output_pixel,
    output reg input_read_enable,
    output reg [13:0] input_read_address,
    input  wire signed [7:0] input_read_data,
    output reg weight_read_enable,
    output reg [8:0] weight_read_address,
    input  wire signed [7:0] weight_read_data,
    output reg bias_read_enable,
    output reg [3:0] bias_read_address,
    input  wire signed [31:0] bias_read_data
);
    localparam STATE_IDLE              = 5'd0;
    localparam STATE_READ_BIAS         = 5'd1;
    localparam STATE_WAIT_BIAS_1       = 5'd2;
    localparam STATE_WAIT_BIAS_2       = 5'd3;
    localparam STATE_CHECK_POSITION    = 5'd4;
    localparam STATE_REQUEST_READ      = 5'd5;
    localparam STATE_WAIT_READ_1       = 5'd6;
    localparam STATE_WAIT_READ_2       = 5'd7;
    localparam STATE_CAPTURE_READ      = 5'd8;
    localparam STATE_REGISTER_PRODUCT  = 5'd9;
    localparam STATE_ACCUMULATE        = 5'd10;
    localparam STATE_UPDATE_INDEX      = 5'd11;
    localparam STATE_QUANTIZE_MULTIPLY = 5'd12;
    localparam STATE_QUANTIZE_ROUND    = 5'd13;
    localparam STATE_QUANTIZE_SHIFT    = 5'd14;
    localparam STATE_RELU_SATURATE     = 5'd15;
    localparam STATE_DONE              = 5'd16;
    reg [4:0] current_state;
    reg [5:0] stored_pixel_x;
    reg [5:0] stored_pixel_y;
    reg [3:0] stored_output_channel;
    reg [1:0] input_channel_index;
    reg [1:0] kernel_row_index;
    reg [1:0] kernel_col_index;
    wire signed [7:0] current_input_x_position;
    wire signed [7:0] current_input_y_position;
    wire current_padding_active;
    wire [13:0] calculated_input_address;
    wire [8:0] calculated_weight_address;
    reg signed [31:0] accumulator;
    reg signed [7:0] input_value_for_mac;
    reg signed [7:0] weight_value_for_mac;
    reg signed [15:0] registered_product;
    reg signed [31:0] signed_scale_multiplier;
    reg signed [63:0] quantized_product;
    reg signed [63:0] quantized_rounded_product;
    reg signed [31:0] quantized_shifted_value;
    assign current_input_x_position =
        $signed({2'b00, stored_pixel_x}) +
        $signed({6'b000000, kernel_col_index}) -
        8'sd1;
    assign current_input_y_position =
        $signed({2'b00, stored_pixel_y}) +
        $signed({6'b000000, kernel_row_index}) -
        8'sd1;
    assign current_padding_active =
        (current_input_x_position < 8'sd0) ||
        (current_input_x_position > 8'sd63) ||
        (current_input_y_position < 8'sd0) ||
        (current_input_y_position > 8'sd63);
    assign calculated_input_address =
        (input_channel_index * 14'd4096) +
        (current_input_y_position[5:0] * 14'd64) +
        current_input_x_position[5:0];
    assign calculated_weight_address =
        (stored_output_channel * 9'd27) +
        (input_channel_index * 9'd9) +
        (kernel_row_index * 9'd3) +
        kernel_col_index;
    always @(posedge clk) begin
        if (reset) begin
            current_state <= STATE_IDLE;
            done <= 1'b0;
            output_pixel <= 8'sd0;
            input_read_enable <= 1'b0;
            input_read_address <= 14'd0;
            weight_read_enable <= 1'b0;
            weight_read_address <= 9'd0;
            bias_read_enable <= 1'b0;
            bias_read_address <= 4'd0;
            stored_pixel_x <= 6'd0;
            stored_pixel_y <= 6'd0;
            stored_output_channel <= 4'd0;
            input_channel_index <= 2'd0;
            kernel_row_index <= 2'd0;
            kernel_col_index <= 2'd0;
            accumulator <= 32'sd0;
            input_value_for_mac <= 8'sd0;
            weight_value_for_mac <= 8'sd0;
            registered_product <= 16'sd0;
            signed_scale_multiplier <= SCALE_MULT;
            quantized_product <= 64'sd0;
            quantized_rounded_product <= 64'sd0;
            quantized_shifted_value <= 32'sd0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    input_read_enable <= 1'b0;
                    weight_read_enable <= 1'b0;
                    bias_read_enable <= 1'b0;
                    if (start) begin
                        stored_pixel_x <= pixel_x;
                        stored_pixel_y <= pixel_y;
                        stored_output_channel <= output_channel;
                        input_channel_index <= 2'd0;
                        kernel_row_index <= 2'd0;
                        kernel_col_index <= 2'd0;
                        accumulator <= 32'sd0;
                        output_pixel <= 8'sd0;
                        registered_product <= 16'sd0;
                        signed_scale_multiplier <= SCALE_MULT;
                        current_state <= STATE_READ_BIAS;
                    end
                end
                STATE_READ_BIAS: begin
                    bias_read_enable <= 1'b1;
                    bias_read_address <= output_channel;

                    current_state <= STATE_WAIT_BIAS_1;
                end
                STATE_WAIT_BIAS_1: begin
                    bias_read_enable <= 1'b0;
                    current_state <= STATE_WAIT_BIAS_2;
                end
                STATE_WAIT_BIAS_2: begin
                    accumulator <= bias_read_data;
                    current_state <= STATE_CHECK_POSITION;
                end
                STATE_CHECK_POSITION: begin
                    current_state <= STATE_REQUEST_READ;
                end
                STATE_REQUEST_READ: begin
                    if (current_padding_active) begin
                        input_read_enable <= 1'b0;
                        input_read_address <= 14'd0;
                    end else begin
                        input_read_enable <= 1'b1;
                        input_read_address <= calculated_input_address;
                    end
                    weight_read_enable <= 1'b1;
                    weight_read_address <= calculated_weight_address;
                    current_state <= STATE_WAIT_READ_1;
                end
                STATE_WAIT_READ_1: begin
                    input_read_enable <= 1'b0;
                    weight_read_enable <= 1'b0;

                    current_state <= STATE_WAIT_READ_2;
                end
                STATE_WAIT_READ_2: begin
                    current_state <= STATE_CAPTURE_READ;
                end
                STATE_CAPTURE_READ: begin
                    if (current_padding_active) begin
                        input_value_for_mac <= 8'sd0;
                    end else begin
                        input_value_for_mac <= input_read_data;
                    end
                    weight_value_for_mac <= weight_read_data;
                    current_state <= STATE_REGISTER_PRODUCT;
                end
                STATE_REGISTER_PRODUCT: begin
                    registered_product <= input_value_for_mac * weight_value_for_mac;
                    current_state <= STATE_ACCUMULATE;
                end
                STATE_ACCUMULATE: begin
                    accumulator <= accumulator + registered_product;
                    current_state <= STATE_UPDATE_INDEX;
                end
                STATE_UPDATE_INDEX: begin
                    if (kernel_col_index < 2'd2) begin
                        kernel_col_index <= kernel_col_index + 2'd1;
                        current_state <= STATE_CHECK_POSITION;
                    end else begin
                        kernel_col_index <= 2'd0;
                        if (kernel_row_index < 2'd2) begin
                            kernel_row_index <= kernel_row_index + 2'd1;
                            current_state <= STATE_CHECK_POSITION;
                        end else begin
                            kernel_row_index <= 2'd0;
                            if (input_channel_index < 2'd2) begin
                                input_channel_index <= input_channel_index + 2'd1;
                                current_state <= STATE_CHECK_POSITION;
                            end else begin
                                input_channel_index <= 2'd0;
                                current_state <= STATE_QUANTIZE_MULTIPLY;
                            end
                        end
                    end
                end
                STATE_QUANTIZE_MULTIPLY: begin
                    quantized_product <= accumulator * signed_scale_multiplier;
                    current_state <= STATE_QUANTIZE_ROUND;
                end
                STATE_QUANTIZE_ROUND: begin
                    if (quantized_product > 64'sd0) begin
                        quantized_rounded_product <= quantized_product + (64'sd1 <<< (SCALE_SHIFT - 1));
                    end else begin
                        quantized_rounded_product <= quantized_product;
                    end
                    current_state <= STATE_QUANTIZE_SHIFT;
                end
                STATE_QUANTIZE_SHIFT: begin
                    quantized_shifted_value <= quantized_rounded_product >>> SCALE_SHIFT;
                    current_state <= STATE_RELU_SATURATE;
                end
                STATE_RELU_SATURATE: begin
                    if (quantized_shifted_value <= 32'sd0) begin
                        output_pixel <= 8'sd0;
                    end else if (quantized_shifted_value > 32'sd127) begin
                        output_pixel <= 8'sd127;
                    end else begin
                        output_pixel <= quantized_shifted_value[7:0];
                    end
                    current_state <= STATE_DONE;
                end
                STATE_DONE: begin
                    done <= 1'b1;
                    current_state <= STATE_IDLE;
                end
                default: begin
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule