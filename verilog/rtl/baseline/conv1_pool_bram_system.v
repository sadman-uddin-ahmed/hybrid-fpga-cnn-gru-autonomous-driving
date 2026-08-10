`timescale 1ns / 1ps

module conv1_pool_bram_system (
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    start,
    input  wire                    input_memory_write_enable,
    input  wire [13:0]             input_memory_write_address,
    input  wire signed [7:0]       input_memory_write_data,
    input  wire                    weight_memory_write_enable,
    input  wire [8:0]              weight_memory_write_address,
    input  wire signed [7:0]       weight_memory_write_data,
    input  wire                    bias_memory_write_enable,
    input  wire [3:0]              bias_memory_write_address,
    input  wire signed [31:0]      bias_memory_write_data,
    input  wire [13:0]             pooled_output_read_address,
    output reg  signed [7:0]       pooled_output_read_data,
    output reg  [13:0]             pooled_output_write_address_monitor,
    output reg  signed [7:0]       pooled_output_write_data_monitor,
    output reg                     pooled_output_write_enable_monitor,
    output reg                     done
);
    localparam INPUT_TOTAL_VALUES         = 12288;
    localparam WEIGHT_TOTAL_VALUES        = 432;
    localparam BIAS_TOTAL_VALUES          = 16;
    localparam POOLED_OUTPUT_TOTAL_VALUES = 16384;
    localparam signed [63:0] SCALE_MULT_64  = 64'sd1301962;
    localparam integer SCALE_SHIFT = 30;
    localparam STATE_IDLE              = 5'd0;
    localparam STATE_START_POOL_PIXEL  = 5'd1;
    localparam STATE_START_CONV_PIXEL  = 5'd2;
    localparam STATE_MAC_STEP          = 5'd3;
    localparam STATE_UPDATE_MAC_INDEX  = 5'd4;
    localparam STATE_QUANTIZE_MULT     = 5'd5;
    localparam STATE_QUANTIZE_ROUND    = 5'd6;
    localparam STATE_QUANTIZE_SHIFT    = 5'd7;
    localparam STATE_POOL_COMPARE      = 5'd8;
    localparam STATE_NEXT_POOL_MEMBER  = 5'd9;
    localparam STATE_WRITE_POOL_OUTPUT = 5'd10;
    localparam STATE_NEXT_OUTPUT       = 5'd11;
    localparam STATE_DONE              = 5'd12;
    reg [4:0] current_state;
    (* ram_style = "block" *) reg signed [7:0]  input_memory_array [0:INPUT_TOTAL_VALUES-1];
    (* ram_style = "block" *) reg signed [7:0]  weight_memory_array [0:WEIGHT_TOTAL_VALUES-1];
    (* ram_style = "block" *) reg signed [31:0] bias_memory_array [0:BIAS_TOTAL_VALUES-1];
    (* ram_style = "block" *) reg signed [7:0]  pooled_output_memory_array [0:POOLED_OUTPUT_TOTAL_VALUES-1];
    reg [3:0] current_output_channel;
    reg [4:0] current_pool_x;
    reg [4:0] current_pool_y;
    reg [1:0] current_pool_member;
    reg [5:0] current_conv_pixel_x;
    reg [5:0] current_conv_pixel_y;
    reg [1:0] current_input_channel;
    reg [1:0] current_kernel_row;
    reg [1:0] current_kernel_col;
    reg signed [63:0] accumulator;
    reg signed [63:0] quantized_product;
    reg signed [63:0] quantized_rounded_product;
    reg signed [63:0] quantized_shifted_value;
    reg signed [7:0] current_pool_max;
    reg signed [7:0] candidate_conv_value;
    wire signed [7:0] calculated_input_x;
    wire signed [7:0] calculated_input_y;
    wire padding_active;
    wire [31:0] calculated_input_address_wide;
    wire [31:0] calculated_weight_address_wide;
    wire [31:0] calculated_pooled_output_address_wide;
    wire [13:0] calculated_input_address;
    wire [8:0] calculated_weight_address;
    wire [13:0] calculated_pooled_output_address;
    wire signed [63:0] selected_input_value_64;
    wire signed [63:0] selected_weight_value_64;
    wire signed [63:0] current_product_64;
    initial begin
        $display("ACTIVE RTL: conv1_pool_bram_system DIRECT RECOVERY V3 64BIT SIGNED MAC");
    end
    assign calculated_input_x =
        $signed({2'b00, current_conv_pixel_x}) +
        $signed({6'b000000, current_kernel_col}) -
        8'sd1;
    assign calculated_input_y =
        $signed({2'b00, current_conv_pixel_y}) +
        $signed({6'b000000, current_kernel_row}) -
        8'sd1;
    assign padding_active =
        (calculated_input_x < 8'sd0) ||
        (calculated_input_x > 8'sd63) ||
        (calculated_input_y < 8'sd0) ||
        (calculated_input_y > 8'sd63);
    assign calculated_input_address_wide =
        ({30'd0, current_input_channel} * 32'd4096) +
        ({26'd0, calculated_input_y[5:0]} * 32'd64) +
        {26'd0, calculated_input_x[5:0]};
    assign calculated_weight_address_wide =
        ({28'd0, current_output_channel} * 32'd27) +
        ({30'd0, current_input_channel} * 32'd9) +
        ({30'd0, current_kernel_row} * 32'd3) +
        {30'd0, current_kernel_col};
    assign calculated_pooled_output_address_wide =
        ({28'd0, current_output_channel} * 32'd1024) +
        ({27'd0, current_pool_y} * 32'd32) +
        {27'd0, current_pool_x};
    assign calculated_input_address =
        calculated_input_address_wide[13:0];
    assign calculated_weight_address =
        calculated_weight_address_wide[8:0];
    assign calculated_pooled_output_address =
        calculated_pooled_output_address_wide[13:0];
    assign selected_input_value_64 =
        padding_active ?
        64'sd0 :
        {{56{input_memory_array[calculated_input_address][7]}}, input_memory_array[calculated_input_address]};
    assign selected_weight_value_64 =
        {{56{weight_memory_array[calculated_weight_address][7]}}, weight_memory_array[calculated_weight_address]};
    assign current_product_64 =
        selected_input_value_64 * selected_weight_value_64;
    always @(posedge clk) begin
        if (input_memory_write_enable) begin
            input_memory_array[input_memory_write_address] <= input_memory_write_data;
        end
        if (weight_memory_write_enable) begin
            weight_memory_array[weight_memory_write_address] <= weight_memory_write_data;
        end
        if (bias_memory_write_enable) begin
            bias_memory_array[bias_memory_write_address] <= bias_memory_write_data;
        end
        pooled_output_read_data <= pooled_output_memory_array[pooled_output_read_address];
    end
    always @(posedge clk) begin
        if (reset) begin
            current_state <= STATE_IDLE;
            current_output_channel <= 4'd0;
            current_pool_x <= 5'd0;
            current_pool_y <= 5'd0;
            current_pool_member <= 2'd0;
            current_conv_pixel_x <= 6'd0;
            current_conv_pixel_y <= 6'd0;
            current_input_channel <= 2'd0;
            current_kernel_row <= 2'd0;
            current_kernel_col <= 2'd0;
            accumulator <= 64'sd0;
            quantized_product <= 64'sd0;
            quantized_rounded_product <= 64'sd0;
            quantized_shifted_value <= 64'sd0;
            current_pool_max <= 8'sd0;
            candidate_conv_value <= 8'sd0;
            pooled_output_write_address_monitor <= 14'd0;
            pooled_output_write_data_monitor <= 8'sd0;
            pooled_output_write_enable_monitor <= 1'b0;
            done <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    pooled_output_write_enable_monitor <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        current_output_channel <= 4'd0;
                        current_pool_x <= 5'd0;
                        current_pool_y <= 5'd0;
                        current_pool_member <= 2'd0;
                        current_pool_max <= 8'sd0;
                        candidate_conv_value <= 8'sd0;
                        current_state <= STATE_START_POOL_PIXEL;
                    end
                end
                STATE_START_POOL_PIXEL: begin
                    pooled_output_write_enable_monitor <= 1'b0;
                    current_pool_member <= 2'd0;
                    current_pool_max <= 8'sd0;
                    candidate_conv_value <= 8'sd0;
                    current_state <= STATE_START_CONV_PIXEL;
                end
                STATE_START_CONV_PIXEL: begin
                    current_conv_pixel_x <= {current_pool_x, 1'b0} + {5'd0, current_pool_member[0]};
                    current_conv_pixel_y <= {current_pool_y, 1'b0} + {5'd0, current_pool_member[1]};
                    current_input_channel <= 2'd0;
                    current_kernel_row <= 2'd0;
                    current_kernel_col <= 2'd0;
                    accumulator <= {{32{bias_memory_array[current_output_channel][31]}}, bias_memory_array[current_output_channel]};
                    current_state <= STATE_MAC_STEP;
                end
                STATE_MAC_STEP: begin
                    accumulator <= accumulator + current_product_64;
                    current_state <= STATE_UPDATE_MAC_INDEX;
                end
                STATE_UPDATE_MAC_INDEX: begin
                    if (current_kernel_col < 2'd2) begin
                        current_kernel_col <= current_kernel_col + 2'd1;
                        current_state <= STATE_MAC_STEP;
                    end else begin
                        current_kernel_col <= 2'd0;
                        if (current_kernel_row < 2'd2) begin
                            current_kernel_row <= current_kernel_row + 2'd1;
                            current_state <= STATE_MAC_STEP;
                        end else begin
                            current_kernel_row <= 2'd0;
                            if (current_input_channel < 2'd2) begin
                                current_input_channel <= current_input_channel + 2'd1;
                                current_state <= STATE_MAC_STEP;
                            end else begin
                                current_input_channel <= 2'd0;
                                current_state <= STATE_QUANTIZE_MULT;
                            end
                        end
                    end
                end
                STATE_QUANTIZE_MULT: begin
                    quantized_product <= accumulator * SCALE_MULT_64;
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
                    current_state <= STATE_POOL_COMPARE;
                end
                STATE_POOL_COMPARE: begin
                    if (quantized_shifted_value <= 64'sd0) begin
                        candidate_conv_value <= 8'sd0;
                    end else if (quantized_shifted_value > 64'sd127) begin
                        candidate_conv_value <= 8'sd127;
                    end else begin
                        candidate_conv_value <= quantized_shifted_value[7:0];
                    end
                    if (current_pool_member == 2'd0) begin
                        if (quantized_shifted_value <= 64'sd0) begin
                            current_pool_max <= 8'sd0;
                        end else if (quantized_shifted_value > 64'sd127) begin
                            current_pool_max <= 8'sd127;
                        end else begin
                            current_pool_max <= quantized_shifted_value[7:0];
                        end
                    end else begin
                        if (quantized_shifted_value <= 64'sd0) begin
                            current_pool_max <= current_pool_max;
                        end else if (quantized_shifted_value > 64'sd127) begin
                            current_pool_max <= 8'sd127;
                        end else if ($signed(quantized_shifted_value[7:0]) > current_pool_max) begin
                            current_pool_max <= quantized_shifted_value[7:0];
                        end
                    end
                    current_state <= STATE_NEXT_POOL_MEMBER;
                end
                STATE_NEXT_POOL_MEMBER: begin
                    if (current_pool_member < 2'd3) begin
                        current_pool_member <= current_pool_member + 2'd1;
                        current_state <= STATE_START_CONV_PIXEL;
                    end else begin
                        current_state <= STATE_WRITE_POOL_OUTPUT;
                    end
                end
                STATE_WRITE_POOL_OUTPUT: begin
                    pooled_output_memory_array[calculated_pooled_output_address] <= current_pool_max;
                    pooled_output_write_address_monitor <= calculated_pooled_output_address;
                    pooled_output_write_data_monitor <= current_pool_max;
                    pooled_output_write_enable_monitor <= 1'b1;
                    current_state <= STATE_NEXT_OUTPUT;
                end
                STATE_NEXT_OUTPUT: begin
                    pooled_output_write_enable_monitor <= 1'b0;
                    if (current_pool_x < 5'd31) begin
                        current_pool_x <= current_pool_x + 5'd1;
                        current_state <= STATE_START_POOL_PIXEL;
                    end else begin
                        current_pool_x <= 5'd0;
                        if (current_pool_y < 5'd31) begin
                            current_pool_y <= current_pool_y + 5'd1;
                            current_state <= STATE_START_POOL_PIXEL;
                        end else begin
                            current_pool_y <= 5'd0;
                            if (current_output_channel < 4'd15) begin
                                current_output_channel <= current_output_channel + 4'd1;
                                current_state <= STATE_START_POOL_PIXEL;
                            end else begin
                                current_output_channel <= 4'd0;
                                current_state <= STATE_DONE;
                            end
                        end
                    end
                end
                STATE_DONE: begin
                    pooled_output_write_enable_monitor <= 1'b0;
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