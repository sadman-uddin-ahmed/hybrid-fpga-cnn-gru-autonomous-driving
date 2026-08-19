`timescale 1ns / 1ps
`default_nettype none

module cnn_feature_streaming_latency_monitor_tb;

    localparam integer BOARD_CLOCK_PERIOD_NS       = 10;
    localparam integer CORE_CLOCK_PERIOD_NS        = 20;
    localparam integer FRAME_COUNT                 = 4;
    localparam integer PADDED_INPUTS_PER_FRAME     = 13068;
    localparam integer FEATURES_PER_FRAME          = 8192;
    localparam integer TOTAL_PADDED_INPUTS         = 52272;
    localparam integer TOTAL_FEATURES              = 32768;

    localparam [3:0] STATE_IDLE                    = 4'd0;
    localparam [3:0] STATE_CAPTURE_RESET           = 4'd1;
    localparam [3:0] STATE_LOAD_CONV1_WEIGHT       = 4'd2;
    localparam [3:0] STATE_LOAD_CONV1_BIAS         = 4'd3;
    localparam [3:0] STATE_LOAD_CONV2_WEIGHT       = 4'd4;
    localparam [3:0] STATE_LOAD_CONV2_BIAS         = 4'd5;
    localparam [3:0] STATE_FRAME_PREP              = 4'd6;
    localparam [3:0] STATE_STREAM_REQUEST          = 4'd7;
    localparam [3:0] STATE_STREAM_ROM_WAIT         = 4'd8;
    localparam [3:0] STATE_STREAM_SEND             = 4'd9;
    localparam [3:0] STATE_WAIT_FRAME_DONE         = 4'd10;
    localparam [3:0] STATE_WAIT_CAPTURE_DONE       = 4'd11;
    localparam [3:0] STATE_RESULT_HOLD             = 4'd12;

    reg clk;
    reg reset_button;
    reg start_button;

    wire [7:0] led;

    wire led_done;
    wire led_busy;
    wire led_started;
    wire led_pass;
    wire led_fail;

    wire raw_cnn_output_valid;

    reg signed [7:0] expected_frame_0
        [0:FEATURES_PER_FRAME-1];
    reg signed [7:0] expected_frame_1
        [0:FEATURES_PER_FRAME-1];
    reg signed [7:0] expected_frame_2
        [0:FEATURES_PER_FRAME-1];
    reg signed [7:0] expected_frame_3
        [0:FEATURES_PER_FRAME-1];

    reg [FEATURES_PER_FRAME-1:0] seen_frame_0;
    reg [FEATURES_PER_FRAME-1:0] seen_frame_1;
    reg [FEATURES_PER_FRAME-1:0] seen_frame_2;
    reg [FEATURES_PER_FRAME-1:0] seen_frame_3;

    integer expected_vector_checks;
    integer expected_vector_mismatches;
    integer duplicate_address_errors;
    integer feature_address_errors;
    integer feature_xz_errors;
    integer missing_address_errors;

    integer error_count;
    integer frame_index;

    integer accepted_input_count;
    integer raw_cnn_feature_count;
    integer reordered_feature_count;
    integer frame_done_count;

    integer frame_accepted_input_count [0:FRAME_COUNT-1];
    integer frame_raw_feature_count     [0:FRAME_COUNT-1];
    integer frame_reordered_count       [0:FRAME_COUNT-1];

    time frame_first_input_time         [0:FRAME_COUNT-1];
    time frame_last_input_time          [0:FRAME_COUNT-1];
    time frame_first_raw_time           [0:FRAME_COUNT-1];
    time frame_last_raw_time            [0:FRAME_COUNT-1];
    time frame_done_time                [0:FRAME_COUNT-1];

    reg frame_first_input_seen          [0:FRAME_COUNT-1];
    reg frame_first_raw_seen            [0:FRAME_COUNT-1];

    reg latency_active;
    reg runtime_error_seen;

    integer core_cycle_count;
    integer capture_reset_cycles;
    integer conv1_weight_load_cycles;
    integer conv1_bias_load_cycles;
    integer conv2_weight_load_cycles;
    integer conv2_bias_load_cycles;
    integer frame_prep_cycles;
    integer stream_request_cycles;
    integer stream_rom_wait_cycles;
    integer stream_send_cycles;
    integer input_stall_cycles;
    integer wait_frame_done_cycles;
    integer wait_capture_done_cycles;

    integer conv1_requantize_busy_cycles;
    integer conv2_requantize_busy_cycles;
    integer reorder_capture_busy_cycles;
    integer reorder_drain_busy_cycles;

    time start_time_ns;
    time done_time_ns;
    time total_latency_ns;
    time startup_to_first_input_ns;
    time final_capture_tail_ns;

    integer total_core_cycles;

    real total_latency_ms;
    real average_latency_per_frame_ms;
    real measured_throughput_fps;

    real stage06_four_frame_ms;
    real stage06_average_frame_ms;
    real stage06_throughput_fps;

    real latency_speedup;
    real frame_latency_speedup;
    real throughput_gain;
    real latency_reduction_percent;

    real parameter_load_ms;
    real feeder_control_ms;
    real feeder_stall_ms;

    initial begin
        $readmemh(
            "sequence_000_frame_0_expected.mem",
            expected_frame_0
        );

        $readmemh(
            "sequence_000_frame_1_expected.mem",
            expected_frame_1
        );

        $readmemh(
            "sequence_000_frame_2_expected.mem",
            expected_frame_2
        );

        $readmemh(
            "sequence_000_frame_3_expected.mem",
            expected_frame_3
        );
    end

    cnn_feature_streaming_nexys_video_top dut (
        .clk(clk),
        .reset_button(reset_button),
        .start_button(start_button),
        .led(led)
    );

    assign led_done    = led[0];
    assign led_busy    = led[1];
    assign led_started = led[2];
    assign led_pass    = led[3];
    assign led_fail    = led[4];

    assign raw_cnn_output_valid =
        dut.cnn_temporal_inst
           .feature_vector_extractor_inst
           .cnn_output_valid;

    always #(BOARD_CLOCK_PERIOD_NS / 2) begin
        clk = ~clk;
    end

    always @(posedge dut.cnn_core_clk) begin
        if (latency_active) begin
            core_cycle_count <= core_cycle_count + 1;

            case (dut.current_state)
                STATE_CAPTURE_RESET:
                    capture_reset_cycles <=
                        capture_reset_cycles + 1;

                STATE_LOAD_CONV1_WEIGHT:
                    conv1_weight_load_cycles <=
                        conv1_weight_load_cycles + 1;

                STATE_LOAD_CONV1_BIAS:
                    conv1_bias_load_cycles <=
                        conv1_bias_load_cycles + 1;

                STATE_LOAD_CONV2_WEIGHT:
                    conv2_weight_load_cycles <=
                        conv2_weight_load_cycles + 1;

                STATE_LOAD_CONV2_BIAS:
                    conv2_bias_load_cycles <=
                        conv2_bias_load_cycles + 1;

                STATE_FRAME_PREP:
                    frame_prep_cycles <=
                        frame_prep_cycles + 1;

                STATE_STREAM_REQUEST:
                    stream_request_cycles <=
                        stream_request_cycles + 1;

                STATE_STREAM_ROM_WAIT:
                    stream_rom_wait_cycles <=
                        stream_rom_wait_cycles + 1;

                STATE_STREAM_SEND: begin
                    stream_send_cycles <=
                        stream_send_cycles + 1;

                    if (!dut.input_ready) begin
                        input_stall_cycles <=
                            input_stall_cycles + 1;
                    end
                end

                STATE_WAIT_FRAME_DONE:
                    wait_frame_done_cycles <=
                        wait_frame_done_cycles + 1;

                STATE_WAIT_CAPTURE_DONE:
                    wait_capture_done_cycles <=
                        wait_capture_done_cycles + 1;

                default: begin
                end
            endcase

            if (dut.conv1_requantize_busy) begin
                conv1_requantize_busy_cycles <=
                    conv1_requantize_busy_cycles + 1;
            end

            if (dut.conv2_requantize_busy) begin
                conv2_requantize_busy_cycles <=
                    conv2_requantize_busy_cycles + 1;
            end

            if (dut.reorder_capture_busy) begin
                reorder_capture_busy_cycles <=
                    reorder_capture_busy_cycles + 1;
            end

            if (dut.reorder_drain_busy) begin
                reorder_drain_busy_cycles <=
                    reorder_drain_busy_cycles + 1;
            end

            if (
                dut.conv2_padding_overflow_error ||
                dut.conv2_padding_sequence_error ||
                dut.reorder_sequence_error ||
                dut.reorder_metadata_error ||
                dut.reorder_overflow_error
            ) begin
                runtime_error_seen <= 1'b1;
            end

            if (
                dut.input_valid &&
                dut.input_ready
            ) begin
                if (
                    dut.current_frame_index <
                    FRAME_COUNT
                ) begin
                    frame_index =
                        dut.current_frame_index;

                    if (
                        !frame_first_input_seen[
                            frame_index
                        ]
                    ) begin
                        frame_first_input_seen[
                            frame_index
                        ] <= 1'b1;

                        frame_first_input_time[
                            frame_index
                        ] <= $time;
                    end

                    frame_last_input_time[
                        frame_index
                    ] <= $time;

                    frame_accepted_input_count[
                        frame_index
                    ] <=
                        frame_accepted_input_count[
                            frame_index
                        ] + 1;
                end

                accepted_input_count <=
                    accepted_input_count + 1;
            end

            if (raw_cnn_output_valid) begin
                if (
                    dut.current_frame_index <
                    FRAME_COUNT
                ) begin
                    frame_index =
                        dut.current_frame_index;

                    if (
                        !frame_first_raw_seen[
                            frame_index
                        ]
                    ) begin
                        frame_first_raw_seen[
                            frame_index
                        ] <= 1'b1;

                        frame_first_raw_time[
                            frame_index
                        ] <= $time;
                    end

                    frame_last_raw_time[
                        frame_index
                    ] <= $time;

                    frame_raw_feature_count[
                        frame_index
                    ] <=
                        frame_raw_feature_count[
                            frame_index
                        ] + 1;
                end

                raw_cnn_feature_count <=
                    raw_cnn_feature_count + 1;
            end

            if (dut.feature_stream_valid) begin
                if (
                    dut.current_frame_index <
                    FRAME_COUNT
                ) begin
                    frame_index =
                        dut.current_frame_index;

                    frame_reordered_count[
                        frame_index
                    ] <=
                        frame_reordered_count[
                            frame_index
                        ] + 1;
                end

                reordered_feature_count <=
                    reordered_feature_count + 1;

                if (
                    ((^dut.feature_stream_address) === 1'bx) ||
                    ((^dut.feature_stream_value) === 1'bx)
                ) begin
                    feature_xz_errors =
                        feature_xz_errors + 1;

                    if (feature_xz_errors <= 20) begin
                        $display(
                            "FAIL: X/Z on reordered feature stream at frame %0d address %0h value %0h",
                            dut.current_frame_index,
                            dut.feature_stream_address,
                            dut.feature_stream_value
                        );
                    end
                end else if (
                    dut.feature_stream_address >=
                    FEATURES_PER_FRAME
                ) begin
                    feature_address_errors =
                        feature_address_errors + 1;

                    if (feature_address_errors <= 20) begin
                        $display(
                            "FAIL: Reordered feature address %0d is outside 0..8191 on frame %0d",
                            dut.feature_stream_address,
                            dut.current_frame_index
                        );
                    end
                end else begin
                    case (dut.current_frame_index)
                        2'd0: begin
                            if (
                                seen_frame_0[
                                    dut.feature_stream_address
                                ]
                            ) begin
                                duplicate_address_errors =
                                    duplicate_address_errors + 1;

                                if (
                                    duplicate_address_errors <=
                                    20
                                ) begin
                                    $display(
                                        "FAIL: Duplicate reordered address %0d on frame 0",
                                        dut.feature_stream_address
                                    );
                                end
                            end

                            seen_frame_0[
                                dut.feature_stream_address
                            ] = 1'b1;

                            expected_vector_checks =
                                expected_vector_checks + 1;

                            if (
                                dut.feature_stream_value !==
                                expected_frame_0[
                                    dut.feature_stream_address
                                ]
                            ) begin
                                expected_vector_mismatches =
                                    expected_vector_mismatches + 1;

                                if (
                                    expected_vector_mismatches <=
                                    20
                                ) begin
                                    $display(
                                        "FAIL: Frame 0 feature[%0d] actual=%0d expected=%0d",
                                        dut.feature_stream_address,
                                        $signed(
                                            dut.feature_stream_value
                                        ),
                                        $signed(
                                            expected_frame_0[
                                                dut.feature_stream_address
                                            ]
                                        )
                                    );
                                end
                            end
                        end

                        2'd1: begin
                            if (
                                seen_frame_1[
                                    dut.feature_stream_address
                                ]
                            ) begin
                                duplicate_address_errors =
                                    duplicate_address_errors + 1;

                                if (
                                    duplicate_address_errors <=
                                    20
                                ) begin
                                    $display(
                                        "FAIL: Duplicate reordered address %0d on frame 1",
                                        dut.feature_stream_address
                                    );
                                end
                            end

                            seen_frame_1[
                                dut.feature_stream_address
                            ] = 1'b1;

                            expected_vector_checks =
                                expected_vector_checks + 1;

                            if (
                                dut.feature_stream_value !==
                                expected_frame_1[
                                    dut.feature_stream_address
                                ]
                            ) begin
                                expected_vector_mismatches =
                                    expected_vector_mismatches + 1;

                                if (
                                    expected_vector_mismatches <=
                                    20
                                ) begin
                                    $display(
                                        "FAIL: Frame 1 feature[%0d] actual=%0d expected=%0d",
                                        dut.feature_stream_address,
                                        $signed(
                                            dut.feature_stream_value
                                        ),
                                        $signed(
                                            expected_frame_1[
                                                dut.feature_stream_address
                                            ]
                                        )
                                    );
                                end
                            end
                        end

                        2'd2: begin
                            if (
                                seen_frame_2[
                                    dut.feature_stream_address
                                ]
                            ) begin
                                duplicate_address_errors =
                                    duplicate_address_errors + 1;

                                if (
                                    duplicate_address_errors <=
                                    20
                                ) begin
                                    $display(
                                        "FAIL: Duplicate reordered address %0d on frame 2",
                                        dut.feature_stream_address
                                    );
                                end
                            end

                            seen_frame_2[
                                dut.feature_stream_address
                            ] = 1'b1;

                            expected_vector_checks =
                                expected_vector_checks + 1;

                            if (
                                dut.feature_stream_value !==
                                expected_frame_2[
                                    dut.feature_stream_address
                                ]
                            ) begin
                                expected_vector_mismatches =
                                    expected_vector_mismatches + 1;

                                if (
                                    expected_vector_mismatches <=
                                    20
                                ) begin
                                    $display(
                                        "FAIL: Frame 2 feature[%0d] actual=%0d expected=%0d",
                                        dut.feature_stream_address,
                                        $signed(
                                            dut.feature_stream_value
                                        ),
                                        $signed(
                                            expected_frame_2[
                                                dut.feature_stream_address
                                            ]
                                        )
                                    );
                                end
                            end
                        end

                        2'd3: begin
                            if (
                                seen_frame_3[
                                    dut.feature_stream_address
                                ]
                            ) begin
                                duplicate_address_errors =
                                    duplicate_address_errors + 1;

                                if (
                                    duplicate_address_errors <=
                                    20
                                ) begin
                                    $display(
                                        "FAIL: Duplicate reordered address %0d on frame 3",
                                        dut.feature_stream_address
                                    );
                                end
                            end

                            seen_frame_3[
                                dut.feature_stream_address
                            ] = 1'b1;

                            expected_vector_checks =
                                expected_vector_checks + 1;

                            if (
                                dut.feature_stream_value !==
                                expected_frame_3[
                                    dut.feature_stream_address
                                ]
                            ) begin
                                expected_vector_mismatches =
                                    expected_vector_mismatches + 1;

                                if (
                                    expected_vector_mismatches <=
                                    20
                                ) begin
                                    $display(
                                        "FAIL: Frame 3 feature[%0d] actual=%0d expected=%0d",
                                        dut.feature_stream_address,
                                        $signed(
                                            dut.feature_stream_value
                                        ),
                                        $signed(
                                            expected_frame_3[
                                                dut.feature_stream_address
                                            ]
                                        )
                                    );
                                end
                            end
                        end

                        default: begin
                            feature_address_errors =
                                feature_address_errors + 1;

                            if (feature_address_errors <= 20) begin
                                $display(
                                    "FAIL: Reordered feature arrived with invalid frame index %0d",
                                    dut.current_frame_index
                                );
                            end
                        end
                    endcase
                end
            end

            if (dut.feature_stream_frame_done) begin
                if (
                    dut.current_frame_index <
                    FRAME_COUNT
                ) begin
                    frame_done_time[
                        dut.current_frame_index
                    ] <= $time;
                end

                frame_done_count <=
                    frame_done_count + 1;
            end
        end
    end

    task check_integer;
        input [8*80-1:0] label_text;
        input integer actual_value;
        input integer expected_value;
        begin
            if (actual_value == expected_value) begin
                $display(
                    "PASS: %0s = %0d",
                    label_text,
                    actual_value
                );
            end else begin
                $display(
                    "FAIL: %0s = %0d, expected %0d",
                    label_text,
                    actual_value,
                    expected_value
                );

                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        reset_button = 1'b1;
        start_button = 1'b0;

        error_count = 0;
        frame_index = 0;

        accepted_input_count = 0;
        raw_cnn_feature_count = 0;
        reordered_feature_count = 0;
        frame_done_count = 0;

        expected_vector_checks = 0;
        expected_vector_mismatches = 0;
        duplicate_address_errors = 0;
        feature_address_errors = 0;
        feature_xz_errors = 0;
        missing_address_errors = 0;

        seen_frame_0 = {FEATURES_PER_FRAME{1'b0}};
        seen_frame_1 = {FEATURES_PER_FRAME{1'b0}};
        seen_frame_2 = {FEATURES_PER_FRAME{1'b0}};
        seen_frame_3 = {FEATURES_PER_FRAME{1'b0}};

        latency_active = 1'b0;
        runtime_error_seen = 1'b0;

        core_cycle_count = 0;
        capture_reset_cycles = 0;
        conv1_weight_load_cycles = 0;
        conv1_bias_load_cycles = 0;
        conv2_weight_load_cycles = 0;
        conv2_bias_load_cycles = 0;
        frame_prep_cycles = 0;
        stream_request_cycles = 0;
        stream_rom_wait_cycles = 0;
        stream_send_cycles = 0;
        input_stall_cycles = 0;
        wait_frame_done_cycles = 0;
        wait_capture_done_cycles = 0;

        conv1_requantize_busy_cycles = 0;
        conv2_requantize_busy_cycles = 0;
        reorder_capture_busy_cycles = 0;
        reorder_drain_busy_cycles = 0;

        start_time_ns = 0;
        done_time_ns = 0;
        total_latency_ns = 0;
        startup_to_first_input_ns = 0;
        final_capture_tail_ns = 0;

        total_core_cycles = 0;

        total_latency_ms = 0.0;
        average_latency_per_frame_ms = 0.0;
        measured_throughput_fps = 0.0;

        stage06_four_frame_ms = 227.185600;
        stage06_average_frame_ms = 56.796400;
        stage06_throughput_fps = 17.606750;

        latency_speedup = 0.0;
        frame_latency_speedup = 0.0;
        throughput_gain = 0.0;
        latency_reduction_percent = 0.0;

        parameter_load_ms = 0.0;
        feeder_control_ms = 0.0;
        feeder_stall_ms = 0.0;

        for (
            frame_index = 0;
            frame_index < FRAME_COUNT;
            frame_index = frame_index + 1
        ) begin
            frame_accepted_input_count[
                frame_index
            ] = 0;

            frame_raw_feature_count[
                frame_index
            ] = 0;

            frame_reordered_count[
                frame_index
            ] = 0;

            frame_first_input_time[
                frame_index
            ] = 0;

            frame_last_input_time[
                frame_index
            ] = 0;

            frame_first_raw_time[
                frame_index
            ] = 0;

            frame_last_raw_time[
                frame_index
            ] = 0;

            frame_done_time[
                frame_index
            ] = 0;

            frame_first_input_seen[
                frame_index
            ] = 1'b0;

            frame_first_raw_seen[
                frame_index
            ] = 1'b0;
        end

        $display(
            "============================================================"
        );
        $display(
            "Stage-07 streaming CNN 50 MHz latency monitor"
        );
        $display(
            "Top: cnn_feature_streaming_nexys_video_top V3"
        );
        $display(
            "Board clock = 100 MHz"
        );
        $display(
            "CNN core clock = 50 MHz"
        );
        $display(
            "Stage-06 baseline = 227.185600 ms / four frames"
        );
        $display(
            "============================================================"
        );

        repeat (30) @(posedge clk);
        reset_button = 1'b0;

        repeat (20) @(posedge clk);

        @(posedge clk);
        start_button = 1'b1;

        repeat (10) @(posedge clk);
        start_button = 1'b0;

        wait (led_started === 1'b1);

        start_time_ns = $time;
        latency_active = 1'b1;

        $display(
            "Start command accepted at %0t ns",
            start_time_ns
        );

        wait (led_done === 1'b1);

        done_time_ns = $time;
        latency_active = 1'b0;

        #1;

        total_latency_ns =
            done_time_ns -
            start_time_ns;

        total_core_cycles =
            total_latency_ns /
            CORE_CLOCK_PERIOD_NS;

        total_latency_ms =
            total_latency_ns /
            1000000.0;

        average_latency_per_frame_ms =
            total_latency_ms /
            FRAME_COUNT;

        measured_throughput_fps =
            FRAME_COUNT /
            (
                total_latency_ns /
                1000000000.0
            );

        latency_speedup =
            stage06_four_frame_ms /
            total_latency_ms;

        frame_latency_speedup =
            stage06_average_frame_ms /
            average_latency_per_frame_ms;

        throughput_gain =
            measured_throughput_fps /
            stage06_throughput_fps;

        latency_reduction_percent =
            (
                1.0 -
                (
                    total_latency_ms /
                    stage06_four_frame_ms
                )
            ) * 100.0;

        if (frame_first_input_seen[0]) begin
            startup_to_first_input_ns =
                frame_first_input_time[0] -
                start_time_ns;
        end

        if (
            frame_done_time[FRAME_COUNT-1] != 0
        ) begin
            final_capture_tail_ns =
                done_time_ns -
                frame_done_time[
                    FRAME_COUNT-1
                ];
        end

        parameter_load_ms =
            (
                conv1_weight_load_cycles +
                conv1_bias_load_cycles +
                conv2_weight_load_cycles +
                conv2_bias_load_cycles
            ) *
            CORE_CLOCK_PERIOD_NS /
            1000000.0;

        feeder_control_ms =
            (
                stream_request_cycles +
                stream_rom_wait_cycles
            ) *
            CORE_CLOCK_PERIOD_NS /
            1000000.0;

        feeder_stall_ms =
            input_stall_cycles *
            CORE_CLOCK_PERIOD_NS /
            1000000.0;

        $display("");
        $display(
            "============================================================"
        );
        $display(
            "AUTHORITATIVE BOARD-LEVEL LATENCY RESULT"
        );
        $display(
            "============================================================"
        );
        $display(
            "Start accepted time                = %0t ns",
            start_time_ns
        );
        $display(
            "Done time                          = %0t ns",
            done_time_ns
        );
        $display(
            "Total four-frame latency           = %0t ns",
            total_latency_ns
        );
        $display(
            "Total four-frame latency           = %0.6f ms",
            total_latency_ms
        );
        $display(
            "Equivalent 50 MHz core cycles      = %0d",
            total_core_cycles
        );
        $display(
            "Average latency per frame          = %0.6f ms/frame",
            average_latency_per_frame_ms
        );
        $display(
            "Measured throughput                = %0.6f frames/s",
            measured_throughput_fps
        );

        $display("");
        $display(
            "============================================================"
        );
        $display(
            "STAGE-06 COMPARISON"
        );
        $display(
            "============================================================"
        );
        $display(
            "Stage-06 four-frame latency        = %0.6f ms",
            stage06_four_frame_ms
        );
        $display(
            "Stage-06 average frame latency     = %0.6f ms/frame",
            stage06_average_frame_ms
        );
        $display(
            "Stage-06 throughput                = %0.6f frames/s",
            stage06_throughput_fps
        );
        $display(
            "Four-frame latency speedup         = %0.6fx",
            latency_speedup
        );
        $display(
            "Average-frame latency speedup      = %0.6fx",
            frame_latency_speedup
        );
        $display(
            "Throughput gain                    = %0.6fx",
            throughput_gain
        );
        $display(
            "Latency reduction                  = %0.6f %%",
            latency_reduction_percent
        );

        $display("");
        $display(
            "============================================================"
        );
        $display(
            "BOARD-WRAPPER AND FEEDER BREAKDOWN"
        );
        $display(
            "============================================================"
        );
        $display(
            "Capture-reset cycles               = %0d",
            capture_reset_cycles
        );
        $display(
            "Conv1 weight-load cycles           = %0d",
            conv1_weight_load_cycles
        );
        $display(
            "Conv1 bias-load cycles             = %0d",
            conv1_bias_load_cycles
        );
        $display(
            "Conv2 weight-load cycles           = %0d",
            conv2_weight_load_cycles
        );
        $display(
            "Conv2 bias-load cycles             = %0d",
            conv2_bias_load_cycles
        );
        $display(
            "Parameter-load time                = %0.6f ms",
            parameter_load_ms
        );
        $display(
            "Frame-prep cycles                  = %0d",
            frame_prep_cycles
        );
        $display(
            "STREAM_REQUEST cycles              = %0d",
            stream_request_cycles
        );
        $display(
            "STREAM_ROM_WAIT cycles             = %0d",
            stream_rom_wait_cycles
        );
        $display(
            "STREAM_SEND cycles                 = %0d",
            stream_send_cycles
        );
        $display(
            "Accepted padded-input cycles       = %0d",
            accepted_input_count
        );
        $display(
            "Input-ready stall cycles           = %0d",
            input_stall_cycles
        );
        $display(
            "Feeder control time                = %0.6f ms",
            feeder_control_ms
        );
        $display(
            "Feeder backpressure time           = %0.6f ms",
            feeder_stall_ms
        );
        $display(
            "WAIT_FRAME_DONE cycles             = %0d",
            wait_frame_done_cycles
        );
        $display(
            "WAIT_CAPTURE_DONE cycles           = %0d",
            wait_capture_done_cycles
        );
        $display(
            "Start-to-first-input interval       = %0.6f ms",
            startup_to_first_input_ns /
            1000000.0
        );
        $display(
            "Final frame-done-to-Done tail       = %0.6f ms",
            final_capture_tail_ns /
            1000000.0
        );

        $display("");
        $display(
            "============================================================"
        );
        $display(
            "CNN / REORDER ACTIVITY"
        );
        $display(
            "============================================================"
        );
        $display(
            "Conv1 requantize-busy cycles       = %0d",
            conv1_requantize_busy_cycles
        );
        $display(
            "Conv2 requantize-busy cycles       = %0d",
            conv2_requantize_busy_cycles
        );
        $display(
            "Reorder capture-busy cycles        = %0d",
            reorder_capture_busy_cycles
        );
        $display(
            "Reorder drain-busy cycles          = %0d",
            reorder_drain_busy_cycles
        );
        $display(
            "Raw final-CNN features             = %0d",
            raw_cnn_feature_count
        );
        $display(
            "Reordered temporal features        = %0d",
            reordered_feature_count
        );
        $display(
            "Frame-done pulses                  = %0d",
            frame_done_count
        );
        $display(
            "Expected-vector comparisons        = %0d",
            expected_vector_checks
        );
        $display(
            "Expected-vector mismatches         = %0d",
            expected_vector_mismatches
        );
        $display(
            "Duplicate feature addresses        = %0d",
            duplicate_address_errors
        );
        $display(
            "Out-of-range/frame-index errors    = %0d",
            feature_address_errors
        );
        $display(
            "Feature-stream X/Z errors          = %0d",
            feature_xz_errors
        );

        $display("");
        $display(
            "============================================================"
        );
        $display(
            "PER-FRAME LATENCY BREAKDOWN"
        );
        $display(
            "============================================================"
        );

        for (
            frame_index = 0;
            frame_index < FRAME_COUNT;
            frame_index = frame_index + 1
        ) begin
            $display(
                "Frame %0d:",
                frame_index
            );
            $display(
                "  Accepted padded inputs           = %0d",
                frame_accepted_input_count[
                    frame_index
                ]
            );
            $display(
                "  Raw final-CNN features           = %0d",
                frame_raw_feature_count[
                    frame_index
                ]
            );
            $display(
                "  Reordered features               = %0d",
                frame_reordered_count[
                    frame_index
                ]
            );
            $display(
                "  First accepted input             = %0t ns",
                frame_first_input_time[
                    frame_index
                ]
            );
            $display(
                "  Last accepted input              = %0t ns",
                frame_last_input_time[
                    frame_index
                ]
            );
            $display(
                "  First raw final-CNN output       = %0t ns",
                frame_first_raw_time[
                    frame_index
                ]
            );
            $display(
                "  Last raw final-CNN output        = %0t ns",
                frame_last_raw_time[
                    frame_index
                ]
            );
            $display(
                "  Reordered frame done             = %0t ns",
                frame_done_time[
                    frame_index
                ]
            );

            if (
                frame_first_input_seen[
                    frame_index
                ] &&
                frame_first_raw_seen[
                    frame_index
                ] &&
                (
                    frame_done_time[
                        frame_index
                    ] != 0
                )
            ) begin
                $display(
                    "  First-input -> first raw output  = %0.6f ms",
                    (
                        frame_first_raw_time[
                            frame_index
                        ] -
                        frame_first_input_time[
                            frame_index
                        ]
                    ) /
                    1000000.0
                );
                $display(
                    "  First-input -> last raw output   = %0.6f ms",
                    (
                        frame_last_raw_time[
                            frame_index
                        ] -
                        frame_first_input_time[
                            frame_index
                        ]
                    ) /
                    1000000.0
                );
                $display(
                    "  Raw-last -> reordered frame-done = %0.6f ms",
                    (
                        frame_done_time[
                            frame_index
                        ] -
                        frame_last_raw_time[
                            frame_index
                        ]
                    ) /
                    1000000.0
                );
                $display(
                    "  First-input -> frame-done        = %0.6f ms",
                    (
                        frame_done_time[
                            frame_index
                        ] -
                        frame_first_input_time[
                            frame_index
                        ]
                    ) /
                    1000000.0
                );
            end
        end

        $display("");
        $display(
            "============================================================"
        );
        $display(
            "SELF-CHECKS"
        );
        $display(
            "============================================================"
        );

        check_integer(
            "Accepted padded inputs",
            accepted_input_count,
            TOTAL_PADDED_INPUTS
        );

        check_integer(
            "Raw final-CNN features",
            raw_cnn_feature_count,
            TOTAL_FEATURES
        );

        check_integer(
            "Reordered temporal features",
            reordered_feature_count,
            TOTAL_FEATURES
        );

        check_integer(
            "Frame-done pulses",
            frame_done_count,
            FRAME_COUNT
        );

        for (
            frame_index = 0;
            frame_index < FRAME_COUNT;
            frame_index = frame_index + 1
        ) begin
            check_integer(
                "Per-frame accepted padded inputs",
                frame_accepted_input_count[
                    frame_index
                ],
                PADDED_INPUTS_PER_FRAME
            );

            check_integer(
                "Per-frame raw final-CNN features",
                frame_raw_feature_count[
                    frame_index
                ],
                FEATURES_PER_FRAME
            );

            check_integer(
                "Per-frame reordered features",
                frame_reordered_count[
                    frame_index
                ],
                FEATURES_PER_FRAME
            );
        end

        check_integer(
            "Expected-vector comparisons",
            expected_vector_checks,
            TOTAL_FEATURES
        );

        check_integer(
            "Expected-vector mismatches",
            expected_vector_mismatches,
            0
        );

        check_integer(
            "Duplicate reordered addresses",
            duplicate_address_errors,
            0
        );

        check_integer(
            "Feature address/frame-index errors",
            feature_address_errors,
            0
        );

        check_integer(
            "Feature-stream X/Z errors",
            feature_xz_errors,
            0
        );

        for (
            frame_index = 0;
            frame_index < FEATURES_PER_FRAME;
            frame_index = frame_index + 1
        ) begin
            if (!seen_frame_0[frame_index]) begin
                missing_address_errors =
                    missing_address_errors + 1;
            end

            if (!seen_frame_1[frame_index]) begin
                missing_address_errors =
                    missing_address_errors + 1;
            end

            if (!seen_frame_2[frame_index]) begin
                missing_address_errors =
                    missing_address_errors + 1;
            end

            if (!seen_frame_3[frame_index]) begin
                missing_address_errors =
                    missing_address_errors + 1;
            end
        end

        check_integer(
            "Missing reordered feature addresses",
            missing_address_errors,
            0
        );

        if (
            dut.temporal_captured_frame_count ==
            FRAME_COUNT
        ) begin
            $display(
                "PASS: Captured temporal frames = %0d",
                dut.temporal_captured_frame_count
            );
        end else begin
            $display(
                "FAIL: Captured temporal frames = %0d, expected %0d",
                dut.temporal_captured_frame_count,
                FRAME_COUNT
            );

            error_count = error_count + 1;
        end

        if (
            dut.temporal_capture_complete ===
            1'b1
        ) begin
            $display(
                "PASS: temporal_capture_complete = 1"
            );
        end else begin
            $display(
                "FAIL: temporal_capture_complete != 1"
            );

            error_count = error_count + 1;
        end

        if (!runtime_error_seen) begin
            $display(
                "PASS: No padding/reorder runtime errors observed"
            );
        end else begin
            $display(
                "FAIL: A padding/reorder runtime error was observed"
            );

            error_count = error_count + 1;
        end

        if (
            (led_done === 1'b1) &&
            (led_busy === 1'b0) &&
            (led_started === 1'b1) &&
            (led_pass === 1'b1) &&
            (led_fail === 1'b0)
        ) begin
            $display(
                "PASS: Final board status is Done=1 Busy=0 Started=1 Pass=1 Fail=0"
            );
        end else begin
            $display(
                "FAIL: Final board status = Done:%b Busy:%b Started:%b Pass:%b Fail:%b",
                led_done,
                led_busy,
                led_started,
                led_pass,
                led_fail
            );

            error_count = error_count + 1;
        end

        $display("");
        $display(
            "============================================================"
        );
        $display(
            "FINAL LATENCY-MONITOR RESULT"
        );
        $display(
            "============================================================"
        );
        $display(
            "Total errors = %0d",
            error_count
        );

        if (error_count == 0) begin
            $display(
                "PASS: Stage-07 four-frame board-level latency measured successfully at the implemented 50 MHz CNN core clock with exact 32768-value expected-vector agreement."
            );
        end else begin
            $display(
                "FAIL: Stage-07 latency monitor detected %0d error(s).",
                error_count
            );
        end

        $display(
            "============================================================"
        );

        #100;
        $finish;
    end

    initial begin
        #(64'd500000000);

        $display("");
        $display(
            "============================================================"
        );
        $display(
            "FAIL: LATENCY MONITOR TIMEOUT"
        );
        $display(
            "============================================================"
        );
        $display(
            "The design did not assert Done within 500 ms simulated time."
        );
        $display(
            "Current state          = %0d",
            dut.current_state
        );
        $display(
            "Current frame          = %0d",
            dut.current_frame_index
        );
        $display(
            "Accepted inputs        = %0d",
            accepted_input_count
        );
        $display(
            "Raw CNN features       = %0d",
            raw_cnn_feature_count
        );
        $display(
            "Reordered features     = %0d",
            reordered_feature_count
        );
        $display(
            "Frame-done pulses      = %0d",
            frame_done_count
        );
        $display(
            "LEDs                   = %b",
            led
        );
        $display(
            "============================================================"
        );

        $finish;
    end

endmodule

`default_nettype wire
