`timescale 1ns / 1ps
`default_nettype none

module spatial_window_set_replay_buffer_tb;

    localparam integer CLOCK_PERIOD          = 10;
    localparam integer INPUT_CHANNELS        = 3;
    localparam integer OUTPUT_GROUPS         = 4;
    localparam integer WINDOW_SET_COUNT      = 3;
    localparam integer INPUT_VALUE_COUNT     =
        WINDOW_SET_COUNT * INPUT_CHANNELS;
    localparam integer OUTPUTS_PER_SET       =
        INPUT_CHANNELS * OUTPUT_GROUPS;
    localparam integer EXPECTED_OUTPUT_COUNT =
        WINDOW_SET_COUNT * OUTPUTS_PER_SET;
    localparam integer EXPECTED_STALL_CYCLES = 5;
    localparam integer MAX_HALF_CYCLES       = 300;

    reg clk;
    reg reset;

    reg                    input_valid;
    wire                   input_ready;

    reg signed [7:0]       input_window_value_0;
    reg signed [7:0]       input_window_value_1;
    reg signed [7:0]       input_window_value_2;
    reg signed [7:0]       input_window_value_3;
    reg signed [7:0]       input_window_value_4;
    reg signed [7:0]       input_window_value_5;
    reg signed [7:0]       input_window_value_6;
    reg signed [7:0]       input_window_value_7;
    reg signed [7:0]       input_window_value_8;

    reg [7:0]              input_x;
    reg [7:0]              input_y;
    reg [7:0]              input_channel_index;
    reg                    input_first_input_channel;
    reg                    input_last_input_channel;

    wire signed [7:0]      output_window_value_0;
    wire signed [7:0]      output_window_value_1;
    wire signed [7:0]      output_window_value_2;
    wire signed [7:0]      output_window_value_3;
    wire signed [7:0]      output_window_value_4;
    wire signed [7:0]      output_window_value_5;
    wire signed [7:0]      output_window_value_6;
    wire signed [7:0]      output_window_value_7;
    wire signed [7:0]      output_window_value_8;

    wire [7:0]             output_x;
    wire [7:0]             output_y;
    wire [7:0]             output_channel_index;
    wire [7:0]             output_group_index;
    wire                   output_first_input_channel;
    wire                   output_last_input_channel;
    wire                   output_valid;

    reg                    output_ready;

    reg signed [7:0]       held_window_value_0;
    reg signed [7:0]       held_window_value_1;
    reg signed [7:0]       held_window_value_2;
    reg signed [7:0]       held_window_value_3;
    reg signed [7:0]       held_window_value_4;
    reg signed [7:0]       held_window_value_5;
    reg signed [7:0]       held_window_value_6;
    reg signed [7:0]       held_window_value_7;
    reg signed [7:0]       held_window_value_8;

    reg [7:0]              held_output_x;
    reg [7:0]              held_output_y;
    reg [7:0]              held_channel_index;
    reg [7:0]              held_group_index;
    reg                    held_first_input_channel;
    reg                    held_last_input_channel;

    integer accepted_input_count;
    integer output_count;
    integer completed_set_count;
    integer input_backpressure_count;
    integer output_stall_cycle_count;
    integer output_stall_test_count;
    integer output_bubble_count;
    integer ready_wait_count;
    integer drain_wait_count;
    integer error_count;
    integer unknown_count;

    integer expected_set;
    integer expected_position;
    integer expected_group;
    integer expected_channel;

    reg output_stream_started;
    reg output_stall_tests_complete;

    reg simulation_pass;
    reg simulation_fail;
    reg simulation_complete;

    spatial_window_set_replay_buffer #(
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .OUTPUT_GROUPS(OUTPUT_GROUPS)
    ) dut (
        .clk(clk),
        .reset(reset),

        .input_valid(input_valid),
        .input_ready(input_ready),

        .input_window_value_0(input_window_value_0),
        .input_window_value_1(input_window_value_1),
        .input_window_value_2(input_window_value_2),
        .input_window_value_3(input_window_value_3),
        .input_window_value_4(input_window_value_4),
        .input_window_value_5(input_window_value_5),
        .input_window_value_6(input_window_value_6),
        .input_window_value_7(input_window_value_7),
        .input_window_value_8(input_window_value_8),

        .input_x(input_x),
        .input_y(input_y),
        .input_channel_index(input_channel_index),
        .input_first_input_channel(
            input_first_input_channel
        ),
        .input_last_input_channel(
            input_last_input_channel
        ),

        .output_window_value_0(output_window_value_0),
        .output_window_value_1(output_window_value_1),
        .output_window_value_2(output_window_value_2),
        .output_window_value_3(output_window_value_3),
        .output_window_value_4(output_window_value_4),
        .output_window_value_5(output_window_value_5),
        .output_window_value_6(output_window_value_6),
        .output_window_value_7(output_window_value_7),
        .output_window_value_8(output_window_value_8),

        .output_x(output_x),
        .output_y(output_y),
        .output_channel_index(output_channel_index),
        .output_group_index(output_group_index),
        .output_first_input_channel(
            output_first_input_channel
        ),
        .output_last_input_channel(
            output_last_input_channel
        ),
        .output_valid(output_valid),
        .output_ready(output_ready)
    );

    function signed [7:0] expected_window_value;
        input integer test_set;
        input integer test_channel;
        input integer test_tap;

        begin
            case (test_set)
                0: begin
                    case (test_channel)
                        0:
                            expected_window_value =
                                1 + test_tap;

                        1:
                            expected_window_value =
                                11 + test_tap;

                        default:
                            expected_window_value =
                                -(21 + test_tap);
                    endcase
                end

                1: begin
                    case (test_channel)
                        0:
                            expected_window_value =
                                31 + test_tap;

                        1:
                            expected_window_value =
                                -(41 + test_tap);

                        default:
                            expected_window_value =
                                51 + test_tap;
                    endcase
                end

                default: begin
                    case (test_channel)
                        0:
                            expected_window_value =
                                -(61 + test_tap);

                        1:
                            expected_window_value =
                                71 + test_tap;

                        default:
                            expected_window_value =
                                -(81 + test_tap);
                    endcase
                end
            endcase
        end
    endfunction

    function [7:0] expected_x_value;
        input integer test_set;

        begin
            case (test_set)
                0:
                    expected_x_value = 8'd4;

                1:
                    expected_x_value = 8'd6;

                default:
                    expected_x_value = 8'd8;
            endcase
        end
    endfunction

    function [7:0] expected_y_value;
        input integer test_set;

        begin
            case (test_set)
                0:
                    expected_y_value = 8'd5;

                1:
                    expected_y_value = 8'd7;

                default:
                    expected_y_value = 8'd9;
            endcase
        end
    endfunction

    task set_input_window;
        input integer test_set;
        input integer test_channel;

        begin
            input_window_value_0 =
                expected_window_value(
                    test_set,
                    test_channel,
                    0
                );

            input_window_value_1 =
                expected_window_value(
                    test_set,
                    test_channel,
                    1
                );

            input_window_value_2 =
                expected_window_value(
                    test_set,
                    test_channel,
                    2
                );

            input_window_value_3 =
                expected_window_value(
                    test_set,
                    test_channel,
                    3
                );

            input_window_value_4 =
                expected_window_value(
                    test_set,
                    test_channel,
                    4
                );

            input_window_value_5 =
                expected_window_value(
                    test_set,
                    test_channel,
                    5
                );

            input_window_value_6 =
                expected_window_value(
                    test_set,
                    test_channel,
                    6
                );

            input_window_value_7 =
                expected_window_value(
                    test_set,
                    test_channel,
                    7
                );

            input_window_value_8 =
                expected_window_value(
                    test_set,
                    test_channel,
                    8
                );

            input_x =
                expected_x_value(test_set);

            input_y =
                expected_y_value(test_set);

            input_channel_index =
                test_channel;

            input_first_input_channel =
                (test_channel == 0);

            input_last_input_channel =
                (test_channel ==
                 (INPUT_CHANNELS - 1));
        end
    endtask

    task send_input_channel;
        input integer test_set;
        input integer test_channel;

        begin
            @(negedge clk);

            set_input_window(
                test_set,
                test_channel
            );

            input_valid =
                1'b1;

            ready_wait_count =
                0;

            while (
                (input_ready !== 1'b1) &&
                (ready_wait_count < 100)
            ) begin
                input_backpressure_count =
                    input_backpressure_count + 1;

                @(posedge clk);
                @(negedge clk);

                ready_wait_count =
                    ready_wait_count + 1;
            end

            if (
                input_ready !==
                1'b1
            ) begin
                error_count =
                    error_count + 1;

                $display(
                    "ERROR: Timed out waiting to capture set=%0d channel=%0d.",
                    test_set,
                    test_channel
                );
            end else begin
                @(posedge clk);

                accepted_input_count =
                    accepted_input_count + 1;
            end
        end
    endtask

    task stall_output_at;
        input [7:0] target_x;
        input [7:0] target_y;
        input [7:0] target_group;
        input [7:0] target_channel;
        input integer stall_cycles;

        integer search_count;
        integer local_stall_count;
        reg target_found;

        begin
            search_count =
                0;

            local_stall_count =
                0;

            target_found =
                1'b0;

            while (
                (!target_found) &&
                (search_count < 150)
            ) begin
                @(negedge clk);

                if (
                    (output_valid === 1'b1) &&
                    (output_x === target_x) &&
                    (output_y === target_y) &&
                    (output_group_index ===
                     target_group) &&
                    (output_channel_index ===
                     target_channel)
                ) begin
                    target_found =
                        1'b1;
                end else begin
                    search_count =
                        search_count + 1;
                end
            end

            if (!target_found) begin
                error_count =
                    error_count + 1;

                $display(
                    "ERROR: Could not find requested output stall target x=%0d y=%0d group=%0d channel=%0d.",
                    target_x,
                    target_y,
                    target_group,
                    target_channel
                );
            end else begin
                output_ready =
                    1'b0;

                held_window_value_0 =
                    output_window_value_0;
                held_window_value_1 =
                    output_window_value_1;
                held_window_value_2 =
                    output_window_value_2;
                held_window_value_3 =
                    output_window_value_3;
                held_window_value_4 =
                    output_window_value_4;
                held_window_value_5 =
                    output_window_value_5;
                held_window_value_6 =
                    output_window_value_6;
                held_window_value_7 =
                    output_window_value_7;
                held_window_value_8 =
                    output_window_value_8;

                held_output_x =
                    output_x;

                held_output_y =
                    output_y;

                held_channel_index =
                    output_channel_index;

                held_group_index =
                    output_group_index;

                held_first_input_channel =
                    output_first_input_channel;

                held_last_input_channel =
                    output_last_input_channel;

                repeat (stall_cycles) begin
                    @(posedge clk);
                    #1;

                    local_stall_count =
                        local_stall_count + 1;

                    output_stall_cycle_count =
                        output_stall_cycle_count + 1;

                    if (
                        output_valid !==
                        1'b1
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: output_valid deasserted during output backpressure."
                        );
                    end

                    if (
                        (output_window_value_0 !==
                         held_window_value_0) ||
                        (output_window_value_1 !==
                         held_window_value_1) ||
                        (output_window_value_2 !==
                         held_window_value_2) ||
                        (output_window_value_3 !==
                         held_window_value_3) ||
                        (output_window_value_4 !==
                         held_window_value_4) ||
                        (output_window_value_5 !==
                         held_window_value_5) ||
                        (output_window_value_6 !==
                         held_window_value_6) ||
                        (output_window_value_7 !==
                         held_window_value_7) ||
                        (output_window_value_8 !==
                         held_window_value_8) ||
                        (output_x !==
                         held_output_x) ||
                        (output_y !==
                         held_output_y) ||
                        (output_channel_index !==
                         held_channel_index) ||
                        (output_group_index !==
                         held_group_index) ||
                        (output_first_input_channel !==
                         held_first_input_channel) ||
                        (output_last_input_channel !==
                         held_last_input_channel)
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Replay output changed while output_ready was low."
                        );
                    end
                end

                if (
                    local_stall_count !=
                    stall_cycles
                ) begin
                    error_count =
                        error_count + 1;
                end

                @(negedge clk);

                output_ready =
                    1'b1;

                output_stall_test_count =
                    output_stall_test_count + 1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;

        repeat (MAX_HALF_CYCLES) begin
            #(CLOCK_PERIOD / 2);
            clk = ~clk;
        end

        if (!simulation_complete) begin
            error_count =
                error_count + 1;

            $display("================================================");
            $display("FAIL: TESTBENCH TIMEOUT");
            $display(
                "Accepted inputs = %0d",
                accepted_input_count
            );
            $display(
                "Replay outputs  = %0d",
                output_count
            );
            $display(
                "Total errors    = %0d",
                error_count
            );
            $display("================================================");
        end

        $finish;
    end

    always @(posedge clk) begin
        if (!reset) begin
            if (
                (input_ready !== 1'b0) &&
                (input_ready !== 1'b1)
            ) begin
                unknown_count =
                    unknown_count + 1;

                error_count =
                    error_count + 1;

                $display(
                    "ERROR: input_ready contains X/Z."
                );
            end

            if (
                (output_valid !== 1'b0) &&
                (output_valid !== 1'b1)
            ) begin
                unknown_count =
                    unknown_count + 1;

                error_count =
                    error_count + 1;

                $display(
                    "ERROR: output_valid contains X/Z."
                );
            end

            if (
                (output_ready !== 1'b0) &&
                (output_ready !== 1'b1)
            ) begin
                unknown_count =
                    unknown_count + 1;

                error_count =
                    error_count + 1;

                $display(
                    "ERROR: output_ready contains X/Z."
                );
            end

            if (
                output_stream_started &&
                (output_count <
                 EXPECTED_OUTPUT_COUNT) &&
                (output_valid !== 1'b1)
            ) begin
                output_bubble_count =
                    output_bubble_count + 1;

                error_count =
                    error_count + 1;

                $display(
                    "ERROR: Bubble detected inside continuous ping-pong replay at output %0d.",
                    output_count
                );
            end

            if (
                output_valid ===
                1'b1
            ) begin
                output_stream_started =
                    1'b1;

                if (
                    ((^output_window_value_0) === 1'bx) ||
                    ((^output_window_value_1) === 1'bx) ||
                    ((^output_window_value_2) === 1'bx) ||
                    ((^output_window_value_3) === 1'bx) ||
                    ((^output_window_value_4) === 1'bx) ||
                    ((^output_window_value_5) === 1'bx) ||
                    ((^output_window_value_6) === 1'bx) ||
                    ((^output_window_value_7) === 1'bx) ||
                    ((^output_window_value_8) === 1'bx) ||
                    ((^output_x) === 1'bx) ||
                    ((^output_y) === 1'bx) ||
                    ((^output_channel_index) === 1'bx) ||
                    ((^output_group_index) === 1'bx)
                ) begin
                    unknown_count =
                        unknown_count + 1;

                    error_count =
                        error_count + 1;

                    $display(
                        "ERROR: Replay output contains X/Z."
                    );
                end
            end

            if (
                (output_valid === 1'b1) &&
                (output_ready === 1'b1)
            ) begin
                if (
                    output_count >=
                    EXPECTED_OUTPUT_COUNT
                ) begin
                    error_count =
                        error_count + 1;

                    $display(
                        "ERROR: Unexpected extra replay output."
                    );
                end else begin
                    expected_set =
                        output_count /
                        OUTPUTS_PER_SET;

                    expected_position =
                        output_count %
                        OUTPUTS_PER_SET;

                    expected_group =
                        expected_position /
                        INPUT_CHANNELS;

                    expected_channel =
                        expected_position %
                        INPUT_CHANNELS;

                    if (
                        output_x !==
                        expected_x_value(
                            expected_set
                        )
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d X expected=%0d received=%0d",
                            output_count,
                            expected_x_value(
                                expected_set
                            ),
                            output_x
                        );
                    end

                    if (
                        output_y !==
                        expected_y_value(
                            expected_set
                        )
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d Y expected=%0d received=%0d",
                            output_count,
                            expected_y_value(
                                expected_set
                            ),
                            output_y
                        );
                    end

                    if (
                        output_group_index !==
                        expected_group
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d group expected=%0d received=%0d",
                            output_count,
                            expected_group,
                            output_group_index
                        );
                    end

                    if (
                        output_channel_index !==
                        expected_channel
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d channel expected=%0d received=%0d",
                            output_count,
                            expected_channel,
                            output_channel_index
                        );
                    end

                    if (
                        output_first_input_channel !==
                        (expected_channel == 0)
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d FIRST flag incorrect.",
                            output_count
                        );
                    end

                    if (
                        output_last_input_channel !==
                        (expected_channel ==
                         (INPUT_CHANNELS - 1))
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d LAST flag incorrect.",
                            output_count
                        );
                    end

                    if (
                        output_window_value_0 !==
                        expected_window_value(
                            expected_set,
                            expected_channel,
                            0
                        )
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d tap 0 mismatch.",
                            output_count
                        );
                    end

                    if (
                        output_window_value_1 !==
                        expected_window_value(
                            expected_set,
                            expected_channel,
                            1
                        )
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d tap 1 mismatch.",
                            output_count
                        );
                    end

                    if (
                        output_window_value_2 !==
                        expected_window_value(
                            expected_set,
                            expected_channel,
                            2
                        )
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d tap 2 mismatch.",
                            output_count
                        );
                    end

                    if (
                        output_window_value_3 !==
                        expected_window_value(
                            expected_set,
                            expected_channel,
                            3
                        )
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d tap 3 mismatch.",
                            output_count
                        );
                    end

                    if (
                        output_window_value_4 !==
                        expected_window_value(
                            expected_set,
                            expected_channel,
                            4
                        )
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d tap 4 mismatch.",
                            output_count
                        );
                    end

                    if (
                        output_window_value_5 !==
                        expected_window_value(
                            expected_set,
                            expected_channel,
                            5
                        )
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d tap 5 mismatch.",
                            output_count
                        );
                    end

                    if (
                        output_window_value_6 !==
                        expected_window_value(
                            expected_set,
                            expected_channel,
                            6
                        )
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d tap 6 mismatch.",
                            output_count
                        );
                    end

                    if (
                        output_window_value_7 !==
                        expected_window_value(
                            expected_set,
                            expected_channel,
                            7
                        )
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d tap 7 mismatch.",
                            output_count
                        );
                    end

                    if (
                        output_window_value_8 !==
                        expected_window_value(
                            expected_set,
                            expected_channel,
                            8
                        )
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d tap 8 mismatch.",
                            output_count
                        );
                    end

                    if (
                        (output_x ===
                         expected_x_value(
                             expected_set
                         )) &&
                        (output_y ===
                         expected_y_value(
                             expected_set
                         )) &&
                        (output_group_index ===
                         expected_group) &&
                        (output_channel_index ===
                         expected_channel) &&
                        (output_window_value_0 ===
                         expected_window_value(
                             expected_set,
                             expected_channel,
                             0
                         )) &&
                        (output_window_value_1 ===
                         expected_window_value(
                             expected_set,
                             expected_channel,
                             1
                         )) &&
                        (output_window_value_2 ===
                         expected_window_value(
                             expected_set,
                             expected_channel,
                             2
                         )) &&
                        (output_window_value_3 ===
                         expected_window_value(
                             expected_set,
                             expected_channel,
                             3
                         )) &&
                        (output_window_value_4 ===
                         expected_window_value(
                             expected_set,
                             expected_channel,
                             4
                         )) &&
                        (output_window_value_5 ===
                         expected_window_value(
                             expected_set,
                             expected_channel,
                             5
                         )) &&
                        (output_window_value_6 ===
                         expected_window_value(
                             expected_set,
                             expected_channel,
                             6
                         )) &&
                        (output_window_value_7 ===
                         expected_window_value(
                             expected_set,
                             expected_channel,
                             7
                         )) &&
                        (output_window_value_8 ===
                         expected_window_value(
                             expected_set,
                             expected_channel,
                             8
                         ))
                    ) begin
                        $display(
                            "PASS: Set %0d (%0d,%0d) group=%0d channel=%0d center=%0d",
                            expected_set,
                            output_x,
                            output_y,
                            output_group_index,
                            output_channel_index,
                            output_window_value_4
                        );
                    end

                    if (
                        (expected_group ==
                         (OUTPUT_GROUPS - 1)) &&
                        (expected_channel ==
                         (INPUT_CHANNELS - 1))
                    ) begin
                        completed_set_count =
                            completed_set_count + 1;
                    end
                end

                output_count =
                    output_count + 1;
            end
        end
    end

    initial begin
        output_ready =
            1'b1;

        output_stall_tests_complete =
            1'b0;

        repeat (5) @(posedge clk);

        stall_output_at(
            8'd4,
            8'd5,
            8'd1,
            8'd1,
            3
        );

        stall_output_at(
            8'd6,
            8'd7,
            8'd2,
            8'd0,
            2
        );

        output_stall_tests_complete =
            1'b1;
    end

    initial begin
        reset                       = 1'b1;

        input_valid                 = 1'b0;

        input_window_value_0        = 8'sd0;
        input_window_value_1        = 8'sd0;
        input_window_value_2        = 8'sd0;
        input_window_value_3        = 8'sd0;
        input_window_value_4        = 8'sd0;
        input_window_value_5        = 8'sd0;
        input_window_value_6        = 8'sd0;
        input_window_value_7        = 8'sd0;
        input_window_value_8        = 8'sd0;

        input_x                     = 8'd0;
        input_y                     = 8'd0;
        input_channel_index         = 8'd0;
        input_first_input_channel   = 1'b0;
        input_last_input_channel    = 1'b0;

        held_window_value_0         = 8'sd0;
        held_window_value_1         = 8'sd0;
        held_window_value_2         = 8'sd0;
        held_window_value_3         = 8'sd0;
        held_window_value_4         = 8'sd0;
        held_window_value_5         = 8'sd0;
        held_window_value_6         = 8'sd0;
        held_window_value_7         = 8'sd0;
        held_window_value_8         = 8'sd0;

        held_output_x               = 8'd0;
        held_output_y               = 8'd0;
        held_channel_index          = 8'd0;
        held_group_index            = 8'd0;
        held_first_input_channel    = 1'b0;
        held_last_input_channel     = 1'b0;

        accepted_input_count        = 0;
        output_count                = 0;
        completed_set_count         = 0;
        input_backpressure_count    = 0;
        output_stall_cycle_count    = 0;
        output_stall_test_count     = 0;
        output_bubble_count         = 0;
        ready_wait_count            = 0;
        drain_wait_count            = 0;
        error_count                 = 0;
        unknown_count               = 0;

        expected_set                = 0;
        expected_position           = 0;
        expected_group              = 0;
        expected_channel            = 0;

        output_stream_started       = 1'b0;

        simulation_pass             = 1'b0;
        simulation_fail             = 1'b0;
        simulation_complete         = 1'b0;

        repeat (5) @(posedge clk);

        @(negedge clk);
        reset = 1'b0;

        // Set A starts replay as soon as its third channel is captured.
        send_input_channel(0, 0);
        send_input_channel(0, 1);
        send_input_channel(0, 2);

        // Set B is captured into the other bank during Set A replay.
        send_input_channel(1, 0);
        send_input_channel(1, 1);
        send_input_channel(1, 2);

        // Set C is deliberately presented while both banks are occupied.
        send_input_channel(2, 0);
        send_input_channel(2, 1);
        send_input_channel(2, 2);

        @(negedge clk);

        input_valid =
            1'b0;

        input_window_value_0 =
            8'sd100;

        input_window_value_1 =
            -8'sd100;

        input_window_value_2 =
            8'sd99;

        input_window_value_3 =
            -8'sd99;

        input_window_value_4 =
            8'sd98;

        input_window_value_5 =
            -8'sd98;

        input_window_value_6 =
            8'sd97;

        input_window_value_7 =
            -8'sd97;

        input_window_value_8 =
            8'sd96;

        drain_wait_count =
            0;

        while (
            (output_count <
             EXPECTED_OUTPUT_COUNT) &&
            (drain_wait_count < 100)
        ) begin
            @(posedge clk);

            drain_wait_count =
                drain_wait_count + 1;
        end

        repeat (3) @(posedge clk);
        #2;

        if (
            accepted_input_count !=
            INPUT_VALUE_COUNT
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Expected %0d captured channel windows but observed %0d.",
                INPUT_VALUE_COUNT,
                accepted_input_count
            );
        end

        if (
            output_count !=
            EXPECTED_OUTPUT_COUNT
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Expected %0d replay outputs but observed %0d.",
                EXPECTED_OUTPUT_COUNT,
                output_count
            );
        end

        if (
            completed_set_count !=
            WINDOW_SET_COUNT
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Expected %0d completed replay sets but observed %0d.",
                WINDOW_SET_COUNT,
                completed_set_count
            );
        end

        if (
            input_backpressure_count ==
            0
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Input-side ping-pong backpressure was never exercised."
            );
        end

        if (
            output_stall_test_count !=
            2
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Expected 2 output stall tests but completed %0d.",
                output_stall_test_count
            );
        end

        if (
            output_stall_cycle_count !=
            EXPECTED_STALL_CYCLES
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Expected %0d output stall cycles but observed %0d.",
                EXPECTED_STALL_CYCLES,
                output_stall_cycle_count
            );
        end

        if (
            output_bubble_count !=
            0
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Ping-pong replay contained %0d output-valid bubbles.",
                output_bubble_count
            );
        end

        if (
            !output_stall_tests_complete
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Output stall verification did not complete."
            );
        end

        if (
            input_ready !==
            1'b1
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Replay buffer was not ready for a new input set after draining."
            );
        end

        if (
            output_valid !==
            1'b0
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: output_valid remained asserted after all replay sets drained."
            );
        end

        $display("================================================");
        $display("Spatial window-set ping-pong replay verification complete");
        $display("Captured channel windows = %0d", accepted_input_count);
        $display("Replay outputs           = %0d", output_count);
        $display("Completed window sets    = %0d", completed_set_count);
        $display("Input backpressure cycles= %0d", input_backpressure_count);
        $display("Output stall tests       = %0d", output_stall_test_count);
        $display("Output stall cycles      = %0d", output_stall_cycle_count);
        $display("Replay bubbles           = %0d", output_bubble_count);
        $display("X/Z errors               = %0d", unknown_count);
        $display("Total errors             = %0d", error_count);
        $display("================================================");

        if (
            error_count ==
            0
        ) begin
            simulation_pass =
                1'b1;

            $display(
                "PASS: Ping-pong window replay preserved every tap, coordinate, group, channel, stall and bank transition without replay bubbles."
            );
        end else begin
            simulation_fail =
                1'b1;

            $display(
                "FAIL: Spatial window-set replay verification found %0d errors.",
                error_count
            );
        end

        simulation_complete =
            1'b1;

        #20;
        $finish;
    end

endmodule

`default_nettype wire