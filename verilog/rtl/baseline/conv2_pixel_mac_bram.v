`timescale 1ns / 1ps

module conv2_pixel_mac_bram #(
    parameter INPUT_WIDTH        = 32,
    parameter INPUT_HEIGHT       = 32,
    parameter INPUT_CHANNELS     = 16,
    parameter OUTPUT_CHANNELS    = 32,
    parameter KERNEL_SIZE        = 3,
    parameter SCALE_MULT         = 1516810,
    parameter SCALE_SHIFT        = 30
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    start,

    input  wire [4:0]              pixel_x,
    input  wire [4:0]              pixel_y,
    input  wire [4:0]              output_channel,

    output reg  [13:0]             input_read_address,
    input  wire signed [7:0]       input_read_data,

    output reg  [12:0]             weight_read_address,
    input  wire signed [7:0]       weight_read_data,

    output reg  [4:0]              bias_read_address,
    input  wire signed [31:0]      bias_read_data,

    output reg  signed [7:0]       output_pixel,
    output reg                     done
);

    localparam STATE_IDLE               = 5'd0;
    localparam STATE_REQUEST_BIAS       = 5'd1;
    localparam STATE_WAIT_BIAS          = 5'd2;
    localparam STATE_CAPTURE_BIAS       = 5'd3;
    localparam STATE_CHECK_POSITION     = 5'd4;
    localparam STATE_REQUEST_INPUT      = 5'd5;
    localparam STATE_WAIT_INPUT         = 5'd6;
    localparam STATE_CAPTURE_INPUT      = 5'd7;
    localparam STATE_REQUEST_WEIGHT     = 5'd8;
    localparam STATE_WAIT_WEIGHT        = 5'd9;
    localparam STATE_CAPTURE_WEIGHT     = 5'd10;
    localparam STATE_REGISTER_PRODUCT   = 5'd11;
    localparam STATE_MULTIPLY_ACCUM     = 5'd12;
    localparam STATE_NEXT_KERNEL        = 5'd13;
    localparam STATE_QUANTIZE_MULTIPLY  = 5'd14;
    localparam STATE_QUANTIZE_ROUND     = 5'd15;
    localparam STATE_QUANTIZE_SHIFT     = 5'd16;
    localparam STATE_RELU_SATURATE      = 5'd17;
    localparam STATE_DONE               = 5'd18;

    reg [4:0] current_state;

    reg [3:0] input_channel_index;
    reg [1:0] kernel_y_index;
    reg [1:0] kernel_x_index;

    reg signed [6:0] calculated_input_x;
    reg signed [6:0] calculated_input_y;

    reg signed [7:0] captured_input_value;
    reg signed [7:0] captured_weight_value;

    reg signed [15:0] registered_product;
    reg signed [31:0] accumulator;

    reg signed [63:0] quantized_product;
    reg signed [63:0] rounded_quantized_product;
    reg signed [31:0] shifted_quantized_value;
    reg signed [31:0] signed_scale_multiplier;

    wire signed [31:0] calculated_input_x_wire;
    wire signed [31:0] calculated_input_y_wire;

    assign calculated_input_x_wire =
        $signed({2'b00, pixel_x}) +
        $signed({30'd0, kernel_x_index}) -
        32'sd1;

    assign calculated_input_y_wire =
        $signed({2'b00, pixel_y}) +
        $signed({30'd0, kernel_y_index}) -
        32'sd1;

    always @(posedge clk) begin
        if (rst) begin
            current_state             <= STATE_IDLE;

            input_read_address        <= 14'd0;
            weight_read_address       <= 13'd0;
            bias_read_address         <= 5'd0;

            output_pixel              <= 8'sd0;
            done                      <= 1'b0;

            input_channel_index       <= 4'd0;
            kernel_y_index            <= 2'd0;
            kernel_x_index            <= 2'd0;

            calculated_input_x        <= 7'sd0;
            calculated_input_y        <= 7'sd0;

            captured_input_value      <= 8'sd0;
            captured_weight_value     <= 8'sd0;

            registered_product        <= 16'sd0;
            accumulator               <= 32'sd0;

            quantized_product         <= 64'sd0;
            rounded_quantized_product <= 64'sd0;
            shifted_quantized_value   <= 32'sd0;
            signed_scale_multiplier   <= SCALE_MULT;
        end else begin
            case (current_state)

                STATE_IDLE: begin
                    done <= 1'b0;

                    if (start) begin
                        input_channel_index <= 4'd0;
                        kernel_y_index      <= 2'd0;
                        kernel_x_index      <= 2'd0;

                        accumulator         <= 32'sd0;
                        output_pixel        <= 8'sd0;
                        registered_product  <= 16'sd0;

                        signed_scale_multiplier <= SCALE_MULT;

                        bias_read_address   <= output_channel;
                        current_state       <= STATE_REQUEST_BIAS;
                    end
                end

                STATE_REQUEST_BIAS: begin
                    bias_read_address <= output_channel;
                    current_state     <= STATE_WAIT_BIAS;
                end

                STATE_WAIT_BIAS: begin
                    current_state <= STATE_CAPTURE_BIAS;
                end

                STATE_CAPTURE_BIAS: begin
                    accumulator   <= bias_read_data;
                    current_state <= STATE_CHECK_POSITION;
                end

                STATE_CHECK_POSITION: begin
                    calculated_input_x <= calculated_input_x_wire[6:0];
                    calculated_input_y <= calculated_input_y_wire[6:0];

                    if (
                        (calculated_input_x_wire < 0) ||
                        (calculated_input_x_wire >= INPUT_WIDTH) ||
                        (calculated_input_y_wire < 0) ||
                        (calculated_input_y_wire >= INPUT_HEIGHT)
                    ) begin
                        captured_input_value <= 8'sd0;

                        weight_read_address <=
                            (output_channel * INPUT_CHANNELS * KERNEL_SIZE * KERNEL_SIZE) +
                            (input_channel_index * KERNEL_SIZE * KERNEL_SIZE) +
                            (kernel_y_index * KERNEL_SIZE) +
                            kernel_x_index;

                        current_state <= STATE_REQUEST_WEIGHT;
                    end else begin
                        input_read_address <=
                            (input_channel_index * INPUT_WIDTH * INPUT_HEIGHT) +
                            (calculated_input_y_wire * INPUT_WIDTH) +
                            calculated_input_x_wire;

                        current_state <= STATE_REQUEST_INPUT;
                    end
                end

                STATE_REQUEST_INPUT: begin
                    input_read_address <=
                        (input_channel_index * INPUT_WIDTH * INPUT_HEIGHT) +
                        (calculated_input_y * INPUT_WIDTH) +
                        calculated_input_x;

                    current_state <= STATE_WAIT_INPUT;
                end

                STATE_WAIT_INPUT: begin
                    current_state <= STATE_CAPTURE_INPUT;
                end

                STATE_CAPTURE_INPUT: begin
                    captured_input_value <= input_read_data;

                    weight_read_address <=
                        (output_channel * INPUT_CHANNELS * KERNEL_SIZE * KERNEL_SIZE) +
                        (input_channel_index * KERNEL_SIZE * KERNEL_SIZE) +
                        (kernel_y_index * KERNEL_SIZE) +
                        kernel_x_index;

                    current_state <= STATE_REQUEST_WEIGHT;
                end

                STATE_REQUEST_WEIGHT: begin
                    weight_read_address <=
                        (output_channel * INPUT_CHANNELS * KERNEL_SIZE * KERNEL_SIZE) +
                        (input_channel_index * KERNEL_SIZE * KERNEL_SIZE) +
                        (kernel_y_index * KERNEL_SIZE) +
                        kernel_x_index;

                    current_state <= STATE_WAIT_WEIGHT;
                end

                STATE_WAIT_WEIGHT: begin
                    current_state <= STATE_CAPTURE_WEIGHT;
                end

                STATE_CAPTURE_WEIGHT: begin
                    captured_weight_value <= weight_read_data;
                    current_state         <= STATE_REGISTER_PRODUCT;
                end

                STATE_REGISTER_PRODUCT: begin
                    registered_product <= captured_input_value * captured_weight_value;
                    current_state      <= STATE_MULTIPLY_ACCUM;
                end

                STATE_MULTIPLY_ACCUM: begin
                    accumulator   <= accumulator + registered_product;
                    current_state <= STATE_NEXT_KERNEL;
                end

                STATE_NEXT_KERNEL: begin
                    if (kernel_x_index < KERNEL_SIZE - 1) begin
                        kernel_x_index <= kernel_x_index + 1'b1;
                        current_state  <= STATE_CHECK_POSITION;
                    end else begin
                        kernel_x_index <= 2'd0;

                        if (kernel_y_index < KERNEL_SIZE - 1) begin
                            kernel_y_index <= kernel_y_index + 1'b1;
                            current_state  <= STATE_CHECK_POSITION;
                        end else begin
                            kernel_y_index <= 2'd0;

                            if (input_channel_index < INPUT_CHANNELS - 1) begin
                                input_channel_index <= input_channel_index + 1'b1;
                                current_state       <= STATE_CHECK_POSITION;
                            end else begin
                                current_state <= STATE_QUANTIZE_MULTIPLY;
                            end
                        end
                    end
                end

                STATE_QUANTIZE_MULTIPLY: begin
                    quantized_product <= accumulator * signed_scale_multiplier;
                    current_state     <= STATE_QUANTIZE_ROUND;
                end

                STATE_QUANTIZE_ROUND: begin
                    if (quantized_product > 64'sd0) begin
                        rounded_quantized_product <= quantized_product + (64'sd1 <<< (SCALE_SHIFT - 1));
                    end else begin
                        rounded_quantized_product <= quantized_product;
                    end

                    current_state <= STATE_QUANTIZE_SHIFT;
                end

                STATE_QUANTIZE_SHIFT: begin
                    shifted_quantized_value <= rounded_quantized_product >>> SCALE_SHIFT;
                    current_state <= STATE_RELU_SATURATE;
                end

                STATE_RELU_SATURATE: begin
                    if (shifted_quantized_value <= 32'sd0) begin
                        output_pixel <= 8'sd0;
                    end else if (shifted_quantized_value > 32'sd127) begin
                        output_pixel <= 8'sd127;
                    end else begin
                        output_pixel <= shifted_quantized_value[7:0];
                    end

                    current_state <= STATE_DONE;
                end

                STATE_DONE: begin
                    done          <= 1'b1;
                    current_state <= STATE_IDLE;
                end

                default: begin
                    current_state <= STATE_IDLE;
                end

            endcase
        end
    end

endmodule