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
    input  wire [2:0]              output_channel_group,
    output reg  [13:0]             input_read_address,
    input  wire signed [7:0]       input_read_data,
    output reg  [10:0]             weight_read_address,
    input  wire signed [7:0]       weight_read_data_0,
    input  wire signed [7:0]       weight_read_data_1,
    input  wire signed [7:0]       weight_read_data_2,
    input  wire signed [7:0]       weight_read_data_3,
    output reg  [2:0]              bias_read_address,
    input  wire signed [31:0]      bias_read_data_0,
    input  wire signed [31:0]      bias_read_data_1,
    input  wire signed [31:0]      bias_read_data_2,
    input  wire signed [31:0]      bias_read_data_3,
    output reg  signed [7:0]       output_pixel_0,
    output reg  signed [7:0]       output_pixel_1,
    output reg  signed [7:0]       output_pixel_2,
    output reg  signed [7:0]       output_pixel_3,
    output reg                     done
);
    localparam TOTAL_MAC_TERMS         = INPUT_CHANNELS * KERNEL_SIZE * KERNEL_SIZE;
    localparam STATE_IDLE              = 4'd0;
    localparam STATE_WAIT_BIAS         = 4'd1;
    localparam STATE_CAPTURE_BIAS      = 4'd2;
    localparam STATE_RUN_MAC           = 4'd3;
    localparam STATE_QUANTIZE_MULTIPLY = 4'd4;
    localparam STATE_QUANTIZE_ROUND    = 4'd5;
    localparam STATE_QUANTIZE_SHIFT    = 4'd6;
    localparam STATE_RELU_SATURATE     = 4'd7;
    localparam STATE_DONE              = 4'd8;
    reg [3:0] current_state;
    reg [3:0] input_channel_index;
    reg [1:0] kernel_y_index;
    reg [1:0] kernel_x_index;
    reg [7:0] issued_term_count;
    reg [7:0] accumulated_term_count;
    reg response_valid_stage_0;
    reg response_valid_stage_1;
    reg input_valid_stage_0;
    reg input_valid_stage_1;
    reg product_valid;
    reg signed [15:0] registered_product_0;
    reg signed [15:0] registered_product_1;
    reg signed [15:0] registered_product_2;
    reg signed [15:0] registered_product_3;
    reg signed [31:0] accumulator_0;
    reg signed [31:0] accumulator_1;
    reg signed [31:0] accumulator_2;
    reg signed [31:0] accumulator_3;
    reg [1:0] quantize_lane_index;
    reg signed [31:0] selected_accumulator;
    reg signed [63:0] quantized_product;
    reg signed [63:0] rounded_quantized_product;
    reg signed [31:0] shifted_quantized_value;
    reg signed [31:0] signed_scale_multiplier;
    wire signed [31:0] calculated_input_x_wire;
    wire signed [31:0] calculated_input_y_wire;
    wire current_position_valid;
    wire signed [7:0] aligned_input_value;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_0;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_1;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_2;
    (* use_dsp = "yes" *) wire signed [15:0] multiplier_result_3;
    assign calculated_input_x_wire =
        $signed({2'b00, pixel_x}) +
        $signed({30'd0, kernel_x_index}) -
        32'sd1;
    assign calculated_input_y_wire =
        $signed({2'b00, pixel_y}) +
        $signed({30'd0, kernel_y_index}) -
        32'sd1;
    assign current_position_valid =
        (calculated_input_x_wire >= 0) &&
        (calculated_input_x_wire < INPUT_WIDTH) &&
        (calculated_input_y_wire >= 0) &&
        (calculated_input_y_wire < INPUT_HEIGHT);
    assign aligned_input_value =
        input_valid_stage_1 ? input_read_data : 8'sd0;
    assign multiplier_result_0 = aligned_input_value * weight_read_data_0;
    assign multiplier_result_1 = aligned_input_value * weight_read_data_1;
    assign multiplier_result_2 = aligned_input_value * weight_read_data_2;
    assign multiplier_result_3 = aligned_input_value * weight_read_data_3;
    always @(*) begin
        case (quantize_lane_index)
            2'd0: selected_accumulator = accumulator_0;
            2'd1: selected_accumulator = accumulator_1;
            2'd2: selected_accumulator = accumulator_2;
            2'd3: selected_accumulator = accumulator_3;
            default: selected_accumulator = 32'sd0;
        endcase
    end
    initial begin
        $display("ACTIVE RTL: conv2_pixel_mac_bram FOUR-LANE OUTPUT-CHANNEL PARALLEL V2A");
    end
    always @(posedge clk) begin
        if (rst) begin
            current_state             <= STATE_IDLE;
            input_read_address        <= 14'd0;
            weight_read_address       <= 11'd0;
            bias_read_address         <= 3'd0;
            output_pixel_0            <= 8'sd0;
            output_pixel_1            <= 8'sd0;
            output_pixel_2            <= 8'sd0;
            output_pixel_3            <= 8'sd0;
            done                      <= 1'b0;
            input_channel_index       <= 4'd0;
            kernel_y_index            <= 2'd0;
            kernel_x_index            <= 2'd0;
            issued_term_count         <= 8'd0;
            accumulated_term_count    <= 8'd0;
            response_valid_stage_0    <= 1'b0;
            response_valid_stage_1    <= 1'b0;
            input_valid_stage_0       <= 1'b0;
            input_valid_stage_1       <= 1'b0;
            product_valid             <= 1'b0;
            registered_product_0      <= 16'sd0;
            registered_product_1      <= 16'sd0;
            registered_product_2      <= 16'sd0;
            registered_product_3      <= 16'sd0;
            accumulator_0             <= 32'sd0;
            accumulator_1             <= 32'sd0;
            accumulator_2             <= 32'sd0;
            accumulator_3             <= 32'sd0;
            quantize_lane_index       <= 2'd0;
            quantized_product         <= 64'sd0;
            rounded_quantized_product <= 64'sd0;
            shifted_quantized_value   <= 32'sd0;
            signed_scale_multiplier   <= SCALE_MULT;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        input_channel_index    <= 4'd0;
                        kernel_y_index         <= 2'd0;
                        kernel_x_index         <= 2'd0;
                        issued_term_count      <= 8'd0;
                        accumulated_term_count <= 8'd0;
                        response_valid_stage_0 <= 1'b0;
                        response_valid_stage_1 <= 1'b0;
                        input_valid_stage_0    <= 1'b0;
                        input_valid_stage_1    <= 1'b0;
                        product_valid          <= 1'b0;
                        registered_product_0   <= 16'sd0;
                        registered_product_1   <= 16'sd0;
                        registered_product_2   <= 16'sd0;
                        registered_product_3   <= 16'sd0;
                        accumulator_0          <= 32'sd0;
                        accumulator_1          <= 32'sd0;
                        accumulator_2          <= 32'sd0;
                        accumulator_3          <= 32'sd0;
                        output_pixel_0         <= 8'sd0;
                        output_pixel_1         <= 8'sd0;
                        output_pixel_2         <= 8'sd0;
                        output_pixel_3         <= 8'sd0;
                        quantize_lane_index     <= 2'd0;
                        signed_scale_multiplier <= SCALE_MULT;
                        bias_read_address       <= output_channel_group;
                        current_state           <= STATE_WAIT_BIAS;
                    end
                end
                STATE_WAIT_BIAS: begin
                    bias_read_address <= output_channel_group;
                    current_state     <= STATE_CAPTURE_BIAS;
                end
                STATE_CAPTURE_BIAS: begin
                    accumulator_0 <= bias_read_data_0;
                    accumulator_1 <= bias_read_data_1;
                    accumulator_2 <= bias_read_data_2;
                    accumulator_3 <= bias_read_data_3;
                    current_state <= STATE_RUN_MAC;
                end
                STATE_RUN_MAC: begin
                    response_valid_stage_1 <= response_valid_stage_0;
                    input_valid_stage_1    <= input_valid_stage_0;
                    response_valid_stage_0 <= 1'b0;
                    input_valid_stage_0    <= 1'b0;
                    product_valid          <= response_valid_stage_1;
                    if (issued_term_count < TOTAL_MAC_TERMS) begin
                        if (current_position_valid) begin
                            input_read_address <=
                                (input_channel_index * INPUT_WIDTH * INPUT_HEIGHT) +
                                (calculated_input_y_wire * INPUT_WIDTH) +
                                calculated_input_x_wire;
                        end else begin
                            input_read_address <= 14'd0;
                        end
                        weight_read_address <=
                            (output_channel_group * INPUT_CHANNELS * KERNEL_SIZE * KERNEL_SIZE) +
                            (input_channel_index * KERNEL_SIZE * KERNEL_SIZE) +
                            (kernel_y_index * KERNEL_SIZE) +
                            kernel_x_index;
                        response_valid_stage_0 <= 1'b1;
                        input_valid_stage_0    <= current_position_valid;
                        issued_term_count      <= issued_term_count + 1'b1;
                        if (kernel_x_index < KERNEL_SIZE - 1) begin
                            kernel_x_index <= kernel_x_index + 1'b1;
                        end else begin
                            kernel_x_index <= 2'd0;
                            if (kernel_y_index < KERNEL_SIZE - 1) begin
                                kernel_y_index <= kernel_y_index + 1'b1;
                            end else begin
                                kernel_y_index <= 2'd0;
                                if (input_channel_index < INPUT_CHANNELS - 1) begin
                                    input_channel_index <= input_channel_index + 1'b1;
                                end else begin
                                    input_channel_index <= 4'd0;
                                end
                            end
                        end
                    end
                    if (response_valid_stage_1) begin
                        registered_product_0 <= multiplier_result_0;
                        registered_product_1 <= multiplier_result_1;
                        registered_product_2 <= multiplier_result_2;
                        registered_product_3 <= multiplier_result_3;
                    end else begin
                        registered_product_0 <= 16'sd0;
                        registered_product_1 <= 16'sd0;
                        registered_product_2 <= 16'sd0;
                        registered_product_3 <= 16'sd0;
                    end
                    if (product_valid) begin
                        accumulator_0 <= accumulator_0 + registered_product_0;
                        accumulator_1 <= accumulator_1 + registered_product_1;
                        accumulator_2 <= accumulator_2 + registered_product_2;
                        accumulator_3 <= accumulator_3 + registered_product_3;
                        if (accumulated_term_count < TOTAL_MAC_TERMS - 1) begin
                            accumulated_term_count <= accumulated_term_count + 1'b1;
                        end else begin
                            accumulated_term_count <= accumulated_term_count + 1'b1;
                            quantize_lane_index    <= 2'd0;
                            current_state          <= STATE_QUANTIZE_MULTIPLY;
                        end
                    end
                end
                STATE_QUANTIZE_MULTIPLY: begin
                    quantized_product <= selected_accumulator * signed_scale_multiplier;
                    current_state     <= STATE_QUANTIZE_ROUND;
                end
                STATE_QUANTIZE_ROUND: begin
                    if (quantized_product > 64'sd0) begin
                        rounded_quantized_product <=
                            quantized_product + (64'sd1 <<< (SCALE_SHIFT - 1));
                    end else begin
                        rounded_quantized_product <= quantized_product;
                    end
                    current_state <= STATE_QUANTIZE_SHIFT;
                end
                STATE_QUANTIZE_SHIFT: begin
                    shifted_quantized_value <=
                        rounded_quantized_product >>> SCALE_SHIFT;
                    current_state <= STATE_RELU_SATURATE;
                end
                STATE_RELU_SATURATE: begin
                    case (quantize_lane_index)
                        2'd0: begin
                            if (shifted_quantized_value <= 32'sd0) begin
                                output_pixel_0 <= 8'sd0;
                            end else if (shifted_quantized_value > 32'sd127) begin
                                output_pixel_0 <= 8'sd127;
                            end else begin
                                output_pixel_0 <= shifted_quantized_value[7:0];
                            end
                        end
                        2'd1: begin
                            if (shifted_quantized_value <= 32'sd0) begin
                                output_pixel_1 <= 8'sd0;
                            end else if (shifted_quantized_value > 32'sd127) begin
                                output_pixel_1 <= 8'sd127;
                            end else begin
                                output_pixel_1 <= shifted_quantized_value[7:0];
                            end
                        end
                        2'd2: begin
                            if (shifted_quantized_value <= 32'sd0) begin
                                output_pixel_2 <= 8'sd0;
                            end else if (shifted_quantized_value > 32'sd127) begin
                                output_pixel_2 <= 8'sd127;
                            end else begin
                                output_pixel_2 <= shifted_quantized_value[7:0];
                            end
                        end
                        2'd3: begin
                            if (shifted_quantized_value <= 32'sd0) begin
                                output_pixel_3 <= 8'sd0;
                            end else if (shifted_quantized_value > 32'sd127) begin
                                output_pixel_3 <= 8'sd127;
                            end else begin
                                output_pixel_3 <= shifted_quantized_value[7:0];
                            end
                        end
                        default: begin
                            output_pixel_0 <= 8'sd0;
                        end
                    endcase
                    if (quantize_lane_index < 2'd3) begin
                        quantize_lane_index <= quantize_lane_index + 1'b1;
                        current_state       <= STATE_QUANTIZE_MULTIPLY;
                    end else begin
                        current_state <= STATE_DONE;
                    end
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
