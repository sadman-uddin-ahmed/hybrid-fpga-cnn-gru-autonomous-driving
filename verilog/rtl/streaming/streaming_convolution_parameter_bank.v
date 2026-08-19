`timescale 1ns / 1ps

module streaming_convolution_parameter_bank #(
    parameter integer INPUT_CHANNELS  = 3,
    parameter integer OUTPUT_CHANNELS = 16
)(
    input  wire                    clk,
    input  wire                    weight_memory_write_enable,
    input  wire [12:0]             weight_memory_write_address,
    input  wire signed [7:0]       weight_memory_write_data,
    input  wire                    bias_memory_write_enable,
    input  wire [5:0]              bias_memory_write_address,
    input  wire signed [31:0]      bias_memory_write_data,
    input  wire [7:0]              output_group_index,
    input  wire [7:0]              input_channel_index,
    output wire signed [7:0]       weight_lane_0_value_0,
    output wire signed [7:0]       weight_lane_0_value_1,
    output wire signed [7:0]       weight_lane_0_value_2,
    output wire signed [7:0]       weight_lane_0_value_3,
    output wire signed [7:0]       weight_lane_0_value_4,
    output wire signed [7:0]       weight_lane_0_value_5,
    output wire signed [7:0]       weight_lane_0_value_6,
    output wire signed [7:0]       weight_lane_0_value_7,
    output wire signed [7:0]       weight_lane_0_value_8,
    output wire signed [7:0]       weight_lane_1_value_0,
    output wire signed [7:0]       weight_lane_1_value_1,
    output wire signed [7:0]       weight_lane_1_value_2,
    output wire signed [7:0]       weight_lane_1_value_3,
    output wire signed [7:0]       weight_lane_1_value_4,
    output wire signed [7:0]       weight_lane_1_value_5,
    output wire signed [7:0]       weight_lane_1_value_6,
    output wire signed [7:0]       weight_lane_1_value_7,
    output wire signed [7:0]       weight_lane_1_value_8,
    output wire signed [7:0]       weight_lane_2_value_0,
    output wire signed [7:0]       weight_lane_2_value_1,
    output wire signed [7:0]       weight_lane_2_value_2,
    output wire signed [7:0]       weight_lane_2_value_3,
    output wire signed [7:0]       weight_lane_2_value_4,
    output wire signed [7:0]       weight_lane_2_value_5,
    output wire signed [7:0]       weight_lane_2_value_6,
    output wire signed [7:0]       weight_lane_2_value_7,
    output wire signed [7:0]       weight_lane_2_value_8,
    output wire signed [7:0]       weight_lane_3_value_0,
    output wire signed [7:0]       weight_lane_3_value_1,
    output wire signed [7:0]       weight_lane_3_value_2,
    output wire signed [7:0]       weight_lane_3_value_3,
    output wire signed [7:0]       weight_lane_3_value_4,
    output wire signed [7:0]       weight_lane_3_value_5,
    output wire signed [7:0]       weight_lane_3_value_6,
    output wire signed [7:0]       weight_lane_3_value_7,
    output wire signed [7:0]       weight_lane_3_value_8,
    output wire signed [31:0]      bias_value_0,
    output wire signed [31:0]      bias_value_1,
    output wire signed [31:0]      bias_value_2,
    output wire signed [31:0]      bias_value_3
);
    localparam integer OUTPUT_GROUPS = OUTPUT_CHANNELS / 4;
    localparam integer WEIGHTS_PER_OUTPUT_CHANNEL = INPUT_CHANNELS * 9;
    localparam integer WEIGHT_TOTAL_VALUES =
        OUTPUT_CHANNELS * WEIGHTS_PER_OUTPUT_CHANNEL;
    localparam integer BANK_DEPTH =
        OUTPUT_GROUPS * INPUT_CHANNELS;
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_0_0 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_0_1 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_0_2 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_0_3 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_0_4 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_0_5 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_0_6 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_0_7 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_0_8 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_1_0 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_1_1 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_1_2 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_1_3 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_1_4 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_1_5 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_1_6 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_1_7 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_1_8 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_2_0 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_2_1 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_2_2 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_2_3 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_2_4 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_2_5 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_2_6 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_2_7 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_2_8 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_3_0 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_3_1 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_3_2 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_3_3 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_3_4 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_3_5 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_3_6 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_3_7 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] weight_bank_3_8 [0:BANK_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [31:0] bias_bank_0 [0:OUTPUT_GROUPS-1];
    (* ram_style = "distributed" *)
    reg signed [31:0] bias_bank_1 [0:OUTPUT_GROUPS-1];
    (* ram_style = "distributed" *)
    reg signed [31:0] bias_bank_2 [0:OUTPUT_GROUPS-1];
    (* ram_style = "distributed" *)
    reg signed [31:0] bias_bank_3 [0:OUTPUT_GROUPS-1];
    wire [7:0]  weight_write_output_channel;
    wire [12:0] weight_write_term_address;
    wire [7:0]  weight_write_input_channel;
    wire [3:0]  weight_write_tap_index;
    wire [1:0]  weight_write_lane_select;
    wire [7:0]  weight_write_group_index;
    wire [15:0] weight_write_bank_address_wide;
    wire [15:0] selected_bank_address_wide;
    wire [1:0]  bias_write_lane_select;
    wire [7:0]  bias_write_group_index;
    initial begin
        $display("ACTIVE RTL: streaming_convolution_parameter_bank FOUR-LANE K9 V1");
    end
    assign weight_write_output_channel =
        weight_memory_write_address /
        WEIGHTS_PER_OUTPUT_CHANNEL;
    assign weight_write_term_address =
        weight_memory_write_address %
        WEIGHTS_PER_OUTPUT_CHANNEL;
    assign weight_write_input_channel =
        weight_write_term_address / 9;
    assign weight_write_tap_index =
        weight_write_term_address % 9;
    assign weight_write_lane_select =
        weight_write_output_channel[1:0];
    assign weight_write_group_index =
        weight_write_output_channel >> 2;
    assign weight_write_bank_address_wide =
        (weight_write_group_index * INPUT_CHANNELS) +
        weight_write_input_channel;
    assign bias_write_lane_select =
        bias_memory_write_address[1:0];
    assign bias_write_group_index =
        bias_memory_write_address >> 2;
    assign selected_bank_address_wide =
        (output_group_index * INPUT_CHANNELS) +
        input_channel_index;
    assign weight_lane_0_value_0 =
        weight_bank_0_0[
            selected_bank_address_wide
        ];
    assign weight_lane_0_value_1 =
        weight_bank_0_1[
            selected_bank_address_wide
        ];
    assign weight_lane_0_value_2 =
        weight_bank_0_2[
            selected_bank_address_wide
        ];
    assign weight_lane_0_value_3 =
        weight_bank_0_3[
            selected_bank_address_wide
        ];
    assign weight_lane_0_value_4 =
        weight_bank_0_4[
            selected_bank_address_wide
        ];
    assign weight_lane_0_value_5 =
        weight_bank_0_5[
            selected_bank_address_wide
        ];
    assign weight_lane_0_value_6 =
        weight_bank_0_6[
            selected_bank_address_wide
        ];
    assign weight_lane_0_value_7 =
        weight_bank_0_7[
            selected_bank_address_wide
        ];
    assign weight_lane_0_value_8 =
        weight_bank_0_8[
            selected_bank_address_wide
        ];
    assign weight_lane_1_value_0 =
        weight_bank_1_0[
            selected_bank_address_wide
        ];
    assign weight_lane_1_value_1 =
        weight_bank_1_1[
            selected_bank_address_wide
        ];
    assign weight_lane_1_value_2 =
        weight_bank_1_2[
            selected_bank_address_wide
        ];
    assign weight_lane_1_value_3 =
        weight_bank_1_3[
            selected_bank_address_wide
        ];
    assign weight_lane_1_value_4 =
        weight_bank_1_4[
            selected_bank_address_wide
        ];
    assign weight_lane_1_value_5 =
        weight_bank_1_5[
            selected_bank_address_wide
        ];
    assign weight_lane_1_value_6 =
        weight_bank_1_6[
            selected_bank_address_wide
        ];
    assign weight_lane_1_value_7 =
        weight_bank_1_7[
            selected_bank_address_wide
        ];
    assign weight_lane_1_value_8 =
        weight_bank_1_8[
            selected_bank_address_wide
        ];
    assign weight_lane_2_value_0 =
        weight_bank_2_0[
            selected_bank_address_wide
        ];
    assign weight_lane_2_value_1 =
        weight_bank_2_1[
            selected_bank_address_wide
        ];
    assign weight_lane_2_value_2 =
        weight_bank_2_2[
            selected_bank_address_wide
        ];
    assign weight_lane_2_value_3 =
        weight_bank_2_3[
            selected_bank_address_wide
        ];
    assign weight_lane_2_value_4 =
        weight_bank_2_4[
            selected_bank_address_wide
        ];
    assign weight_lane_2_value_5 =
        weight_bank_2_5[
            selected_bank_address_wide
        ];
    assign weight_lane_2_value_6 =
        weight_bank_2_6[
            selected_bank_address_wide
        ];
    assign weight_lane_2_value_7 =
        weight_bank_2_7[
            selected_bank_address_wide
        ];
    assign weight_lane_2_value_8 =
        weight_bank_2_8[
            selected_bank_address_wide
        ];
    assign weight_lane_3_value_0 =
        weight_bank_3_0[
            selected_bank_address_wide
        ];
    assign weight_lane_3_value_1 =
        weight_bank_3_1[
            selected_bank_address_wide
        ];
    assign weight_lane_3_value_2 =
        weight_bank_3_2[
            selected_bank_address_wide
        ];
    assign weight_lane_3_value_3 =
        weight_bank_3_3[
            selected_bank_address_wide
        ];
    assign weight_lane_3_value_4 =
        weight_bank_3_4[
            selected_bank_address_wide
        ];
    assign weight_lane_3_value_5 =
        weight_bank_3_5[
            selected_bank_address_wide
        ];
    assign weight_lane_3_value_6 =
        weight_bank_3_6[
            selected_bank_address_wide
        ];
    assign weight_lane_3_value_7 =
        weight_bank_3_7[
            selected_bank_address_wide
        ];
    assign weight_lane_3_value_8 =
        weight_bank_3_8[
            selected_bank_address_wide
        ];
    assign bias_value_0 =
        bias_bank_0[
            output_group_index
        ];
    assign bias_value_1 =
        bias_bank_1[
            output_group_index
        ];
    assign bias_value_2 =
        bias_bank_2[
            output_group_index
        ];
    assign bias_value_3 =
        bias_bank_3[
            output_group_index
        ];
    always @(posedge clk) begin
        if (
            weight_memory_write_enable &&
            (weight_memory_write_address < WEIGHT_TOTAL_VALUES)
        ) begin
            case (weight_write_lane_select)
                2'd0: begin
                    case (weight_write_tap_index)
                        4'd0:
                            weight_bank_0_0[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd1:
                            weight_bank_0_1[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd2:
                            weight_bank_0_2[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd3:
                            weight_bank_0_3[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd4:
                            weight_bank_0_4[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd5:
                            weight_bank_0_5[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd6:
                            weight_bank_0_6[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd7:
                            weight_bank_0_7[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd8:
                            weight_bank_0_8[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        default: begin
                        end
                    endcase
                end
                2'd1: begin
                    case (weight_write_tap_index)
                        4'd0:
                            weight_bank_1_0[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd1:
                            weight_bank_1_1[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd2:
                            weight_bank_1_2[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd3:
                            weight_bank_1_3[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd4:
                            weight_bank_1_4[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd5:
                            weight_bank_1_5[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd6:
                            weight_bank_1_6[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd7:
                            weight_bank_1_7[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd8:
                            weight_bank_1_8[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        default: begin
                        end
                    endcase
                end
                2'd2: begin
                    case (weight_write_tap_index)
                        4'd0:
                            weight_bank_2_0[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd1:
                            weight_bank_2_1[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd2:
                            weight_bank_2_2[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd3:
                            weight_bank_2_3[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd4:
                            weight_bank_2_4[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd5:
                            weight_bank_2_5[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd6:
                            weight_bank_2_6[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd7:
                            weight_bank_2_7[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd8:
                            weight_bank_2_8[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        default: begin
                        end
                    endcase
                end
                2'd3: begin
                    case (weight_write_tap_index)
                        4'd0:
                            weight_bank_3_0[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd1:
                            weight_bank_3_1[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd2:
                            weight_bank_3_2[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd3:
                            weight_bank_3_3[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd4:
                            weight_bank_3_4[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd5:
                            weight_bank_3_5[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd6:
                            weight_bank_3_6[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd7:
                            weight_bank_3_7[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        4'd8:
                            weight_bank_3_8[
                                weight_write_bank_address_wide
                            ] <= weight_memory_write_data;
                        default: begin
                        end
                    endcase
                end
                default: begin
                end
            endcase
        end
        if (
            bias_memory_write_enable &&
            (bias_memory_write_address < OUTPUT_CHANNELS)
        ) begin
            case (bias_write_lane_select)
                2'd0:
                    bias_bank_0[
                        bias_write_group_index
                    ] <= bias_memory_write_data;
                2'd1:
                    bias_bank_1[
                        bias_write_group_index
                    ] <= bias_memory_write_data;
                2'd2:
                    bias_bank_2[
                        bias_write_group_index
                    ] <= bias_memory_write_data;
                2'd3:
                    bias_bank_3[
                        bias_write_group_index
                    ] <= bias_memory_write_data;
                default: begin
                end
            endcase
        end
    end
endmodule