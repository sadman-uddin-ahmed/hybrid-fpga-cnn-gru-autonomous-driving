`timescale 1ns / 1ps

module spatial_window_set_replay_buffer #(
    parameter integer INPUT_CHANNELS = 3,
    parameter integer OUTPUT_GROUPS  = 4
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    output wire                    input_ready,
    input  wire signed [7:0]       input_window_value_0,
    input  wire signed [7:0]       input_window_value_1,
    input  wire signed [7:0]       input_window_value_2,
    input  wire signed [7:0]       input_window_value_3,
    input  wire signed [7:0]       input_window_value_4,
    input  wire signed [7:0]       input_window_value_5,
    input  wire signed [7:0]       input_window_value_6,
    input  wire signed [7:0]       input_window_value_7,
    input  wire signed [7:0]       input_window_value_8,
    input  wire [7:0]              input_x,
    input  wire [7:0]              input_y,
    input  wire [7:0]              input_channel_index,
    input  wire                    input_first_input_channel,
    input  wire                    input_last_input_channel,
    output reg  signed [7:0]       output_window_value_0,
    output reg  signed [7:0]       output_window_value_1,
    output reg  signed [7:0]       output_window_value_2,
    output reg  signed [7:0]       output_window_value_3,
    output reg  signed [7:0]       output_window_value_4,
    output reg  signed [7:0]       output_window_value_5,
    output reg  signed [7:0]       output_window_value_6,
    output reg  signed [7:0]       output_window_value_7,
    output reg  signed [7:0]       output_window_value_8,
    output reg  [7:0]              output_x,
    output reg  [7:0]              output_y,
    output reg  [7:0]              output_channel_index,
    output reg  [7:0]              output_group_index,
    output reg                     output_first_input_channel,
    output reg                     output_last_input_channel,
    output reg                     output_valid,
    input  wire                    output_ready
);
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_0_window_0 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_0_window_1 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_0_window_2 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_0_window_3 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_0_window_4 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_0_window_5 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_0_window_6 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_0_window_7 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_0_window_8 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_1_window_0 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_1_window_1 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_1_window_2 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_1_window_3 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_1_window_4 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_1_window_5 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_1_window_6 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_1_window_7 [0:INPUT_CHANNELS-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bank_1_window_8 [0:INPUT_CHANNELS-1];
    reg [7:0] bank_0_x;
    reg [7:0] bank_0_y;
    reg [7:0] bank_1_x;
    reg [7:0] bank_1_y;
    reg bank_0_full;
    reg bank_1_full;
    reg capture_bank;
    reg capture_active;
    reg replay_bank;
    reg replay_active;
    reg [7:0] replay_channel_index;
    reg [7:0] replay_group_index;
    wire input_accept;
    wire input_set_complete;
    wire output_accept;
    wire output_set_complete;
    wire other_replay_bank_full;
    assign input_ready =
        capture_bank ?
        !bank_1_full :
        !bank_0_full;
    assign input_accept =
        input_valid &&
        input_ready;
    assign input_set_complete =
        input_accept &&
        input_last_input_channel;
    assign output_accept =
        output_valid &&
        output_ready;
    assign output_set_complete =
        output_accept &&
        (replay_channel_index ==
         (INPUT_CHANNELS - 1)) &&
        (replay_group_index ==
         (OUTPUT_GROUPS - 1));
    assign other_replay_bank_full =
        replay_bank ?
        bank_0_full :
        bank_1_full;
    initial begin
        $display("ACTIVE RTL: spatial_window_set_replay_buffer PING-PONG V1");
    end
    always @(*) begin
        output_window_value_0 = 8'sd0;
        output_window_value_1 = 8'sd0;
        output_window_value_2 = 8'sd0;
        output_window_value_3 = 8'sd0;
        output_window_value_4 = 8'sd0;
        output_window_value_5 = 8'sd0;
        output_window_value_6 = 8'sd0;
        output_window_value_7 = 8'sd0;
        output_window_value_8 = 8'sd0;
        output_x = 8'd0;
        output_y = 8'd0;
        output_channel_index       = 8'd0;
        output_group_index         = 8'd0;
        output_first_input_channel = 1'b0;
        output_last_input_channel  = 1'b0;
        output_valid               = 1'b0;
        if (replay_active) begin
            output_channel_index =
                replay_channel_index;
            output_group_index =
                replay_group_index;
            output_first_input_channel =
                (replay_channel_index == 8'd0);
            output_last_input_channel =
                (replay_channel_index ==
                 (INPUT_CHANNELS - 1));
            output_valid =
                1'b1;
            if (replay_bank == 1'b0) begin
                output_window_value_0 =
                    bank_0_window_0[
                        replay_channel_index
                    ];
                output_window_value_1 =
                    bank_0_window_1[
                        replay_channel_index
                    ];
                output_window_value_2 =
                    bank_0_window_2[
                        replay_channel_index
                    ];
                output_window_value_3 =
                    bank_0_window_3[
                        replay_channel_index
                    ];
                output_window_value_4 =
                    bank_0_window_4[
                        replay_channel_index
                    ];
                output_window_value_5 =
                    bank_0_window_5[
                        replay_channel_index
                    ];
                output_window_value_6 =
                    bank_0_window_6[
                        replay_channel_index
                    ];
                output_window_value_7 =
                    bank_0_window_7[
                        replay_channel_index
                    ];
                output_window_value_8 =
                    bank_0_window_8[
                        replay_channel_index
                    ];
                output_x =
                    bank_0_x;
                output_y =
                    bank_0_y;
            end else begin
                output_window_value_0 =
                    bank_1_window_0[
                        replay_channel_index
                    ];
                output_window_value_1 =
                    bank_1_window_1[
                        replay_channel_index
                    ];
                output_window_value_2 =
                    bank_1_window_2[
                        replay_channel_index
                    ];
                output_window_value_3 =
                    bank_1_window_3[
                        replay_channel_index
                    ];
                output_window_value_4 =
                    bank_1_window_4[
                        replay_channel_index
                    ];
                output_window_value_5 =
                    bank_1_window_5[
                        replay_channel_index
                    ];
                output_window_value_6 =
                    bank_1_window_6[
                        replay_channel_index
                    ];
                output_window_value_7 =
                    bank_1_window_7[
                        replay_channel_index
                    ];
                output_window_value_8 =
                    bank_1_window_8[
                        replay_channel_index
                    ];
                output_x =
                    bank_1_x;
                output_y =
                    bank_1_y;
            end
        end
    end
    always @(posedge clk) begin
        if (reset) begin
            bank_0_full <= 1'b0;
            bank_1_full <= 1'b0;
            capture_bank   <= 1'b0;
            capture_active <= 1'b0;
            replay_bank   <= 1'b0;
            replay_active <= 1'b0;
            replay_channel_index <= 8'd0;
            replay_group_index   <= 8'd0;
            bank_0_x <= 8'd0;
            bank_0_y <= 8'd0;
            bank_1_x <= 8'd0;
            bank_1_y <= 8'd0;
        end else begin
            if (input_accept) begin
                capture_active <=
                    !input_last_input_channel;
                if (capture_bank == 1'b0) begin
                    bank_0_window_0[
                        input_channel_index
                    ] <= input_window_value_0;
                    bank_0_window_1[
                        input_channel_index
                    ] <= input_window_value_1;
                    bank_0_window_2[
                        input_channel_index
                    ] <= input_window_value_2;
                    bank_0_window_3[
                        input_channel_index
                    ] <= input_window_value_3;
                    bank_0_window_4[
                        input_channel_index
                    ] <= input_window_value_4;
                    bank_0_window_5[
                        input_channel_index
                    ] <= input_window_value_5;
                    bank_0_window_6[
                        input_channel_index
                    ] <= input_window_value_6;
                    bank_0_window_7[
                        input_channel_index
                    ] <= input_window_value_7;
                    bank_0_window_8[
                        input_channel_index
                    ] <= input_window_value_8;
                    if (
                        input_first_input_channel
                    ) begin
                        bank_0_x <= input_x;
                        bank_0_y <= input_y;
                    end
                end else begin
                    bank_1_window_0[
                        input_channel_index
                    ] <= input_window_value_0;
                    bank_1_window_1[
                        input_channel_index
                    ] <= input_window_value_1;
                    bank_1_window_2[
                        input_channel_index
                    ] <= input_window_value_2;
                    bank_1_window_3[
                        input_channel_index
                    ] <= input_window_value_3;
                    bank_1_window_4[
                        input_channel_index
                    ] <= input_window_value_4;
                    bank_1_window_5[
                        input_channel_index
                    ] <= input_window_value_5;
                    bank_1_window_6[
                        input_channel_index
                    ] <= input_window_value_6;
                    bank_1_window_7[
                        input_channel_index
                    ] <= input_window_value_7;
                    bank_1_window_8[
                        input_channel_index
                    ] <= input_window_value_8;
                    if (
                        input_first_input_channel
                    ) begin
                        bank_1_x <= input_x;
                        bank_1_y <= input_y;
                    end
                end
            end
            if (!replay_active) begin
                if (input_set_complete) begin
                    if (capture_bank == 1'b0) begin
                        bank_0_full <= 1'b1;
                    end else begin
                        bank_1_full <= 1'b1;
                    end
                    replay_bank <=
                        capture_bank;
                    replay_active <=
                        1'b1;
                    replay_channel_index <=
                        8'd0;
                    replay_group_index <=
                        8'd0;
                    capture_bank <=
                        ~capture_bank;
                end
            end else begin
                if (input_set_complete) begin
                    if (capture_bank == 1'b0) begin
                        bank_0_full <= 1'b1;
                    end else begin
                        bank_1_full <= 1'b1;
                    end
                end
                if (output_accept) begin
                    if (
                        replay_channel_index ==
                        (INPUT_CHANNELS - 1)
                    ) begin
                        if (
                            replay_group_index ==
                            (OUTPUT_GROUPS - 1)
                        ) begin
                            if (replay_bank == 1'b0) begin
                                bank_0_full <= 1'b0;
                            end else begin
                                bank_1_full <= 1'b0;
                            end
                            replay_channel_index <=
                                8'd0;
                            replay_group_index <=
                                8'd0;
                            if (input_set_complete) begin
                                replay_bank <=
                                    capture_bank;
                                replay_active <=
                                    1'b1;
                                capture_bank <=
                                    replay_bank;
                            end else if (
                                other_replay_bank_full
                            ) begin
                                replay_bank <=
                                    ~replay_bank;
                                replay_active <=
                                    1'b1;
                                capture_bank <=
                                    replay_bank;
                            end else begin
                                replay_active <=
                                    1'b0;
                                if (
                                    !capture_active &&
                                    !input_accept
                                ) begin
                                    capture_bank <=
                                        replay_bank;
                                end
                            end
                        end else begin
                            replay_channel_index <=
                                8'd0;
                            replay_group_index <=
                                replay_group_index +
                                8'd1;
                        end
                    end else begin
                        replay_channel_index <=
                            replay_channel_index +
                            8'd1;
                    end
                end
            end
        end
    end
endmodule