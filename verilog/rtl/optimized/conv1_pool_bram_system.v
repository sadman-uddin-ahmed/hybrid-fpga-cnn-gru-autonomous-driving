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
    localparam WEIGHT_VALUES_PER_CHANNEL  = 27;
    localparam WEIGHT_BANK_TOTAL_VALUES   = 108;
    localparam BIAS_TOTAL_VALUES          = 16;
    localparam BIAS_BANK_TOTAL_VALUES     = 4;
    localparam POOLED_OUTPUT_TOTAL_VALUES = 16384;

    localparam signed [63:0] SCALE_MULT_64 = 64'sd1301962;
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
    // Shared Conv1 input storage and unchanged pooled-output storage.
    (* ram_style = "block" *)
    reg signed [7:0] input_memory_array [0:INPUT_TOTAL_VALUES-1];
    // Four output-channel weight banks. Each bank stores one lane from every four-channel group: OC 0/4/8/12, OC 1/5/9/13, etc.
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_memory_bank_0 [0:WEIGHT_BANK_TOTAL_VALUES-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_memory_bank_1 [0:WEIGHT_BANK_TOTAL_VALUES-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_memory_bank_2 [0:WEIGHT_BANK_TOTAL_VALUES-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_memory_bank_3 [0:WEIGHT_BANK_TOTAL_VALUES-1];
    // Four matching bias banks.
    (* ram_style = "distributed" *)
    reg signed [31:0] bias_memory_bank_0 [0:BIAS_BANK_TOTAL_VALUES-1];
    (* ram_style = "distributed" *)
    reg signed [31:0] bias_memory_bank_1 [0:BIAS_BANK_TOTAL_VALUES-1];
    (* ram_style = "distributed" *)
    reg signed [31:0] bias_memory_bank_2 [0:BIAS_BANK_TOTAL_VALUES-1];
    (* ram_style = "distributed" *)
    reg signed [31:0] bias_memory_bank_3 [0:BIAS_BANK_TOTAL_VALUES-1];
    (* ram_style = "block" *)
    reg signed [7:0] pooled_output_memory_array [0:POOLED_OUTPUT_TOTAL_VALUES-1];
    // Four-lane output-channel group control.
    reg [1:0] current_output_group;
    reg [1:0] current_quant_lane;
    reg [1:0] current_write_lane;
    reg [4:0] current_pool_x;
    reg [4:0] current_pool_y;
    reg [1:0] current_pool_member;
    reg [5:0] current_conv_pixel_x;
    reg [5:0] current_conv_pixel_y;
    reg [1:0] current_input_channel;
    reg [1:0] current_kernel_row;
    reg [1:0] current_kernel_col;
    // Independent lane accumulators preserve the original sequential 27-term accumulation order for each output channel.
    reg signed [63:0] accumulator_0;
    reg signed [63:0] accumulator_1;
    reg signed [63:0] accumulator_2;
    reg signed [63:0] accumulator_3;
    // Four parallel registered W8A8 products.
    (* use_dsp = "yes" *) reg signed [15:0] mac_product_reg_0;
    (* use_dsp = "yes" *) reg signed [15:0] mac_product_reg_1;
    (* use_dsp = "yes" *) reg signed [15:0] mac_product_reg_2;
    (* use_dsp = "yes" *) reg signed [15:0] mac_product_reg_3;
    // Shared requantisation datapath, used serially across the four lanes.
    reg signed [63:0] quantized_product;
    reg signed [63:0] quantized_rounded_product;
    reg signed [63:0] quantized_shifted_value;
    reg signed [7:0] current_pool_max_0;
    reg signed [7:0] current_pool_max_1;
    reg signed [7:0] current_pool_max_2;
    reg signed [7:0] current_pool_max_3;
    reg signed [7:0] candidate_conv_value;
    wire signed [7:0] calculated_input_x;
    wire signed [7:0] calculated_input_y;
    wire padding_active;
    wire [31:0] calculated_input_address_wide;
    wire [31:0] calculated_weight_bank_address_wide;
    wire [31:0] calculated_pooled_output_address_wide;
    wire [13:0] calculated_input_address;
    wire [6:0]  calculated_weight_bank_address;
    wire [13:0] calculated_pooled_output_address;
    wire signed [7:0] selected_input_value_8;
    wire signed [7:0] selected_weight_value_0;
    wire signed [7:0] selected_weight_value_1;
    wire signed [7:0] selected_weight_value_2;
    wire signed [7:0] selected_weight_value_3;
    wire signed [63:0] selected_accumulator;
    wire signed [7:0] selected_pool_max;
    // Flat external Conv1 parameter addressing is preserved. Writes are decoded into four physical banks internally.
    wire [3:0] weight_write_output_channel;
    wire [4:0] weight_write_term_address;
    wire [1:0] weight_write_bank_select;
    wire [1:0] weight_write_channel_group;
    wire [6:0] weight_write_bank_address;
    wire [1:0] bias_write_bank_select;
    wire [1:0] bias_write_bank_address;
    initial begin
        $display("ACTIVE RTL: conv1_pool_bram_system FOUR-LANE OUTPUT-CHANNEL PARALLEL V5");
    end
    assign weight_write_output_channel =
        weight_memory_write_address / WEIGHT_VALUES_PER_CHANNEL;
    assign weight_write_term_address =
        weight_memory_write_address % WEIGHT_VALUES_PER_CHANNEL;
    assign weight_write_bank_select =
        weight_write_output_channel[1:0];
    assign weight_write_channel_group =
        weight_write_output_channel[3:2];
    assign weight_write_bank_address =
        (weight_write_channel_group * WEIGHT_VALUES_PER_CHANNEL) +
        weight_write_term_address;
    assign bias_write_bank_select = bias_memory_write_address[1:0];
    assign bias_write_bank_address = bias_memory_write_address[3:2];
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
    assign calculated_weight_bank_address_wide =
        ({30'd0, current_output_group} * 32'd27) +
        ({30'd0, current_input_channel} * 32'd9) +
        ({30'd0, current_kernel_row} * 32'd3) +
        {30'd0, current_kernel_col};
    assign calculated_pooled_output_address_wide =
        ({28'd0, {current_output_group, current_write_lane}} * 32'd1024) +
        ({27'd0, current_pool_y} * 32'd32) +
        {27'd0, current_pool_x};
    assign calculated_input_address =
        calculated_input_address_wide[13:0];
    assign calculated_weight_bank_address =
        calculated_weight_bank_address_wide[6:0];
    assign calculated_pooled_output_address =
        calculated_pooled_output_address_wide[13:0];
    assign selected_input_value_8 =
        padding_active ?
        8'sd0 :
        input_memory_array[calculated_input_address];
    assign selected_weight_value_0 =
        weight_memory_bank_0[calculated_weight_bank_address];
    assign selected_weight_value_1 =
        weight_memory_bank_1[calculated_weight_bank_address];
    assign selected_weight_value_2 =
        weight_memory_bank_2[calculated_weight_bank_address];
    assign selected_weight_value_3 =
        weight_memory_bank_3[calculated_weight_bank_address];
    assign selected_accumulator =
        (current_quant_lane == 2'd0) ? accumulator_0 :
        (current_quant_lane == 2'd1) ? accumulator_1 :
        (current_quant_lane == 2'd2) ? accumulator_2 :
                                        accumulator_3;
    assign selected_pool_max =
        (current_write_lane == 2'd0) ? current_pool_max_0 :
        (current_write_lane == 2'd1) ? current_pool_max_1 :
        (current_write_lane == 2'd2) ? current_pool_max_2 :
                                       current_pool_max_3;
    // Parameter loading and pooled-output read port.
    always @(posedge clk) begin
        if (input_memory_write_enable) begin
            input_memory_array[input_memory_write_address] <=
                input_memory_write_data;
        end
        if (
            weight_memory_write_enable &&
            (weight_write_bank_select == 2'd0)
        ) begin
            weight_memory_bank_0[weight_write_bank_address] <=
                weight_memory_write_data;
        end
        if (
            weight_memory_write_enable &&
            (weight_write_bank_select == 2'd1)
        ) begin
            weight_memory_bank_1[weight_write_bank_address] <=
                weight_memory_write_data;
        end
        if (
            weight_memory_write_enable &&
            (weight_write_bank_select == 2'd2)
        ) begin
            weight_memory_bank_2[weight_write_bank_address] <=
                weight_memory_write_data;
        end
        if (
            weight_memory_write_enable &&
            (weight_write_bank_select == 2'd3)
        ) begin
            weight_memory_bank_3[weight_write_bank_address] <=
                weight_memory_write_data;
        end
        if (
            bias_memory_write_enable &&
            (bias_write_bank_select == 2'd0)
        ) begin
            bias_memory_bank_0[bias_write_bank_address] <=
                bias_memory_write_data;
        end
        if (
            bias_memory_write_enable &&
            (bias_write_bank_select == 2'd1)
        ) begin
            bias_memory_bank_1[bias_write_bank_address] <=
                bias_memory_write_data;
        end
        if (
            bias_memory_write_enable &&
            (bias_write_bank_select == 2'd2)
        ) begin
            bias_memory_bank_2[bias_write_bank_address] <=
                bias_memory_write_data;
        end
        if (
            bias_memory_write_enable &&
            (bias_write_bank_select == 2'd3)
        ) begin
            bias_memory_bank_3[bias_write_bank_address] <=
                bias_memory_write_data;
        end

        pooled_output_read_data <=
            pooled_output_memory_array[pooled_output_read_address];
    end
    always @(posedge clk) begin
        if (reset) begin
            current_state <= STATE_IDLE;
            current_output_group <= 2'd0;
            current_quant_lane <= 2'd0;
            current_write_lane <= 2'd0;
            current_pool_x <= 5'd0;
            current_pool_y <= 5'd0;
            current_pool_member <= 2'd0;
            current_conv_pixel_x <= 6'd0;
            current_conv_pixel_y <= 6'd0;
            current_input_channel <= 2'd0;
            current_kernel_row <= 2'd0;
            current_kernel_col <= 2'd0;
            accumulator_0 <= 64'sd0;
            accumulator_1 <= 64'sd0;
            accumulator_2 <= 64'sd0;
            accumulator_3 <= 64'sd0;
            mac_product_reg_0 <= 16'sd0;
            mac_product_reg_1 <= 16'sd0;
            mac_product_reg_2 <= 16'sd0;
            mac_product_reg_3 <= 16'sd0;
            quantized_product <= 64'sd0;
            quantized_rounded_product <= 64'sd0;
            quantized_shifted_value <= 64'sd0;
            current_pool_max_0 <= 8'sd0;
            current_pool_max_1 <= 8'sd0;
            current_pool_max_2 <= 8'sd0;
            current_pool_max_3 <= 8'sd0;
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
                        current_output_group <= 2'd0;
                        current_quant_lane <= 2'd0;
                        current_write_lane <= 2'd0;
                        current_pool_x <= 5'd0;
                        current_pool_y <= 5'd0;
                        current_pool_member <= 2'd0;
                        current_pool_max_0 <= 8'sd0;
                        current_pool_max_1 <= 8'sd0;
                        current_pool_max_2 <= 8'sd0;
                        current_pool_max_3 <= 8'sd0;
                        candidate_conv_value <= 8'sd0;
                        current_state <= STATE_START_POOL_PIXEL;
                    end
                end
                STATE_START_POOL_PIXEL: begin
                    pooled_output_write_enable_monitor <= 1'b0;
                    current_pool_member <= 2'd0;
                    current_quant_lane <= 2'd0;
                    current_write_lane <= 2'd0;
                    current_pool_max_0 <= 8'sd0;
                    current_pool_max_1 <= 8'sd0;
                    current_pool_max_2 <= 8'sd0;
                    current_pool_max_3 <= 8'sd0;
                    candidate_conv_value <= 8'sd0;
                    current_state <= STATE_START_CONV_PIXEL;
                end
                STATE_START_CONV_PIXEL: begin
                    current_conv_pixel_x <=
                        {current_pool_x, 1'b0} +
                        {5'd0, current_pool_member[0]};
                    current_conv_pixel_y <=
                        {current_pool_y, 1'b0} +
                        {5'd0, current_pool_member[1]};
                    current_input_channel <= 2'd0;
                    current_kernel_row <= 2'd0;
                    current_kernel_col <= 2'd0;
                    current_quant_lane <= 2'd0;
                    accumulator_0 <=
                        {{32{bias_memory_bank_0[current_output_group][31]}},
                          bias_memory_bank_0[current_output_group]};
                    accumulator_1 <=
                        {{32{bias_memory_bank_1[current_output_group][31]}},
                          bias_memory_bank_1[current_output_group]};
                    accumulator_2 <=
                        {{32{bias_memory_bank_2[current_output_group][31]}},
                          bias_memory_bank_2[current_output_group]};
                    accumulator_3 <=
                        {{32{bias_memory_bank_3[current_output_group][31]}},
                          bias_memory_bank_3[current_output_group]};

                    current_state <= STATE_MAC_STEP;
                end
                STATE_MAC_STEP: begin
                    mac_product_reg_0 <=
                        $signed(selected_input_value_8) *
                        $signed(selected_weight_value_0);
                    mac_product_reg_1 <=
                        $signed(selected_input_value_8) *
                        $signed(selected_weight_value_1);
                    mac_product_reg_2 <=
                        $signed(selected_input_value_8) *
                        $signed(selected_weight_value_2);
                    mac_product_reg_3 <=
                        $signed(selected_input_value_8) *
                        $signed(selected_weight_value_3);
                    current_state <= STATE_UPDATE_MAC_INDEX;
                end
                STATE_UPDATE_MAC_INDEX: begin
                    accumulator_0 <= accumulator_0 +
                        {{48{mac_product_reg_0[15]}}, mac_product_reg_0};
                    accumulator_1 <= accumulator_1 +
                        {{48{mac_product_reg_1[15]}}, mac_product_reg_1};
                    accumulator_2 <= accumulator_2 +
                        {{48{mac_product_reg_2[15]}}, mac_product_reg_2};
                    accumulator_3 <= accumulator_3 +
                        {{48{mac_product_reg_3[15]}}, mac_product_reg_3};
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
                                current_input_channel <=
                                    current_input_channel + 2'd1;
                                current_state <= STATE_MAC_STEP;
                            end else begin
                                current_input_channel <= 2'd0;
                                current_quant_lane <= 2'd0;
                                current_state <= STATE_QUANTIZE_MULT;
                            end
                        end
                    end
                end
                STATE_QUANTIZE_MULT: begin
                    quantized_product <=
                        selected_accumulator * SCALE_MULT_64;
                    current_state <= STATE_QUANTIZE_ROUND;
                end
                STATE_QUANTIZE_ROUND: begin
                    if (quantized_product > 64'sd0) begin
                        quantized_rounded_product <=
                            quantized_product +
                            (64'sd1 <<< (SCALE_SHIFT - 1));
                    end else begin
                        quantized_rounded_product <=
                            quantized_product;
                    end
                    current_state <= STATE_QUANTIZE_SHIFT;
                end
                STATE_QUANTIZE_SHIFT: begin
                    quantized_shifted_value <=
                        quantized_rounded_product >>> SCALE_SHIFT;
                    current_state <= STATE_POOL_COMPARE;
                end
                STATE_POOL_COMPARE: begin
                    if (quantized_shifted_value <= 64'sd0) begin
                        candidate_conv_value <= 8'sd0;
                    end else if (quantized_shifted_value > 64'sd127) begin
                        candidate_conv_value <= 8'sd127;
                    end else begin
                        candidate_conv_value <=
                            quantized_shifted_value[7:0];
                    end
                    case (current_quant_lane)
                        2'd0: begin
                            if (current_pool_member == 2'd0) begin
                                if (quantized_shifted_value <= 64'sd0) begin
                                    current_pool_max_0 <= 8'sd0;
                                end else if (quantized_shifted_value > 64'sd127) begin
                                    current_pool_max_0 <= 8'sd127;
                                end else begin
                                    current_pool_max_0 <=
                                        quantized_shifted_value[7:0];
                                end
                            end else begin
                                if (quantized_shifted_value <= 64'sd0) begin
                                    current_pool_max_0 <= current_pool_max_0;
                                end else if (quantized_shifted_value > 64'sd127) begin
                                    current_pool_max_0 <= 8'sd127;
                                end else if (
                                    $signed(quantized_shifted_value[7:0]) >
                                    current_pool_max_0
                                ) begin
                                    current_pool_max_0 <=
                                        quantized_shifted_value[7:0];
                                end
                            end
                        end
                        2'd1: begin
                            if (current_pool_member == 2'd0) begin
                                if (quantized_shifted_value <= 64'sd0) begin
                                    current_pool_max_1 <= 8'sd0;
                                end else if (quantized_shifted_value > 64'sd127) begin
                                    current_pool_max_1 <= 8'sd127;
                                end else begin
                                    current_pool_max_1 <=
                                        quantized_shifted_value[7:0];
                                end
                            end else begin
                                if (quantized_shifted_value <= 64'sd0) begin
                                    current_pool_max_1 <= current_pool_max_1;
                                end else if (quantized_shifted_value > 64'sd127) begin
                                    current_pool_max_1 <= 8'sd127;
                                end else if (
                                    $signed(quantized_shifted_value[7:0]) >
                                    current_pool_max_1
                                ) begin
                                    current_pool_max_1 <=
                                        quantized_shifted_value[7:0];
                                end
                            end
                        end
                        2'd2: begin
                            if (current_pool_member == 2'd0) begin
                                if (quantized_shifted_value <= 64'sd0) begin
                                    current_pool_max_2 <= 8'sd0;
                                end else if (quantized_shifted_value > 64'sd127) begin
                                    current_pool_max_2 <= 8'sd127;
                                end else begin
                                    current_pool_max_2 <=
                                        quantized_shifted_value[7:0];
                                end
                            end else begin
                                if (quantized_shifted_value <= 64'sd0) begin
                                    current_pool_max_2 <= current_pool_max_2;
                                end else if (quantized_shifted_value > 64'sd127) begin
                                    current_pool_max_2 <= 8'sd127;
                                end else if (
                                    $signed(quantized_shifted_value[7:0]) >
                                    current_pool_max_2
                                ) begin
                                    current_pool_max_2 <=
                                        quantized_shifted_value[7:0];
                                end
                            end
                        end
                        default: begin
                            if (current_pool_member == 2'd0) begin
                                if (quantized_shifted_value <= 64'sd0) begin
                                    current_pool_max_3 <= 8'sd0;
                                end else if (quantized_shifted_value > 64'sd127) begin
                                    current_pool_max_3 <= 8'sd127;
                                end else begin
                                    current_pool_max_3 <=
                                        quantized_shifted_value[7:0];
                                end
                            end else begin
                                if (quantized_shifted_value <= 64'sd0) begin
                                    current_pool_max_3 <= current_pool_max_3;
                                end else if (quantized_shifted_value > 64'sd127) begin
                                    current_pool_max_3 <= 8'sd127;
                                end else if (
                                    $signed(quantized_shifted_value[7:0]) >
                                    current_pool_max_3
                                ) begin
                                    current_pool_max_3 <=
                                        quantized_shifted_value[7:0];
                                end
                            end
                        end
                    endcase
                    if (current_quant_lane < 2'd3) begin
                        current_quant_lane <= current_quant_lane + 2'd1;
                        current_state <= STATE_QUANTIZE_MULT;
                    end else begin
                        current_quant_lane <= 2'd0;
                        current_state <= STATE_NEXT_POOL_MEMBER;
                    end
                end
                STATE_NEXT_POOL_MEMBER: begin
                    if (current_pool_member < 2'd3) begin
                        current_pool_member <= current_pool_member + 2'd1;
                        current_state <= STATE_START_CONV_PIXEL;
                    end else begin
                        current_write_lane <= 2'd0;
                        current_state <= STATE_WRITE_POOL_OUTPUT;
                    end
                end
                STATE_WRITE_POOL_OUTPUT: begin
                    pooled_output_memory_array[calculated_pooled_output_address] <=
                        selected_pool_max;
                    pooled_output_write_address_monitor <=
                        calculated_pooled_output_address;
                    pooled_output_write_data_monitor <=
                        selected_pool_max;
                    pooled_output_write_enable_monitor <= 1'b1;

                    if (current_write_lane < 2'd3) begin
                        current_write_lane <= current_write_lane + 2'd1;
                        current_state <= STATE_WRITE_POOL_OUTPUT;
                    end else begin
                        current_write_lane <= 2'd0;
                        current_state <= STATE_NEXT_OUTPUT;
                    end
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
                            if (current_output_group < 2'd3) begin
                                current_output_group <=
                                    current_output_group + 2'd1;
                                current_state <= STATE_START_POOL_PIXEL;
                            end else begin
                                current_output_group <= 2'd0;
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
