`timescale 1ns / 1ps

module streaming_spatial_frontend #(
    parameter integer IMAGE_WIDTH    = 64,
    parameter integer IMAGE_HEIGHT   = 64,
    parameter integer INPUT_CHANNELS = 3,
    parameter integer OUTPUT_GROUPS  = 4
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    output wire                    input_ready,
    input  wire signed [7:0]       input_value,
    output wire [7:0]              requested_channel_index,
    output wire signed [7:0]       output_window_value_0,
    output wire signed [7:0]       output_window_value_1,
    output wire signed [7:0]       output_window_value_2,
    output wire signed [7:0]       output_window_value_3,
    output wire signed [7:0]       output_window_value_4,
    output wire signed [7:0]       output_window_value_5,
    output wire signed [7:0]       output_window_value_6,
    output wire signed [7:0]       output_window_value_7,
    output wire signed [7:0]       output_window_value_8,
    output wire [7:0]              output_x,
    output wire [7:0]              output_y,
    output wire [7:0]              output_channel_index,
    output wire [7:0]              output_group_index,
    output wire                    output_first_input_channel,
    output wire                    output_last_input_channel,
    output wire                    output_valid,
    input  wire                    output_ready
);
    localparam integer BRIDGE_DEPTH = 4;
    wire                    generator_input_ready;
    wire                    generator_input_valid;
    wire signed [7:0]       generator_window_value_0;
    wire signed [7:0]       generator_window_value_1;
    wire signed [7:0]       generator_window_value_2;
    wire signed [7:0]       generator_window_value_3;
    wire signed [7:0]       generator_window_value_4;
    wire signed [7:0]       generator_window_value_5;
    wire signed [7:0]       generator_window_value_6;
    wire signed [7:0]       generator_window_value_7;
    wire signed [7:0]       generator_window_value_8;
    wire [7:0]              generator_window_x;
    wire [7:0]              generator_window_y;
    wire [7:0]              generator_channel_index;
    wire                    generator_first_input_channel;
    wire                    generator_last_input_channel;
    wire                    generator_window_valid;
    (* ram_style = "distributed" *)
    reg signed [7:0] bridge_window_0 [0:BRIDGE_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bridge_window_1 [0:BRIDGE_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bridge_window_2 [0:BRIDGE_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bridge_window_3 [0:BRIDGE_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bridge_window_4 [0:BRIDGE_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bridge_window_5 [0:BRIDGE_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bridge_window_6 [0:BRIDGE_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bridge_window_7 [0:BRIDGE_DEPTH-1];
    (* ram_style = "distributed" *)
    reg signed [7:0] bridge_window_8 [0:BRIDGE_DEPTH-1];
    reg [7:0] bridge_x [0:BRIDGE_DEPTH-1];
    reg [7:0] bridge_y [0:BRIDGE_DEPTH-1];
    reg [7:0] bridge_channel_index [0:BRIDGE_DEPTH-1];
    reg       bridge_first_input_channel [0:BRIDGE_DEPTH-1];
    reg       bridge_last_input_channel [0:BRIDGE_DEPTH-1];
    reg [1:0] bridge_write_pointer;
    reg [1:0] bridge_read_pointer;
    reg [2:0] bridge_count;
    reg [2:0] bridge_projected_count;
    wire bridge_push;
    wire bridge_pop;
    wire                    replay_input_ready;
    wire                    replay_input_valid;
    wire signed [7:0]       replay_input_window_value_0;
    wire signed [7:0]       replay_input_window_value_1;
    wire signed [7:0]       replay_input_window_value_2;
    wire signed [7:0]       replay_input_window_value_3;
    wire signed [7:0]       replay_input_window_value_4;
    wire signed [7:0]       replay_input_window_value_5;
    wire signed [7:0]       replay_input_window_value_6;
    wire signed [7:0]       replay_input_window_value_7;
    wire signed [7:0]       replay_input_window_value_8;
    wire [7:0]              replay_input_x;
    wire [7:0]              replay_input_y;
    wire [7:0]              replay_input_channel_index;
    wire                    replay_input_first_input_channel;
    wire                    replay_input_last_input_channel;
    assign replay_input_valid =
        (bridge_count != 3'd0);
    assign replay_input_window_value_0 =
        bridge_window_0[
            bridge_read_pointer
        ];
    assign replay_input_window_value_1 =
        bridge_window_1[
            bridge_read_pointer
        ];
    assign replay_input_window_value_2 =
        bridge_window_2[
            bridge_read_pointer
        ];
    assign replay_input_window_value_3 =
        bridge_window_3[
            bridge_read_pointer
        ];
    assign replay_input_window_value_4 =
        bridge_window_4[
            bridge_read_pointer
        ];
    assign replay_input_window_value_5 =
        bridge_window_5[
            bridge_read_pointer
        ];
    assign replay_input_window_value_6 =
        bridge_window_6[
            bridge_read_pointer
        ];
    assign replay_input_window_value_7 =
        bridge_window_7[
            bridge_read_pointer
        ];
    assign replay_input_window_value_8 =
        bridge_window_8[
            bridge_read_pointer
        ];
    assign replay_input_x =
        bridge_x[
            bridge_read_pointer
        ];
    assign replay_input_y =
        bridge_y[
            bridge_read_pointer
        ];
    assign replay_input_channel_index =
        bridge_channel_index[
            bridge_read_pointer
        ];
    assign replay_input_first_input_channel =
        bridge_first_input_channel[
            bridge_read_pointer
        ];
    assign replay_input_last_input_channel =
        bridge_last_input_channel[
            bridge_read_pointer
        ];
    assign bridge_push =
        generator_window_valid;
    assign bridge_pop =
        replay_input_valid &&
        replay_input_ready;
    always @(*) begin
        bridge_projected_count =
            bridge_count;
        case ({
            bridge_push,
            bridge_pop
        })
            2'b10:
                bridge_projected_count =
                    bridge_count + 3'd1;
            2'b01:
                bridge_projected_count =
                    bridge_count - 3'd1;
            default:
                bridge_projected_count =
                    bridge_count;
        endcase
    end
    assign input_ready =
        generator_input_ready &&
        (bridge_projected_count <
         BRIDGE_DEPTH);
    assign generator_input_valid =
        input_valid &&
        input_ready;
    initial begin
        $display("ACTIVE RTL: streaming_spatial_frontend MULTICHANNEL-PING-PONG V1");
    end
    always @(posedge clk) begin
        if (reset) begin
            bridge_write_pointer <=
                2'd0;
            bridge_read_pointer <=
                2'd0;
            bridge_count <=
                3'd0;
        end else begin
            if (bridge_push) begin
                bridge_window_0[
                    bridge_write_pointer
                ] <= generator_window_value_0;
                bridge_window_1[
                    bridge_write_pointer
                ] <= generator_window_value_1;
                bridge_window_2[
                    bridge_write_pointer
                ] <= generator_window_value_2;
                bridge_window_3[
                    bridge_write_pointer
                ] <= generator_window_value_3;
                bridge_window_4[
                    bridge_write_pointer
                ] <= generator_window_value_4;
                bridge_window_5[
                    bridge_write_pointer
                ] <= generator_window_value_5;
                bridge_window_6[
                    bridge_write_pointer
                ] <= generator_window_value_6;
                bridge_window_7[
                    bridge_write_pointer
                ] <= generator_window_value_7;
                bridge_window_8[
                    bridge_write_pointer
                ] <= generator_window_value_8;
                bridge_x[
                    bridge_write_pointer
                ] <= generator_window_x;
                bridge_y[
                    bridge_write_pointer
                ] <= generator_window_y;
                bridge_channel_index[
                    bridge_write_pointer
                ] <= generator_channel_index;
                bridge_first_input_channel[
                    bridge_write_pointer
                ] <= generator_first_input_channel;
                bridge_last_input_channel[
                    bridge_write_pointer
                ] <= generator_last_input_channel;
                bridge_write_pointer <=
                    bridge_write_pointer +
                    2'd1;
            end
            if (bridge_pop) begin
                bridge_read_pointer <=
                    bridge_read_pointer +
                    2'd1;
            end
            case ({
                bridge_push,
                bridge_pop
            })
                2'b10:
                    bridge_count <=
                        bridge_count + 3'd1;
                2'b01:
                    bridge_count <=
                        bridge_count - 3'd1;
                default:
                    bridge_count <=
                        bridge_count;
            endcase
        end
    end
    streaming_multichannel_3x3_window_generator #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .INPUT_CHANNELS(INPUT_CHANNELS)
    ) multichannel_window_generator_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(
            generator_input_valid
        ),
        .input_ready(
            generator_input_ready
        ),
        .input_value(input_value),

        .requested_channel_index(
            requested_channel_index
        ),
        .window_value_0(
            generator_window_value_0
        ),
        .window_value_1(
            generator_window_value_1
        ),
        .window_value_2(
            generator_window_value_2
        ),
        .window_value_3(
            generator_window_value_3
        ),
        .window_value_4(
            generator_window_value_4
        ),
        .window_value_5(
            generator_window_value_5
        ),
        .window_value_6(
            generator_window_value_6
        ),
        .window_value_7(
            generator_window_value_7
        ),
        .window_value_8(
            generator_window_value_8
        ),
        .window_x(
            generator_window_x
        ),
        .window_y(
            generator_window_y
        ),
        .window_channel_index(
            generator_channel_index
        ),
        .window_first_input_channel(
            generator_first_input_channel
        ),
        .window_last_input_channel(
            generator_last_input_channel
        ),
        .window_valid(
            generator_window_valid
        )
    );
    spatial_window_set_replay_buffer #(
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .OUTPUT_GROUPS(OUTPUT_GROUPS)
    ) replay_buffer_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(
            replay_input_valid
        ),
        .input_ready(
            replay_input_ready
        ),
        .input_window_value_0(
            replay_input_window_value_0
        ),
        .input_window_value_1(
            replay_input_window_value_1
        ),
        .input_window_value_2(
            replay_input_window_value_2
        ),
        .input_window_value_3(
            replay_input_window_value_3
        ),
        .input_window_value_4(
            replay_input_window_value_4
        ),
        .input_window_value_5(
            replay_input_window_value_5
        ),
        .input_window_value_6(
            replay_input_window_value_6
        ),
        .input_window_value_7(
            replay_input_window_value_7
        ),
        .input_window_value_8(
            replay_input_window_value_8
        ),
        .input_x(
            replay_input_x
        ),
        .input_y(
            replay_input_y
        ),
        .input_channel_index(
            replay_input_channel_index
        ),
        .input_first_input_channel(
            replay_input_first_input_channel
        ),
        .input_last_input_channel(
            replay_input_last_input_channel
        ),
        .output_window_value_0(
            output_window_value_0
        ),
        .output_window_value_1(
            output_window_value_1
        ),
        .output_window_value_2(
            output_window_value_2
        ),
        .output_window_value_3(
            output_window_value_3
        ),
        .output_window_value_4(
            output_window_value_4
        ),
        .output_window_value_5(
            output_window_value_5
        ),
        .output_window_value_6(
            output_window_value_6
        ),
        .output_window_value_7(
            output_window_value_7
        ),
        .output_window_value_8(
            output_window_value_8
        ),
        .output_x(output_x),
        .output_y(output_y),
        .output_channel_index(
            output_channel_index
        ),
        .output_group_index(
            output_group_index
        ),
        .output_first_input_channel(
            output_first_input_channel
        ),
        .output_last_input_channel(
            output_last_input_channel
        ),
        .output_valid(output_valid),
        .output_ready(output_ready)
    );
endmodule