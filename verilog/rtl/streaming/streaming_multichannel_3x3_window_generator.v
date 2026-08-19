`timescale 1ns / 1ps

module streaming_multichannel_3x3_window_generator #(
    parameter integer IMAGE_WIDTH    = 64,
    parameter integer IMAGE_HEIGHT   = 64,
    parameter integer INPUT_CHANNELS = 3
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    output wire                    input_ready,
    input  wire signed [7:0]       input_value,
    output wire [7:0]              requested_channel_index,
    output reg  signed [7:0]       window_value_0,
    output reg  signed [7:0]       window_value_1,
    output reg  signed [7:0]       window_value_2,
    output reg  signed [7:0]       window_value_3,
    output reg  signed [7:0]       window_value_4,
    output reg  signed [7:0]       window_value_5,
    output reg  signed [7:0]       window_value_6,
    output reg  signed [7:0]       window_value_7,
    output reg  signed [7:0]       window_value_8,
    output reg  [7:0]              window_x,
    output reg  [7:0]              window_y,
    output reg  [7:0]              window_channel_index,
    output reg                     window_first_input_channel,
    output reg                     window_last_input_channel,
    output reg                     window_valid
);
    reg [7:0] current_input_channel;
    wire [INPUT_CHANNELS-1:0] channel_input_ready;
    wire [INPUT_CHANNELS-1:0] channel_window_valid;
    wire signed [7:0]
        channel_window_value_0 [0:INPUT_CHANNELS-1];
    wire signed [7:0]
        channel_window_value_1 [0:INPUT_CHANNELS-1];
    wire signed [7:0]
        channel_window_value_2 [0:INPUT_CHANNELS-1];
    wire signed [7:0]
        channel_window_value_3 [0:INPUT_CHANNELS-1];
    wire signed [7:0]
        channel_window_value_4 [0:INPUT_CHANNELS-1];
    wire signed [7:0]
        channel_window_value_5 [0:INPUT_CHANNELS-1];
    wire signed [7:0]
        channel_window_value_6 [0:INPUT_CHANNELS-1];
    wire signed [7:0]
        channel_window_value_7 [0:INPUT_CHANNELS-1];
    wire signed [7:0]
        channel_window_value_8 [0:INPUT_CHANNELS-1];
    wire [7:0]
        channel_window_x [0:INPUT_CHANNELS-1];
    wire [7:0]
        channel_window_y [0:INPUT_CHANNELS-1];
    reg selected_channel_ready;
    integer ready_index;
    integer mux_index;
    assign requested_channel_index =
        current_input_channel;
    assign input_ready =
        selected_channel_ready;
    initial begin
        $display("ACTIVE RTL: streaming_multichannel_3x3_window_generator CHANNEL-INTERLEAVED V1");
    end
    always @(*) begin
        selected_channel_ready = 1'b0;
        for (
            ready_index = 0;
            ready_index < INPUT_CHANNELS;
            ready_index = ready_index + 1
        ) begin
            if (
                current_input_channel ==
                ready_index
            ) begin
                selected_channel_ready =
                    channel_input_ready[
                        ready_index
                    ];
            end
        end
    end
    always @(posedge clk) begin
        if (reset) begin
            current_input_channel <= 8'd0;
        end else begin
            if (
                input_valid &&
                input_ready
            ) begin
                if (
                    current_input_channel ==
                    (INPUT_CHANNELS - 1)
                ) begin
                    current_input_channel <=
                        8'd0;
                end else begin
                    current_input_channel <=
                        current_input_channel +
                        8'd1;
                end
            end
        end
    end
    always @(*) begin
        window_value_0 = 8'sd0;
        window_value_1 = 8'sd0;
        window_value_2 = 8'sd0;
        window_value_3 = 8'sd0;
        window_value_4 = 8'sd0;
        window_value_5 = 8'sd0;
        window_value_6 = 8'sd0;
        window_value_7 = 8'sd0;
        window_value_8 = 8'sd0;
        window_x = 8'd0;
        window_y = 8'd0;
        window_channel_index        = 8'd0;
        window_first_input_channel  = 1'b0;
        window_last_input_channel   = 1'b0;
        window_valid                = 1'b0;
        for (
            mux_index = 0;
            mux_index < INPUT_CHANNELS;
            mux_index = mux_index + 1
        ) begin
            if (
                channel_window_valid[
                    mux_index
                ]
            ) begin
                window_value_0 =
                    channel_window_value_0[
                        mux_index
                    ];
                window_value_1 =
                    channel_window_value_1[
                        mux_index
                    ];
                window_value_2 =
                    channel_window_value_2[
                        mux_index
                    ];
                window_value_3 =
                    channel_window_value_3[
                        mux_index
                    ];
                window_value_4 =
                    channel_window_value_4[
                        mux_index
                    ];
                window_value_5 =
                    channel_window_value_5[
                        mux_index
                    ];
                window_value_6 =
                    channel_window_value_6[
                        mux_index
                    ];
                window_value_7 =
                    channel_window_value_7[
                        mux_index
                    ];
                window_value_8 =
                    channel_window_value_8[
                        mux_index
                    ];
                window_x =
                    channel_window_x[
                        mux_index
                    ];
                window_y =
                    channel_window_y[
                        mux_index
                    ];
                window_channel_index =
                    mux_index;
                window_first_input_channel =
                    (mux_index == 0);
                window_last_input_channel =
                    (mux_index ==
                     (INPUT_CHANNELS - 1));
                window_valid =
                    1'b1;
            end
        end
    end
    genvar channel_number;
    generate
        for (
            channel_number = 0;
            channel_number < INPUT_CHANNELS;
            channel_number = channel_number + 1
        ) begin : channel_window_generator
            wire channel_sample_valid;
            assign channel_sample_valid =
                input_valid &&
                input_ready &&
                (current_input_channel ==
                 channel_number);
            streaming_3x3_window_generator #(
                .IMAGE_WIDTH(IMAGE_WIDTH),
                .IMAGE_HEIGHT(IMAGE_HEIGHT)
            ) window_generator_inst (
                .clk(clk),
                .reset(reset),
                .input_valid(
                    channel_sample_valid
                ),
                .input_ready(
                    channel_input_ready[
                        channel_number
                    ]
                ),
                .input_value(input_value),
                .window_value_0(
                    channel_window_value_0[
                        channel_number
                    ]
                ),
                .window_value_1(
                    channel_window_value_1[
                        channel_number
                    ]
                ),
                .window_value_2(
                    channel_window_value_2[
                        channel_number
                    ]
                ),
                .window_value_3(
                    channel_window_value_3[
                        channel_number
                    ]
                ),
                .window_value_4(
                    channel_window_value_4[
                        channel_number
                    ]
                ),
                .window_value_5(
                    channel_window_value_5[
                        channel_number
                    ]
                ),
                .window_value_6(
                    channel_window_value_6[
                        channel_number
                    ]
                ),
                .window_value_7(
                    channel_window_value_7[
                        channel_number
                    ]
                ),
                .window_value_8(
                    channel_window_value_8[
                        channel_number
                    ]
                ),
                .window_x(
                    channel_window_x[
                        channel_number
                    ]
                ),
                .window_y(
                    channel_window_y[
                        channel_number
                    ]
                ),
                .window_valid(
                    channel_window_valid[
                        channel_number
                    ]
                )
            );
        end
    endgenerate
endmodule