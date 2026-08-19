`timescale 1ns / 1ps

module streaming_feature_reorder_buffer_tb;

    localparam integer FEATURE_WIDTH      = 4;
    localparam integer FEATURE_HEIGHT     = 3;
    localparam integer FEATURE_CHANNELS   = 4;
    localparam integer FEATURES_PER_FRAME =
        FEATURE_WIDTH * FEATURE_HEIGHT * FEATURE_CHANNELS;

    localparam integer TEST_FRAMES        = 2;
    localparam integer EXPECTED_OUTPUTS   =
        FEATURES_PER_FRAME * TEST_FRAMES;

    localparam integer MAX_CLOCK_CYCLES   = 2000;

    reg                     clk;
    reg                     reset;

    reg signed [7:0]        input_value;
    reg [7:0]               input_x;
    reg [7:0]               input_y;
    reg [7:0]               input_channel_index;
    reg                     input_valid;

    wire signed [7:0]       output_value;
    wire [12:0]             output_address;
    wire                    output_valid;
    wire                    output_frame_done;

    wire                    capture_busy;
    wire                    drain_busy;
    wire                    sequence_error;
    wire                    metadata_error;
    wire                    overflow_error;

    integer input_count;
    integer output_count;
    integer frame_done_count;
    integer error_count;
    integer unknown_count;
    integer duplicate_count;
    integer missing_count;
    integer unexpected_count;
    integer capture_busy_cycles;
    integer drain_busy_cycles;
    integer clock_cycle_count;

    integer send_frame_index;
    integer send_y_index;
    integer send_x_index;
    integer send_channel_index;
    integer send_legacy_address;
    integer send_value_integer;

    integer monitor_frame_index;
    integer monitor_frame_address;
    integer expected_x;
    integer expected_y;
    integer expected_channel;
    integer expected_value_integer;
    integer expected_global_index;

    integer seen_index;

    reg output_seen [0:EXPECTED_OUTPUTS-1];

    reg simulation_complete;
    reg simulation_pass;
    reg simulation_fail;

    streaming_feature_reorder_buffer #(
        .FEATURE_WIDTH(FEATURE_WIDTH),
        .FEATURE_HEIGHT(FEATURE_HEIGHT),
        .FEATURE_CHANNELS(FEATURE_CHANNELS),
        .FEATURES_PER_FRAME(FEATURES_PER_FRAME)
    ) dut (
        .clk(clk),
        .reset(reset),

        .input_value(input_value),
        .input_x(input_x),
        .input_y(input_y),
        .input_channel_index(input_channel_index),
        .input_valid(input_valid),

        .output_value(output_value),
        .output_address(output_address),
        .output_valid(output_valid),
        .output_frame_done(output_frame_done),

        .capture_busy(capture_busy),
        .drain_busy(drain_busy),
        .sequence_error(sequence_error),
        .metadata_error(metadata_error),
        .overflow_error(overflow_error)
    );

    function signed [7:0] generated_input_value;
        input integer frame_number;
        input integer x_position;
        input integer y_position;
        input integer channel_number;
        integer value_integer;
        begin
            value_integer =
                (frame_number * 53) +
                (channel_number * 17) +
                (y_position * 7) +
                (x_position * 3) -
                64;

            generated_input_value = value_integer;
        end
    endfunction

    function signed [7:0] expected_channel_major_value;
        input integer frame_number;
        input integer channel_major_address;
        integer local_channel;
        integer local_spatial_address;
        integer local_y;
        integer local_x;
        begin
            local_channel =
                channel_major_address /
                (FEATURE_WIDTH * FEATURE_HEIGHT);

            local_spatial_address =
                channel_major_address %
                (FEATURE_WIDTH * FEATURE_HEIGHT);

            local_y =
                local_spatial_address / FEATURE_WIDTH;

            local_x =
                local_spatial_address % FEATURE_WIDTH;

            expected_channel_major_value =
                generated_input_value(
                    frame_number,
                    local_x,
                    local_y,
                    local_channel
                );
        end
    endfunction

    task send_frame;
        input integer frame_number;
        begin
            for (
                send_y_index = 0;
                send_y_index < FEATURE_HEIGHT;
                send_y_index = send_y_index + 1
            ) begin
                for (
                    send_x_index = 0;
                    send_x_index < FEATURE_WIDTH;
                    send_x_index = send_x_index + 1
                ) begin
                    for (
                        send_channel_index = 0;
                        send_channel_index < FEATURE_CHANNELS;
                        send_channel_index = send_channel_index + 1
                    ) begin
                        while (!capture_busy) begin
                            @(negedge clk);
                        end

                        send_legacy_address =
                            (send_channel_index *
                             FEATURE_WIDTH *
                             FEATURE_HEIGHT) +
                            (send_y_index * FEATURE_WIDTH) +
                            send_x_index;

                        send_value_integer =
                            generated_input_value(
                                frame_number,
                                send_x_index,
                                send_y_index,
                                send_channel_index
                            );

                        @(negedge clk);

                        input_value =
                            send_value_integer;
                        input_x =
                            send_x_index;
                        input_y =
                            send_y_index;
                        input_channel_index =
                            send_channel_index;
                        input_valid =
                            1'b1;

                        @(negedge clk);

                        input_valid =
                            1'b0;
                        input_value =
                            8'sd0;
                        input_x =
                            8'd0;
                        input_y =
                            8'd0;
                        input_channel_index =
                            8'd0;

                        input_count =
                            input_count + 1;
                    end
                end
            end
        end
    endtask

    always @(posedge clk) begin
        if (!reset) begin
            if (capture_busy) begin
                capture_busy_cycles =
                    capture_busy_cycles + 1;
            end

            if (drain_busy) begin
                drain_busy_cycles =
                    drain_busy_cycles + 1;
            end

            if (output_valid) begin
                if (
                    (^output_value === 1'bx) ||
                    (^output_address === 1'bx)
                ) begin
                    unknown_count =
                        unknown_count + 1;
                    error_count =
                        error_count + 1;

                    $display(
                        "ERROR: Output %0d contains X/Z.",
                        output_count
                    );
                end

                if (output_count >= EXPECTED_OUTPUTS) begin
                    unexpected_count =
                        unexpected_count + 1;
                    error_count =
                        error_count + 1;

                    $display(
                        "ERROR: Unexpected extra output address=%0d value=%0d.",
                        output_address,
                        $signed(output_value)
                    );
                end else begin
                    monitor_frame_index =
                        output_count / FEATURES_PER_FRAME;

                    monitor_frame_address =
                        output_count % FEATURES_PER_FRAME;

                    expected_global_index =
                        (monitor_frame_index *
                         FEATURES_PER_FRAME) +
                        monitor_frame_address;

                    expected_channel =
                        monitor_frame_address /
                        (FEATURE_WIDTH * FEATURE_HEIGHT);

                    expected_y =
                        (monitor_frame_address %
                         (FEATURE_WIDTH * FEATURE_HEIGHT)) /
                        FEATURE_WIDTH;

                    expected_x =
                        monitor_frame_address %
                        FEATURE_WIDTH;

                    expected_value_integer =
                        expected_channel_major_value(
                            monitor_frame_index,
                            monitor_frame_address
                        );

                    if (
                        output_address !==
                        monitor_frame_address[12:0]
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d address expected=%0d received=%0d.",
                            output_count,
                            monitor_frame_address,
                            output_address
                        );
                    end

                    if (
                        output_value !==
                        expected_value_integer
                    ) begin
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Output %0d frame=%0d address=%0d channel=%0d y=%0d x=%0d expected=%0d received=%0d.",
                            output_count,
                            monitor_frame_index,
                            monitor_frame_address,
                            expected_channel,
                            expected_y,
                            expected_x,
                            expected_value_integer,
                            $signed(output_value)
                        );
                    end else begin
                        $display(
                            "PASS: Output %0d frame=%0d address=%0d channel=%0d y=%0d x=%0d value=%0d",
                            output_count,
                            monitor_frame_index,
                            output_address,
                            expected_channel,
                            expected_y,
                            expected_x,
                            $signed(output_value)
                        );
                    end

                    if (
                        output_seen[expected_global_index]
                    ) begin
                        duplicate_count =
                            duplicate_count + 1;
                        error_count =
                            error_count + 1;

                        $display(
                            "ERROR: Duplicate output global index %0d.",
                            expected_global_index
                        );
                    end else begin
                        output_seen[expected_global_index] =
                            1'b1;
                    end
                end

                output_count =
                    output_count + 1;
            end

            if (output_frame_done) begin
                frame_done_count =
                    frame_done_count + 1;

                if (!output_valid) begin
                    error_count =
                        error_count + 1;

                    $display(
                        "ERROR: output_frame_done asserted without output_valid."
                    );
                end

                if (
                    output_address !==
                    FEATURES_PER_FRAME - 1
                ) begin
                    error_count =
                        error_count + 1;

                    $display(
                        "ERROR: output_frame_done address expected=%0d received=%0d.",
                        FEATURES_PER_FRAME - 1,
                        output_address
                    );
                end
            end
        end
    end

    initial begin
        clk = 1'b0;

        repeat (MAX_CLOCK_CYCLES) begin
            #5 clk = ~clk;
        end

        if (!simulation_complete) begin
            $display(
                "FAIL: Timeout before reorder-buffer verification completed."
            );
            $finish;
        end
    end

    initial begin
        reset =
            1'b1;

        input_value =
            8'sd0;
        input_x =
            8'd0;
        input_y =
            8'd0;
        input_channel_index =
            8'd0;
        input_valid =
            1'b0;

        input_count =
            0;
        output_count =
            0;
        frame_done_count =
            0;
        error_count =
            0;
        unknown_count =
            0;
        duplicate_count =
            0;
        missing_count =
            0;
        unexpected_count =
            0;
        capture_busy_cycles =
            0;
        drain_busy_cycles =
            0;
        clock_cycle_count =
            0;

        simulation_complete =
            1'b0;
        simulation_pass =
            1'b0;
        simulation_fail =
            1'b0;

        for (
            seen_index = 0;
            seen_index < EXPECTED_OUTPUTS;
            seen_index = seen_index + 1
        ) begin
            output_seen[seen_index] =
                1'b0;
        end

        $display(
            "ACTIVE TB: streaming_feature_reorder_buffer_tb CHANNEL-MAJOR TWO-FRAME V1"
        );

        repeat (5) @(posedge clk);

        @(negedge clk);
        reset =
            1'b0;

        repeat (3) @(posedge clk);

        for (
            send_frame_index = 0;
            send_frame_index < TEST_FRAMES;
            send_frame_index = send_frame_index + 1
        ) begin
            $display(
                "Sending frame %0d in pixel-major/channel-interleaved order...",
                send_frame_index
            );

            send_frame(send_frame_index);

            while (
                frame_done_count <
                send_frame_index + 1
            ) begin
                @(posedge clk);
            end

            repeat (3) @(posedge clk);
        end

        repeat (5) @(posedge clk);
        @(negedge clk);

        for (
            seen_index = 0;
            seen_index < EXPECTED_OUTPUTS;
            seen_index = seen_index + 1
        ) begin
            if (!output_seen[seen_index]) begin
                missing_count =
                    missing_count + 1;
                error_count =
                    error_count + 1;

                $display(
                    "ERROR: Missing output global index %0d.",
                    seen_index
                );
            end
        end

        if (
            input_count !=
            EXPECTED_OUTPUTS
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Input count expected=%0d received=%0d.",
                EXPECTED_OUTPUTS,
                input_count
            );
        end

        if (
            output_count !=
            EXPECTED_OUTPUTS
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Output count expected=%0d received=%0d.",
                EXPECTED_OUTPUTS,
                output_count
            );
        end

        if (
            frame_done_count !=
            TEST_FRAMES
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Frame-done count expected=%0d received=%0d.",
                TEST_FRAMES,
                frame_done_count
            );
        end

        if (sequence_error) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: sequence_error asserted."
            );
        end

        if (metadata_error) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: metadata_error asserted."
            );
        end

        if (overflow_error) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: overflow_error asserted."
            );
        end

        $display(
            "================================================"
        );
        $display(
            "Streaming feature reorder-buffer verification complete"
        );
        $display(
            "Frames captured             = %0d",
            TEST_FRAMES
        );
        $display(
            "Input transactions          = %0d",
            input_count
        );
        $display(
            "Expected input transactions = %0d",
            EXPECTED_OUTPUTS
        );
        $display(
            "Output transactions         = %0d",
            output_count
        );
        $display(
            "Expected output transactions= %0d",
            EXPECTED_OUTPUTS
        );
        $display(
            "Frame-done pulses           = %0d",
            frame_done_count
        );
        $display(
            "Capture-busy cycles         = %0d",
            capture_busy_cycles
        );
        $display(
            "Drain-busy cycles           = %0d",
            drain_busy_cycles
        );
        $display(
            "Duplicate outputs           = %0d",
            duplicate_count
        );
        $display(
            "Missing outputs             = %0d",
            missing_count
        );
        $display(
            "Unexpected outputs          = %0d",
            unexpected_count
        );
        $display(
            "sequence_error              = %0d",
            sequence_error
        );
        $display(
            "metadata_error              = %0d",
            metadata_error
        );
        $display(
            "overflow_error              = %0d",
            overflow_error
        );
        $display(
            "X/Z errors                  = %0d",
            unknown_count
        );
        $display(
            "Total errors                = %0d",
            error_count
        );
        $display(
            "================================================"
        );

        if (error_count == 0) begin
            simulation_pass =
                1'b1;

            $display(
                "PASS: Pixel-major/channel-interleaved capture was reordered exactly into the frozen channel-major feature-vector address order across two complete frames."
            );
        end else begin
            simulation_fail =
                1'b1;

            $display(
                "FAIL: Feature reorder-buffer verification found %0d errors.",
                error_count
            );
        end

        simulation_complete =
            1'b1;

        #20;
        $finish;
    end

endmodule
