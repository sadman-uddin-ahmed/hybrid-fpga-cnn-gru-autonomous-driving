`timescale 1ns / 1ps
`default_nettype none

module convolution_four_lane_datapath_tb;
    localparam integer CLOCK_PERIOD          = 10;
    localparam integer CONV1_EXPECTED_OUTPUTS = 8;
    localparam integer CONV2_EXPECTED_OUTPUTS = 8;
    localparam integer MAX_HALF_CYCLES       = 400;
    reg clk;
    reg conv1_reset;
    reg conv2_reset;
    reg input_valid;
    reg first_input_channel;
    reg last_input_channel;
    reg signed [7:0] input_value_0;
    reg signed [7:0] input_value_1;
    reg signed [7:0] input_value_2;
    reg signed [7:0] input_value_3;
    reg signed [7:0] input_value_4;
    reg signed [7:0] input_value_5;
    reg signed [7:0] input_value_6;
    reg signed [7:0] input_value_7;
    reg signed [7:0] input_value_8;
    reg signed [7:0] weight_lane_0_value_0;
    reg signed [7:0] weight_lane_0_value_1;
    reg signed [7:0] weight_lane_0_value_2;
    reg signed [7:0] weight_lane_0_value_3;
    reg signed [7:0] weight_lane_0_value_4;
    reg signed [7:0] weight_lane_0_value_5;
    reg signed [7:0] weight_lane_0_value_6;
    reg signed [7:0] weight_lane_0_value_7;
    reg signed [7:0] weight_lane_0_value_8;
    reg signed [7:0] weight_lane_1_value_0;
    reg signed [7:0] weight_lane_1_value_1;
    reg signed [7:0] weight_lane_1_value_2;
    reg signed [7:0] weight_lane_1_value_3;
    reg signed [7:0] weight_lane_1_value_4;
    reg signed [7:0] weight_lane_1_value_5;
    reg signed [7:0] weight_lane_1_value_6;
    reg signed [7:0] weight_lane_1_value_7;
    reg signed [7:0] weight_lane_1_value_8;
    reg signed [7:0] weight_lane_2_value_0;
    reg signed [7:0] weight_lane_2_value_1;
    reg signed [7:0] weight_lane_2_value_2;
    reg signed [7:0] weight_lane_2_value_3;
    reg signed [7:0] weight_lane_2_value_4;
    reg signed [7:0] weight_lane_2_value_5;
    reg signed [7:0] weight_lane_2_value_6;
    reg signed [7:0] weight_lane_2_value_7;
    reg signed [7:0] weight_lane_2_value_8;
    reg signed [7:0] weight_lane_3_value_0;
    reg signed [7:0] weight_lane_3_value_1;
    reg signed [7:0] weight_lane_3_value_2;
    reg signed [7:0] weight_lane_3_value_3;
    reg signed [7:0] weight_lane_3_value_4;
    reg signed [7:0] weight_lane_3_value_5;
    reg signed [7:0] weight_lane_3_value_6;
    reg signed [7:0] weight_lane_3_value_7;
    reg signed [7:0] weight_lane_3_value_8;
    reg signed [31:0] bias_value_0;
    reg signed [31:0] bias_value_1;
    reg signed [31:0] bias_value_2;
    reg signed [31:0] bias_value_3;
    wire               conv1_input_ready;
    wire signed [7:0]  conv1_output_value;
    wire [1:0]         conv1_output_lane_index;
    wire               conv1_output_valid;
    wire               conv1_requantize_busy;
    wire               conv2_input_ready;
    wire signed [7:0]  conv2_output_value;
    wire [1:0]         conv2_output_lane_index;
    wire               conv2_output_valid;
    wire               conv2_requantize_busy;
    reg signed [7:0] expected_conv1_value [0:CONV1_EXPECTED_OUTPUTS-1];
    reg signed [7:0] expected_conv2_value [0:CONV2_EXPECTED_OUTPUTS-1];
    integer conv1_accepted_channels;
    integer conv2_accepted_channels;
    integer conv1_output_count;
    integer conv2_output_count;
    integer conv1_continuous_count;
    integer conv2_first_burst_count;
    integer conv2_second_burst_count;
    integer conv1_backpressure_count;
    integer conv2_backpressure_count;
    integer ready_wait_count;
    integer channel_index;
    integer error_count;
    integer unknown_count;
    reg conv1_burst_started;
    reg conv2_second_burst_started;
    reg conv2_gap_seen;
    reg simulation_pass;
    reg simulation_fail;
    reg simulation_complete;
    convolution_four_lane_datapath #(
        .INPUT_CHANNELS(3),
        .MIN_GROUP_CYCLES(4),
        .SCALE_MULT(1301962),
        .SCALE_SHIFT(30)
    ) conv1_dut (
        .clk(clk),
        .reset(conv1_reset),
        .input_valid(input_valid),
        .input_ready(conv1_input_ready),
        .first_input_channel(first_input_channel),
        .last_input_channel(last_input_channel),
        .input_value_0(input_value_0),
        .input_value_1(input_value_1),
        .input_value_2(input_value_2),
        .input_value_3(input_value_3),
        .input_value_4(input_value_4),
        .input_value_5(input_value_5),
        .input_value_6(input_value_6),
        .input_value_7(input_value_7),
        .input_value_8(input_value_8),
        .weight_lane_0_value_0(weight_lane_0_value_0),
        .weight_lane_0_value_1(weight_lane_0_value_1),
        .weight_lane_0_value_2(weight_lane_0_value_2),
        .weight_lane_0_value_3(weight_lane_0_value_3),
        .weight_lane_0_value_4(weight_lane_0_value_4),
        .weight_lane_0_value_5(weight_lane_0_value_5),
        .weight_lane_0_value_6(weight_lane_0_value_6),
        .weight_lane_0_value_7(weight_lane_0_value_7),
        .weight_lane_0_value_8(weight_lane_0_value_8),
        .weight_lane_1_value_0(weight_lane_1_value_0),
        .weight_lane_1_value_1(weight_lane_1_value_1),
        .weight_lane_1_value_2(weight_lane_1_value_2),
        .weight_lane_1_value_3(weight_lane_1_value_3),
        .weight_lane_1_value_4(weight_lane_1_value_4),
        .weight_lane_1_value_5(weight_lane_1_value_5),
        .weight_lane_1_value_6(weight_lane_1_value_6),
        .weight_lane_1_value_7(weight_lane_1_value_7),
        .weight_lane_1_value_8(weight_lane_1_value_8),
        .weight_lane_2_value_0(weight_lane_2_value_0),
        .weight_lane_2_value_1(weight_lane_2_value_1),
        .weight_lane_2_value_2(weight_lane_2_value_2),
        .weight_lane_2_value_3(weight_lane_2_value_3),
        .weight_lane_2_value_4(weight_lane_2_value_4),
        .weight_lane_2_value_5(weight_lane_2_value_5),
        .weight_lane_2_value_6(weight_lane_2_value_6),
        .weight_lane_2_value_7(weight_lane_2_value_7),
        .weight_lane_2_value_8(weight_lane_2_value_8),
        .weight_lane_3_value_0(weight_lane_3_value_0),
        .weight_lane_3_value_1(weight_lane_3_value_1),
        .weight_lane_3_value_2(weight_lane_3_value_2),
        .weight_lane_3_value_3(weight_lane_3_value_3),
        .weight_lane_3_value_4(weight_lane_3_value_4),
        .weight_lane_3_value_5(weight_lane_3_value_5),
        .weight_lane_3_value_6(weight_lane_3_value_6),
        .weight_lane_3_value_7(weight_lane_3_value_7),
        .weight_lane_3_value_8(weight_lane_3_value_8),
        .bias_value_0(bias_value_0),
        .bias_value_1(bias_value_1),
        .bias_value_2(bias_value_2),
        .bias_value_3(bias_value_3),
        .output_value(conv1_output_value),
        .output_lane_index(conv1_output_lane_index),
        .output_valid(conv1_output_valid),
        .requantize_busy(conv1_requantize_busy)
    );
    convolution_four_lane_datapath #(
        .INPUT_CHANNELS(16),
        .MIN_GROUP_CYCLES(4),
        .SCALE_MULT(1516810),
        .SCALE_SHIFT(30)
    ) conv2_dut (
        .clk(clk),
        .reset(conv2_reset),
        .input_valid(input_valid),
        .input_ready(conv2_input_ready),
        .first_input_channel(first_input_channel),
        .last_input_channel(last_input_channel),
        .input_value_0(input_value_0),
        .input_value_1(input_value_1),
        .input_value_2(input_value_2),
        .input_value_3(input_value_3),
        .input_value_4(input_value_4),
        .input_value_5(input_value_5),
        .input_value_6(input_value_6),
        .input_value_7(input_value_7),
        .input_value_8(input_value_8),
        .weight_lane_0_value_0(weight_lane_0_value_0),
        .weight_lane_0_value_1(weight_lane_0_value_1),
        .weight_lane_0_value_2(weight_lane_0_value_2),
        .weight_lane_0_value_3(weight_lane_0_value_3),
        .weight_lane_0_value_4(weight_lane_0_value_4),
        .weight_lane_0_value_5(weight_lane_0_value_5),
        .weight_lane_0_value_6(weight_lane_0_value_6),
        .weight_lane_0_value_7(weight_lane_0_value_7),
        .weight_lane_0_value_8(weight_lane_0_value_8),
        .weight_lane_1_value_0(weight_lane_1_value_0),
        .weight_lane_1_value_1(weight_lane_1_value_1),
        .weight_lane_1_value_2(weight_lane_1_value_2),
        .weight_lane_1_value_3(weight_lane_1_value_3),
        .weight_lane_1_value_4(weight_lane_1_value_4),
        .weight_lane_1_value_5(weight_lane_1_value_5),
        .weight_lane_1_value_6(weight_lane_1_value_6),
        .weight_lane_1_value_7(weight_lane_1_value_7),
        .weight_lane_1_value_8(weight_lane_1_value_8),
        .weight_lane_2_value_0(weight_lane_2_value_0),
        .weight_lane_2_value_1(weight_lane_2_value_1),
        .weight_lane_2_value_2(weight_lane_2_value_2),
        .weight_lane_2_value_3(weight_lane_2_value_3),
        .weight_lane_2_value_4(weight_lane_2_value_4),
        .weight_lane_2_value_5(weight_lane_2_value_5),
        .weight_lane_2_value_6(weight_lane_2_value_6),
        .weight_lane_2_value_7(weight_lane_2_value_7),
        .weight_lane_2_value_8(weight_lane_2_value_8),
        .weight_lane_3_value_0(weight_lane_3_value_0),
        .weight_lane_3_value_1(weight_lane_3_value_1),
        .weight_lane_3_value_2(weight_lane_3_value_2),
        .weight_lane_3_value_3(weight_lane_3_value_3),
        .weight_lane_3_value_4(weight_lane_3_value_4),
        .weight_lane_3_value_5(weight_lane_3_value_5),
        .weight_lane_3_value_6(weight_lane_3_value_6),
        .weight_lane_3_value_7(weight_lane_3_value_7),
        .weight_lane_3_value_8(weight_lane_3_value_8),
        .bias_value_0(bias_value_0),
        .bias_value_1(bias_value_1),
        .bias_value_2(bias_value_2),
        .bias_value_3(bias_value_3),
        .output_value(conv2_output_value),
        .output_lane_index(conv2_output_lane_index),
        .output_valid(conv2_output_valid),
        .requantize_busy(conv2_requantize_busy)
    );
    initial begin
        clk = 1'b0;

        repeat (MAX_HALF_CYCLES) begin
            #(CLOCK_PERIOD / 2);
            clk = ~clk;
        end
        if (!simulation_complete) begin
            error_count = error_count + 1;
            $display("================================================");
            $display("FAIL: TESTBENCH TIMEOUT");
            $display("Conv1 outputs = %0d", conv1_output_count);
            $display("Conv2 outputs = %0d", conv2_output_count);
            $display("Total errors  = %0d", error_count);
            $display("================================================");
        end
        $finish;
    end
    always @(posedge clk) begin
        #1;
        if (!conv1_reset) begin
            if (
                (conv1_input_ready !== 1'b0) &&
                (conv1_input_ready !== 1'b1)
            ) begin
                unknown_count = unknown_count + 1;
                error_count   = error_count + 1;

                $display(
                    "ERROR: Conv1 input_ready contains X/Z."
                );
            end
            if (
                (conv1_requantize_busy !== 1'b0) &&
                (conv1_requantize_busy !== 1'b1)
            ) begin
                unknown_count = unknown_count + 1;
                error_count   = error_count + 1;

                $display(
                    "ERROR: Conv1 requantize_busy contains X/Z."
                );
            end
            if (
                (conv1_output_valid !== 1'b0) &&
                (conv1_output_valid !== 1'b1)
            ) begin
                unknown_count = unknown_count + 1;
                error_count   = error_count + 1;
                $display(
                    "ERROR: Conv1 output_valid contains X/Z."
                );
            end
            if (
                conv1_burst_started &&
                (conv1_output_count < CONV1_EXPECTED_OUTPUTS) &&
                (conv1_output_valid !== 1'b1)
            ) begin
                error_count = error_count + 1;
                $display(
                    "ERROR: Bubble detected inside the Conv1 eight-output burst at count %0d.",
                    conv1_output_count
                );
            end
            if (conv1_output_valid === 1'b1) begin
                conv1_burst_started = 1'b1;
                if (
                    conv1_output_count >=
                    CONV1_EXPECTED_OUTPUTS
                ) begin
                    error_count = error_count + 1;

                    $display(
                        "ERROR: Unexpected extra Conv1 output."
                    );
                end else if (
                    ((^conv1_output_value) === 1'bx) ||
                    ((^conv1_output_lane_index) === 1'bx)
                ) begin
                    unknown_count = unknown_count + 1;
                    error_count   = error_count + 1;
                    $display(
                        "ERROR: Conv1 output %0d contains X/Z.",
                        conv1_output_count
                    );
                end else begin
                    if (
                        conv1_output_value !==
                        expected_conv1_value[conv1_output_count]
                    ) begin
                        error_count = error_count + 1;
                        $display(
                            "ERROR: Conv1 output=%0d expected=%0d received=%0d",
                            conv1_output_count,
                            expected_conv1_value[
                                conv1_output_count
                            ],
                            conv1_output_value
                        );
                    end
                    if (
                        conv1_output_lane_index !==
                        (conv1_output_count % 4)
                    ) begin
                        error_count = error_count + 1;
                        $display(
                            "ERROR: Conv1 output=%0d lane expected=%0d received=%0d",
                            conv1_output_count,
                            (conv1_output_count % 4),
                            conv1_output_lane_index
                        );
                    end
                    if (
                        (conv1_output_value ===
                         expected_conv1_value[
                             conv1_output_count
                         ]) &&
                        (conv1_output_lane_index ===
                         (conv1_output_count % 4))
                    ) begin
                        $display(
                            "PASS: Conv1 output %0d value=%0d lane=%0d",
                            conv1_output_count,
                            conv1_output_value,
                            conv1_output_lane_index
                        );
                    end
                end
                conv1_output_count =
                    conv1_output_count + 1;
                conv1_continuous_count =
                    conv1_continuous_count + 1;
            end
        end
        if (!conv2_reset) begin
            if (
                (conv2_input_ready !== 1'b0) &&
                (conv2_input_ready !== 1'b1)
            ) begin
                unknown_count = unknown_count + 1;
                error_count   = error_count + 1;
                $display(
                    "ERROR: Conv2 input_ready contains X/Z."
                );
            end
            if (
                (conv2_requantize_busy !== 1'b0) &&
                (conv2_requantize_busy !== 1'b1)
            ) begin
                unknown_count = unknown_count + 1;
                error_count   = error_count + 1;
                $display(
                    "ERROR: Conv2 requantize_busy contains X/Z."
                );
            end
            if (
                (conv2_output_valid !== 1'b0) &&
                (conv2_output_valid !== 1'b1)
            ) begin
                unknown_count = unknown_count + 1;
                error_count   = error_count + 1;
                $display(
                    "ERROR: Conv2 output_valid contains X/Z."
                );
            end
            if (
                (conv2_output_count > 0) &&
                (conv2_output_count < 4) &&
                (conv2_output_valid !== 1'b1)
            ) begin
                error_count = error_count + 1;

                $display(
                    "ERROR: Bubble detected inside the first Conv2 four-output burst."
                );
            end
            if (
                conv2_second_burst_started &&
                (conv2_output_count < CONV2_EXPECTED_OUTPUTS) &&
                (conv2_output_valid !== 1'b1)
            ) begin
                error_count = error_count + 1;

                $display(
                    "ERROR: Bubble detected inside the second Conv2 four-output burst."
                );
            end
            if (
                (conv2_output_count == 4) &&
                (conv2_output_valid !== 1'b1)
            ) begin
                conv2_gap_seen = 1'b1;
            end
            if (conv2_output_valid === 1'b1) begin
                if (
                    conv2_output_count >=
                    CONV2_EXPECTED_OUTPUTS
                ) begin
                    error_count = error_count + 1;
                    $display(
                        "ERROR: Unexpected extra Conv2 output."
                    );
                end else begin
                    if (
                        (conv2_output_count == 4) &&
                        !conv2_gap_seen
                    ) begin
                        error_count = error_count + 1;
                        $display(
                            "ERROR: No output gap was observed between the two Conv2 groups."
                        );
                    end
                    if (conv2_output_count == 4) begin
                        conv2_second_burst_started = 1'b1;
                    end
                    if (
                        ((^conv2_output_value) === 1'bx) ||
                        ((^conv2_output_lane_index) === 1'bx)
                    ) begin
                        unknown_count = unknown_count + 1;
                        error_count   = error_count + 1;
                        $display(
                            "ERROR: Conv2 output %0d contains X/Z.",
                            conv2_output_count
                        );
                    end else begin
                        if (
                            conv2_output_value !==
                            expected_conv2_value[
                                conv2_output_count
                            ]
                        ) begin
                            error_count = error_count + 1;
                            $display(
                                "ERROR: Conv2 output=%0d expected=%0d received=%0d",
                                conv2_output_count,
                                expected_conv2_value[
                                    conv2_output_count
                                ],
                                conv2_output_value
                            );
                        end
                        if (
                            conv2_output_lane_index !==
                            (conv2_output_count % 4)
                        ) begin
                            error_count = error_count + 1;
                            $display(
                                "ERROR: Conv2 output=%0d lane expected=%0d received=%0d",
                                conv2_output_count,
                                (conv2_output_count % 4),
                                conv2_output_lane_index
                            );
                        end
                        if (
                            (conv2_output_value ===
                             expected_conv2_value[
                                 conv2_output_count
                             ]) &&
                            (conv2_output_lane_index ===
                             (conv2_output_count % 4))
                        ) begin
                            $display(
                                "PASS: Conv2 output %0d value=%0d lane=%0d",
                                conv2_output_count,
                                conv2_output_value,
                                conv2_output_lane_index
                            );
                        end
                    end
                    if (conv2_output_count < 4) begin
                        conv2_first_burst_count =
                            conv2_first_burst_count + 1;
                    end else begin
                        conv2_second_burst_count =
                            conv2_second_burst_count + 1;
                    end
                end
                conv2_output_count =
                    conv2_output_count + 1;
            end
        end
    end
    task set_constant_window;
        input signed [7:0] value;
        begin
            input_value_0 = value;
            input_value_1 = value;
            input_value_2 = value;
            input_value_3 = value;
            input_value_4 = value;
            input_value_5 = value;
            input_value_6 = value;
            input_value_7 = value;
            input_value_8 = value;
        end
    endtask
    task set_constant_lane_weights;
        input signed [7:0] lane_0_value;
        input signed [7:0] lane_1_value;
        input signed [7:0] lane_2_value;
        input signed [7:0] lane_3_value;
        begin
            weight_lane_0_value_0 = lane_0_value;
            weight_lane_0_value_1 = lane_0_value;
            weight_lane_0_value_2 = lane_0_value;
            weight_lane_0_value_3 = lane_0_value;
            weight_lane_0_value_4 = lane_0_value;
            weight_lane_0_value_5 = lane_0_value;
            weight_lane_0_value_6 = lane_0_value;
            weight_lane_0_value_7 = lane_0_value;
            weight_lane_0_value_8 = lane_0_value;
            weight_lane_1_value_0 = lane_1_value;
            weight_lane_1_value_1 = lane_1_value;
            weight_lane_1_value_2 = lane_1_value;
            weight_lane_1_value_3 = lane_1_value;
            weight_lane_1_value_4 = lane_1_value;
            weight_lane_1_value_5 = lane_1_value;
            weight_lane_1_value_6 = lane_1_value;
            weight_lane_1_value_7 = lane_1_value;
            weight_lane_1_value_8 = lane_1_value;
            weight_lane_2_value_0 = lane_2_value;
            weight_lane_2_value_1 = lane_2_value;
            weight_lane_2_value_2 = lane_2_value;
            weight_lane_2_value_3 = lane_2_value;
            weight_lane_2_value_4 = lane_2_value;
            weight_lane_2_value_5 = lane_2_value;
            weight_lane_2_value_6 = lane_2_value;
            weight_lane_2_value_7 = lane_2_value;
            weight_lane_2_value_8 = lane_2_value;
            weight_lane_3_value_0 = lane_3_value;
            weight_lane_3_value_1 = lane_3_value;
            weight_lane_3_value_2 = lane_3_value;
            weight_lane_3_value_3 = lane_3_value;
            weight_lane_3_value_4 = lane_3_value;
            weight_lane_3_value_5 = lane_3_value;
            weight_lane_3_value_6 = lane_3_value;
            weight_lane_3_value_7 = lane_3_value;
            weight_lane_3_value_8 = lane_3_value;
        end
    endtask
    task set_lane_1_alternating;
        begin
            weight_lane_1_value_0 = 8'sd1;
            weight_lane_1_value_1 = -8'sd1;
            weight_lane_1_value_2 = 8'sd1;
            weight_lane_1_value_3 = -8'sd1;
            weight_lane_1_value_4 = 8'sd1;
            weight_lane_1_value_5 = -8'sd1;
            weight_lane_1_value_6 = 8'sd1;
            weight_lane_1_value_7 = -8'sd1;
            weight_lane_1_value_8 = 8'sd1;
        end
    endtask
    task set_lane_2_alternating;
        begin
            weight_lane_2_value_0 = 8'sd1;
            weight_lane_2_value_1 = -8'sd1;
            weight_lane_2_value_2 = 8'sd1;
            weight_lane_2_value_3 = -8'sd1;
            weight_lane_2_value_4 = 8'sd1;
            weight_lane_2_value_5 = -8'sd1;
            weight_lane_2_value_6 = 8'sd1;
            weight_lane_2_value_7 = -8'sd1;
            weight_lane_2_value_8 = 8'sd1;
        end
    endtask
    task set_conv1_channel;
        input integer group_number;
        input integer input_channel_number;
        begin
            if (group_number == 0) begin
                case (input_channel_number)
                    0: begin
                        input_value_0 = 8'sd1;
                        input_value_1 = 8'sd2;
                        input_value_2 = 8'sd3;
                        input_value_3 = 8'sd4;
                        input_value_4 = 8'sd5;
                        input_value_5 = 8'sd6;
                        input_value_6 = 8'sd7;
                        input_value_7 = 8'sd8;
                        input_value_8 = 8'sd9;
                        set_constant_lane_weights(
                            8'sd1,
                            8'sd1,
                            8'sd2,
                            -8'sd2
                        );
                        set_lane_1_alternating;
                        bias_value_0 = 32'sd40000;
                        bias_value_1 = -32'sd10000;
                        bias_value_2 = 32'sd60000;
                        bias_value_3 = 32'sd100000;
                    end
                    1: begin
                        input_value_0 = 8'sd9;
                        input_value_1 = 8'sd8;
                        input_value_2 = 8'sd7;
                        input_value_3 = 8'sd6;
                        input_value_4 = 8'sd5;
                        input_value_5 = 8'sd4;
                        input_value_6 = 8'sd3;
                        input_value_7 = 8'sd2;
                        input_value_8 = 8'sd1;
                        set_constant_lane_weights(
                            8'sd2,
                            8'sd1,
                            -8'sd1,
                            8'sd1
                        );
                        set_lane_1_alternating;
                        bias_value_0 = 32'sd111111;
                        bias_value_1 = -32'sd222222;
                        bias_value_2 = 32'sd333333;
                        bias_value_3 = -32'sd444444;
                    end
                    default: begin
                        input_value_0 = -8'sd1;
                        input_value_1 = -8'sd2;
                        input_value_2 = -8'sd3;
                        input_value_3 = -8'sd4;
                        input_value_4 = -8'sd5;
                        input_value_5 = -8'sd6;
                        input_value_6 = -8'sd7;
                        input_value_7 = -8'sd8;
                        input_value_8 = -8'sd9;
                        set_constant_lane_weights(
                            -8'sd1,
                            8'sd1,
                            8'sd1,
                            -8'sd2
                        );
                        set_lane_2_alternating;
                        bias_value_0 = -32'sd555555;
                        bias_value_1 = 32'sd666666;
                        bias_value_2 = -32'sd777777;
                        bias_value_3 = 32'sd888888;
                    end
                endcase
            end else begin
                case (input_channel_number)
                    0: begin
                        set_constant_window(8'sd10);
                        set_constant_lane_weights(
                            8'sd3,
                            -8'sd2,
                            8'sd1,
                            8'sd4
                        );
                        bias_value_0 = 32'sd104300;
                        bias_value_1 = 32'sd1000;
                        bias_value_2 = -32'sd500;
                        bias_value_3 = 32'sd70000;
                    end
                    1: begin
                        set_constant_window(-8'sd5);
                        set_constant_lane_weights(
                            8'sd4,
                            8'sd3,
                            -8'sd2,
                            8'sd1
                        );
                        bias_value_0 = 32'sd123456;
                        bias_value_1 = 32'sd234567;
                        bias_value_2 = 32'sd345678;
                        bias_value_3 = 32'sd456789;
                    end
                    default: begin
                        set_constant_window(8'sd7);
                        set_constant_lane_weights(
                            -8'sd1,
                            8'sd2,
                            8'sd3,
                            -8'sd4
                        );
                        bias_value_0 = -32'sd654321;
                        bias_value_1 = -32'sd765432;
                        bias_value_2 = -32'sd876543;
                        bias_value_3 = -32'sd987654;
                    end
                endcase
            end
        end
    endtask
    task send_conv1_channel;
        input integer group_number;
        input integer input_channel_number;
        begin
            @(negedge clk);
            set_conv1_channel(
                group_number,
                input_channel_number
            );
            input_valid =
                1'b1;
            first_input_channel =
                (input_channel_number == 0);
            last_input_channel =
                (input_channel_number == 2);
            ready_wait_count = 0;
            while (
                (conv1_input_ready !== 1'b1) &&
                (ready_wait_count < 8)
            ) begin
                conv1_backpressure_count =
                    conv1_backpressure_count + 1;
                @(posedge clk);
                @(negedge clk);
                ready_wait_count =
                    ready_wait_count + 1;
            end
            if (conv1_input_ready !== 1'b1) begin
                error_count = error_count + 1;
                $display(
                    "ERROR: Conv1 timed out waiting for input_ready at group=%0d channel=%0d.",
                    group_number,
                    input_channel_number
                );
            end else begin
                @(posedge clk);
                conv1_accepted_channels =
                    conv1_accepted_channels + 1;
            end
        end
    endtask
    task set_conv2_channel;
        input integer group_number;
        input integer input_channel_number;
        reg signed [7:0] channel_value;
        begin
            if (group_number == 0) begin
                channel_value =
                    input_channel_number + 1;

                set_constant_window(
                    channel_value
                );
                set_constant_lane_weights(
                    8'sd1,
                    -8'sd1,
                    8'sd2,
                    -8'sd2
                );
                if (input_channel_number == 0) begin
                    bias_value_0 = 32'sd50000;
                    bias_value_1 = 32'sd90000;
                    bias_value_2 = 32'sd70000;
                    bias_value_3 = 32'sd110000;
                end else begin
                    bias_value_0 =
                        32'sd100000 + input_channel_number;
                    bias_value_1 =
                        -32'sd200000 - input_channel_number;
                    bias_value_2 =
                        32'sd300000 + input_channel_number;
                    bias_value_3 =
                        -32'sd400000 - input_channel_number;
                end
            end else begin
                channel_value =
                    -(input_channel_number + 1);

                set_constant_window(
                    channel_value
                );
                set_constant_lane_weights(
                    8'sd1,
                    -8'sd1,
                    8'sd2,
                    -8'sd2
                );
                if (input_channel_number == 0) begin
                    bias_value_0 = 32'sd100000;
                    bias_value_1 = 32'sd0;
                    bias_value_2 = 32'sd60000;
                    bias_value_3 = 32'sd80000;
                end else begin
                    bias_value_0 =
                        -32'sd500000 - input_channel_number;
                    bias_value_1 =
                        32'sd600000 + input_channel_number;
                    bias_value_2 =
                        -32'sd700000 - input_channel_number;
                    bias_value_3 =
                        32'sd800000 + input_channel_number;
                end
            end
        end
    endtask
    task send_conv2_channel;
        input integer group_number;
        input integer input_channel_number;
        begin
            @(negedge clk);
            set_conv2_channel(
                group_number,
                input_channel_number
            );
            input_valid =
                1'b1;
            first_input_channel =
                (input_channel_number == 0);
            last_input_channel =
                (input_channel_number == 15);
            ready_wait_count = 0;
            while (
                (conv2_input_ready !== 1'b1) &&
                (ready_wait_count < 8)
            ) begin
                conv2_backpressure_count =
                    conv2_backpressure_count + 1;
                @(posedge clk);
                @(negedge clk);
                ready_wait_count =
                    ready_wait_count + 1;
            end
            if (conv2_input_ready !== 1'b1) begin
                error_count = error_count + 1;
                $display(
                    "ERROR: Conv2 timed out waiting for input_ready at group=%0d channel=%0d.",
                    group_number,
                    input_channel_number
                );
            end else begin
                @(posedge clk);
                conv2_accepted_channels =
                    conv2_accepted_channels + 1;
            end
        end
    endtask
    initial begin
        expected_conv1_value[0] = 8'sd49;
        expected_conv1_value[1] = 8'sd0;
        expected_conv1_value[2] = 8'sd73;
        expected_conv1_value[3] = 8'sd121;
        expected_conv1_value[4] = 8'sd127;
        expected_conv1_value[5] = 8'sd1;
        expected_conv1_value[6] = 8'sd0;
        expected_conv1_value[7] = 8'sd85;
        expected_conv2_value[0] = 8'sd72;
        expected_conv2_value[1] = 8'sd125;
        expected_conv2_value[2] = 8'sd102;
        expected_conv2_value[3] = 8'sd127;
        expected_conv2_value[4] = 8'sd127;
        expected_conv2_value[5] = 8'sd2;
        expected_conv2_value[6] = 8'sd81;
        expected_conv2_value[7] = 8'sd116;
    end
    initial begin
        conv1_reset = 1'b1;
        conv2_reset = 1'b1;
        input_valid         = 1'b0;
        first_input_channel = 1'b0;
        last_input_channel  = 1'b0;
        input_value_0 = 8'sd0;
        input_value_1 = 8'sd0;
        input_value_2 = 8'sd0;
        input_value_3 = 8'sd0;
        input_value_4 = 8'sd0;
        input_value_5 = 8'sd0;
        input_value_6 = 8'sd0;
        input_value_7 = 8'sd0;
        input_value_8 = 8'sd0;
        set_constant_lane_weights(
            8'sd0,
            8'sd0,
            8'sd0,
            8'sd0
        );
        bias_value_0 = 32'sd0;
        bias_value_1 = 32'sd0;
        bias_value_2 = 32'sd0;
        bias_value_3 = 32'sd0;
        conv1_accepted_channels = 0;
        conv2_accepted_channels = 0;
        conv1_output_count      = 0;
        conv2_output_count      = 0;
        conv1_continuous_count  = 0;
        conv2_first_burst_count = 0;
        conv2_second_burst_count = 0;
        conv1_backpressure_count = 0;
        conv2_backpressure_count = 0;
        ready_wait_count        = 0;
        channel_index           = 0;
        error_count             = 0;
        unknown_count           = 0;
        conv1_burst_started       = 1'b0;
        conv2_second_burst_started = 1'b0;
        conv2_gap_seen            = 1'b0;
        simulation_pass     = 1'b0;
        simulation_fail     = 1'b0;
        simulation_complete = 1'b0;
        repeat (5) @(posedge clk);
        // Verify the actual three-channel Conv1 configuration.
        @(negedge clk);
        conv1_reset = 1'b0;
        conv2_reset = 1'b1;
        send_conv1_channel(0, 0);
        send_conv1_channel(0, 1);
        send_conv1_channel(0, 2);
        send_conv1_channel(1, 0);
        send_conv1_channel(1, 1);
        send_conv1_channel(1, 2);
        @(negedge clk);
        input_valid         = 1'b0;
        first_input_channel = 1'b0;
        last_input_channel  = 1'b0;
        repeat (25) @(posedge clk);
        #2;
        if (conv1_accepted_channels != 6) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv1 expected 6 accepted channel transactions but observed %0d.",
                conv1_accepted_channels
            );
        end
        if (
            conv1_output_count !=
            CONV1_EXPECTED_OUTPUTS
        ) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv1 expected %0d final outputs but observed %0d.",
                CONV1_EXPECTED_OUTPUTS,
                conv1_output_count
            );
        end
        if (
            conv1_continuous_count !=
            CONV1_EXPECTED_OUTPUTS
        ) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv1 expected %0d continuous outputs but observed %0d.",
                CONV1_EXPECTED_OUTPUTS,
                conv1_continuous_count
            );
        end
        if (conv1_backpressure_count != 1) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv1 expected exactly 1 cadence backpressure cycle but observed %0d.",
                conv1_backpressure_count
            );
        end
        if (conv1_requantize_busy !== 1'b0) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv1 requantization subsystem remained busy after draining."
            );
        end
        // Reset both datapaths before the Conv2 experiment.
        @(negedge clk);
        conv1_reset = 1'b1;
        conv2_reset = 1'b1;
        input_valid         = 1'b0;
        first_input_channel = 1'b0;
        last_input_channel  = 1'b0;
        repeat (5) @(posedge clk);
        // Verify the actual sixteen-channel Conv2 configuration.
        @(negedge clk);
        conv1_reset = 1'b1;
        conv2_reset = 1'b0;
        for (
            channel_index = 0;
            channel_index < 16;
            channel_index = channel_index + 1
        ) begin
            send_conv2_channel(
                0,
                channel_index
            );
        end
        for (
            channel_index = 0;
            channel_index < 16;
            channel_index = channel_index + 1
        ) begin
            send_conv2_channel(
                1,
                channel_index
            );
        end
        @(negedge clk);
        input_valid         = 1'b0;
        first_input_channel = 1'b0;
        last_input_channel  = 1'b0;
        repeat (30) @(posedge clk);
        #2;
        if (conv2_accepted_channels != 32) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv2 expected 32 accepted channel transactions but observed %0d.",
                conv2_accepted_channels
            );
        end
        if (
            conv2_output_count !=
            CONV2_EXPECTED_OUTPUTS
        ) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv2 expected %0d final outputs but observed %0d.",
                CONV2_EXPECTED_OUTPUTS,
                conv2_output_count
            );
        end
        if (conv2_first_burst_count != 4) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv2 first group expected 4 outputs but observed %0d.",
                conv2_first_burst_count
            );
        end
        if (conv2_second_burst_count != 4) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv2 second group expected 4 outputs but observed %0d.",
                conv2_second_burst_count
            );
        end
        if (!conv2_gap_seen) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Expected Conv2 output gap between the two 16-channel groups was not observed."
            );
        end
        if (conv2_backpressure_count != 0) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv2 unexpectedly experienced %0d backpressure cycles.",
                conv2_backpressure_count
            );
        end
        if (conv2_requantize_busy !== 1'b0) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv2 requantization subsystem remained busy after draining."
            );
        end
        if (conv2_input_ready !== 1'b1) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Conv2 was not ready at the end of the test."
            );
        end
        $display("================================================");
        $display("Candidate-A convolution datapath verification complete");
        $display("Conv1 accepted channels     = %0d", conv1_accepted_channels);
        $display("Conv1 final outputs         = %0d", conv1_output_count);
        $display("Conv1 continuous outputs    = %0d", conv1_continuous_count);
        $display("Conv1 backpressure cycles   = %0d", conv1_backpressure_count);
        $display("Conv2 accepted channels     = %0d", conv2_accepted_channels);
        $display("Conv2 final outputs         = %0d", conv2_output_count);
        $display("Conv2 first burst outputs   = %0d", conv2_first_burst_count);
        $display("Conv2 second burst outputs  = %0d", conv2_second_burst_count);
        $display("Conv2 backpressure cycles   = %0d", conv2_backpressure_count);
        $display("Conv2 output gap observed   = %0d", conv2_gap_seen);
        $display("X/Z errors                  = %0d", unknown_count);
        $display("Total errors                = %0d", error_count);
        $display("================================================");
        if (error_count == 0) begin
            simulation_pass = 1'b1;
            $display(
                "PASS: Candidate-A Conv1 and Conv2 datapaths produced exact final int8 results from full 3x3 convolution inputs."
            );
        end else begin
            simulation_fail = 1'b1;
            $display(
                "FAIL: Candidate-A convolution datapath verification found %0d errors.",
                error_count
            );
        end
        simulation_complete = 1'b1;
        #20;
        $finish;
    end
endmodule

`default_nettype wire