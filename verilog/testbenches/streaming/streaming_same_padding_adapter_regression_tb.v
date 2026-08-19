`timescale 1ns / 1ps

module streaming_same_padding_adapter_regression_tb;

    // ACTIVE TESTBENCH: SAME-padding regression corrected edge sampling

    localparam integer IMAGE_WIDTH  = 3;
    localparam integer IMAGE_HEIGHT = 2;
    localparam integer CHANNELS     = 3;
    localparam integer FIFO_DEPTH   = IMAGE_WIDTH * IMAGE_HEIGHT * CHANNELS;
    localparam integer PADDED_WIDTH = IMAGE_WIDTH + 2;
    localparam integer PADDED_HEIGHT = IMAGE_HEIGHT + 2;
    localparam integer FRAME_COUNT = 2;
    localparam integer FRAME_INPUT_COUNT =
        IMAGE_WIDTH * IMAGE_HEIGHT * CHANNELS;
    localparam integer FRAME_OUTPUT_COUNT =
        PADDED_WIDTH * PADDED_HEIGHT * CHANNELS;
    localparam integer TOTAL_INPUT_COUNT =
        FRAME_COUNT * FRAME_INPUT_COUNT;
    localparam integer EXPECTED_OUTPUT_COUNT =
        FRAME_COUNT * FRAME_OUTPUT_COUNT;
    localparam integer EXPECTED_BORDER_OUTPUTS =
        FRAME_COUNT *
        (((PADDED_WIDTH * PADDED_HEIGHT) -
          (IMAGE_WIDTH * IMAGE_HEIGHT)) * CHANNELS);

    reg clk;
    reg reset;

    reg signed [7:0] input_value;
    reg [7:0] input_x;
    reg [7:0] input_y;
    reg [7:0] input_channel_index;
    reg input_valid;

    wire signed [7:0] output_value;
    wire [7:0] output_padded_x;
    wire [7:0] output_padded_y;
    wire [7:0] output_channel_index;
    wire output_valid;
    reg output_ready;

    wire overflow_error;
    wire sequence_error;

    integer error_count;
    integer unknown_count;
    integer input_sample_count;
    integer output_count;
    integer border_output_count;
    integer interior_output_count;
    integer downstream_stall_cycles;
    integer empty_wait_cycles;
    integer held_output_checks;
    integer fifo_peak;
    integer simultaneous_fifo_cycles;
    integer ready_pattern_count;

    integer expected_frame;
    integer expected_position;
    integer expected_pixel;
    integer expected_padded_x;
    integer expected_padded_y;
    integer expected_channel;
    reg signed [7:0] expected_value;

    reg stall_holding;
    reg signed [7:0] held_output_value;
    reg [7:0] held_output_padded_x;
    reg [7:0] held_output_padded_y;
    reg [7:0] held_output_channel;
    reg held_output_valid;

    function signed [7:0] source_value;
        input integer frame_index;
        input integer x;
        input integer y;
        input integer channel_index;
        integer calculated_value;
        begin
            calculated_value =
                -42 +
                (frame_index * 60) +
                (y * 31) +
                (x * 9) +
                (channel_index * 5);
            source_value = calculated_value;
        end
    endfunction

    streaming_same_padding_adapter #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .CHANNELS(CHANNELS),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .input_value(input_value),
        .input_x(input_x),
        .input_y(input_y),
        .input_channel_index(input_channel_index),
        .input_valid(input_valid),
        .output_value(output_value),
        .output_padded_x(output_padded_x),
        .output_padded_y(output_padded_y),
        .output_channel_index(output_channel_index),
        .output_valid(output_valid),
        .output_ready(output_ready),
        .overflow_error(overflow_error),
        .sequence_error(sequence_error)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task send_frame_continuous;
        input integer frame_index;
        integer y_index;
        integer x_index;
        integer channel_index;
        begin
            for (y_index = 0; y_index < IMAGE_HEIGHT; y_index = y_index + 1) begin
                for (x_index = 0; x_index < IMAGE_WIDTH; x_index = x_index + 1) begin
                    for (
                        channel_index = 0;
                        channel_index < CHANNELS;
                        channel_index = channel_index + 1
                    ) begin
                        @(negedge clk);

                        input_valid = 1'b1;
                        input_x = x_index[7:0];
                        input_y = y_index[7:0];
                        input_channel_index = channel_index[7:0];
                        input_value = source_value(
                            frame_index,
                            x_index,
                            y_index,
                            channel_index
                        );
                    end
                end
            end

            @(negedge clk);
            input_valid = 1'b0;
            input_value = 8'sd0;
            input_x = 8'd0;
            input_y = 8'd0;
            input_channel_index = 8'd0;
        end
    endtask

    task send_frame_slow;
        input integer frame_index;
        integer y_index;
        integer x_index;
        integer channel_index;
        begin
            while (dut.fifo_count > 8) begin
                @(negedge clk);
            end

            $display(
                "Starting frame %0d while padded output is active, FIFO occupancy=%0d...",
                frame_index,
                dut.fifo_count
            );

            for (y_index = 0; y_index < IMAGE_HEIGHT; y_index = y_index + 1) begin
                for (x_index = 0; x_index < IMAGE_WIDTH; x_index = x_index + 1) begin
                    for (
                        channel_index = 0;
                        channel_index < CHANNELS;
                        channel_index = channel_index + 1
                    ) begin
                        @(negedge clk);

                        input_valid = 1'b1;
                        input_x = x_index[7:0];
                        input_y = y_index[7:0];
                        input_channel_index = channel_index[7:0];
                        input_value = source_value(
                            frame_index,
                            x_index,
                            y_index,
                            channel_index
                        );

                        @(negedge clk);
                        input_valid = 1'b0;
                        input_value = 8'sd0;

                        repeat (2) @(negedge clk);
                    end
                end
            end

            input_valid = 1'b0;
            input_value = 8'sd0;
            input_x = 8'd0;
            input_y = 8'd0;
            input_channel_index = 8'd0;
        end
    endtask

    task drive_output_ready;
        begin
            while (output_count < EXPECTED_OUTPUT_COUNT) begin
                @(negedge clk);

                if (output_count < EXPECTED_OUTPUT_COUNT) begin
                    if (
                        ((ready_pattern_count % 7) == 2) ||
                        ((ready_pattern_count % 11) == 6)
                    ) begin
                        output_ready = 1'b0;
                    end else begin
                        output_ready = 1'b1;
                    end

                    ready_pattern_count = ready_pattern_count + 1;
                end else begin
                    output_ready = 1'b0;
                end
            end

            output_ready = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (!reset) begin
            if (input_valid) begin
                input_sample_count = input_sample_count + 1;
            end

            if (dut.fifo_enqueue && dut.fifo_dequeue) begin
                simultaneous_fifo_cycles =
                    simultaneous_fifo_cycles + 1;
            end

            if (output_valid === 1'bx) begin
                unknown_count = unknown_count + 1;
                error_count = error_count + 1;
                $display("ERROR: output_valid contains X/Z.");
            end

            if (output_valid === 1'b1) begin
                if (
                    ((^output_value) === 1'bx) ||
                    ((^output_padded_x) === 1'bx) ||
                    ((^output_padded_y) === 1'bx) ||
                    ((^output_channel_index) === 1'bx)
                ) begin
                    unknown_count = unknown_count + 1;
                    error_count = error_count + 1;
                    $display("ERROR: Valid padded output contains X/Z.");
                end
            end

            if (output_valid && !output_ready) begin
                downstream_stall_cycles =
                    downstream_stall_cycles + 1;

                if (!stall_holding) begin
                    stall_holding = 1'b1;
                    held_output_value = output_value;
                    held_output_padded_x = output_padded_x;
                    held_output_padded_y = output_padded_y;
                    held_output_channel = output_channel_index;
                    held_output_valid = output_valid;
                end else begin
                    held_output_checks = held_output_checks + 1;

                    if (
                        (output_value !== held_output_value) ||
                        (output_padded_x !== held_output_padded_x) ||
                        (output_padded_y !== held_output_padded_y) ||
                        (output_channel_index !== held_output_channel) ||
                        (output_valid !== held_output_valid)
                    ) begin
                        error_count = error_count + 1;
                        $display(
                            "ERROR: Padded output changed while downstream was stalled."
                        );
                    end
                end
            end else begin
                stall_holding = 1'b0;
            end

            if (output_ready && !output_valid) begin
                empty_wait_cycles = empty_wait_cycles + 1;
            end

            if (output_valid && output_ready) begin
                if (output_count >= EXPECTED_OUTPUT_COUNT) begin
                    error_count = error_count + 1;
                    $display(
                        "ERROR: Unexpected extra padded output value=%0d x=%0d y=%0d channel=%0d",
                        $signed(output_value),
                        output_padded_x,
                        output_padded_y,
                        output_channel_index
                    );
                end else begin
                    expected_frame =
                        output_count / FRAME_OUTPUT_COUNT;
                    expected_position =
                        output_count % FRAME_OUTPUT_COUNT;
                    expected_pixel =
                        expected_position / CHANNELS;
                    expected_channel =
                        expected_position % CHANNELS;
                    expected_padded_x =
                        expected_pixel % PADDED_WIDTH;
                    expected_padded_y =
                        expected_pixel / PADDED_WIDTH;

                    if (
                        (expected_padded_x == 0) ||
                        (expected_padded_y == 0) ||
                        (expected_padded_x == (PADDED_WIDTH - 1)) ||
                        (expected_padded_y == (PADDED_HEIGHT - 1))
                    ) begin
                        expected_value = 8'sd0;
                        border_output_count =
                            border_output_count + 1;
                    end else begin
                        expected_value = source_value(
                            expected_frame,
                            expected_padded_x - 1,
                            expected_padded_y - 1,
                            expected_channel
                        );
                        interior_output_count =
                            interior_output_count + 1;
                    end

                    if (output_padded_x !== expected_padded_x[7:0]) begin
                        error_count = error_count + 1;
                        $display(
                            "ERROR: Output %0d padded X expected=%0d received=%0d",
                            output_count,
                            expected_padded_x,
                            output_padded_x
                        );
                    end

                    if (output_padded_y !== expected_padded_y[7:0]) begin
                        error_count = error_count + 1;
                        $display(
                            "ERROR: Output %0d padded Y expected=%0d received=%0d",
                            output_count,
                            expected_padded_y,
                            output_padded_y
                        );
                    end

                    if (output_channel_index !== expected_channel[7:0]) begin
                        error_count = error_count + 1;
                        $display(
                            "ERROR: Output %0d channel expected=%0d received=%0d",
                            output_count,
                            expected_channel,
                            output_channel_index
                        );
                    end

                    if (output_value !== expected_value) begin
                        error_count = error_count + 1;
                        $display(
                            "ERROR: Output %0d frame=%0d value expected=%0d received=%0d at padded=(%0d,%0d) channel=%0d",
                            output_count,
                            expected_frame,
                            $signed(expected_value),
                            $signed(output_value),
                            expected_padded_x,
                            expected_padded_y,
                            expected_channel
                        );
                    end else if (
                        (output_padded_x === expected_padded_x[7:0]) &&
                        (output_padded_y === expected_padded_y[7:0]) &&
                        (output_channel_index === expected_channel[7:0])
                    ) begin
                        $display(
                            "PASS: Output %0d frame=%0d padded=(%0d,%0d) channel=%0d value=%0d",
                            output_count,
                            expected_frame,
                            output_padded_x,
                            output_padded_y,
                            output_channel_index,
                            $signed(output_value)
                        );
                    end
                end

                output_count = output_count + 1;
            end
        end
    end

    always @(posedge clk) begin
        #1;

        if (!reset) begin
            if ((^dut.fifo_count) === 1'bx) begin
                unknown_count = unknown_count + 1;
                error_count = error_count + 1;
                $display("ERROR: FIFO occupancy contains X/Z.");
            end else if (dut.fifo_count > fifo_peak) begin
                fifo_peak = dut.fifo_count;
            end
        end
    end

    initial begin
        $display("ACTIVE TB: streaming_same_padding_adapter_regression_tb CORRECTED-EDGE V1");
    end

    initial begin
        reset = 1'b1;
        input_value = 8'sd0;
        input_x = 8'd0;
        input_y = 8'd0;
        input_channel_index = 8'd0;
        input_valid = 1'b0;
        output_ready = 1'b0;

        error_count = 0;
        unknown_count = 0;
        input_sample_count = 0;
        output_count = 0;
        border_output_count = 0;
        interior_output_count = 0;
        downstream_stall_cycles = 0;
        empty_wait_cycles = 0;
        held_output_checks = 0;
        fifo_peak = 0;
        simultaneous_fifo_cycles = 0;
        ready_pattern_count = 0;

        expected_frame = 0;
        expected_position = 0;
        expected_pixel = 0;
        expected_padded_x = 0;
        expected_padded_y = 0;
        expected_channel = 0;
        expected_value = 8'sd0;

        stall_holding = 1'b0;
        held_output_value = 8'sd0;
        held_output_padded_x = 8'd0;
        held_output_padded_y = 8'd0;
        held_output_channel = 8'd0;
        held_output_valid = 1'b0;

        repeat (5) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        $display(
            "Buffering frame 0 completely while downstream is stalled..."
        );

        send_frame_continuous(0);

        repeat (2) @(posedge clk);
        #1;

        if (input_sample_count != FRAME_INPUT_COUNT) begin
            error_count = error_count + 1;
            $display(
                "ERROR: First-frame input count expected=%0d observed=%0d",
                FRAME_INPUT_COUNT,
                input_sample_count
            );
        end

        if (dut.fifo_count != FRAME_INPUT_COUNT) begin
            error_count = error_count + 1;
            $display(
                "ERROR: FIFO did not retain the complete stalled frame expected=%0d observed=%0d",
                FRAME_INPUT_COUNT,
                dut.fifo_count
            );
        end else begin
            $display(
                "PASS: FIFO retained all %0d frame-0 samples while output_ready=0.",
                FRAME_INPUT_COUNT
            );
        end

        if (overflow_error !== 1'b0) begin
            error_count = error_count + 1;
            $display("ERROR: overflow_error asserted during full-frame buffering.");
        end

        if (sequence_error !== 1'b0) begin
            error_count = error_count + 1;
            $display("ERROR: sequence_error asserted for correctly ordered frame 0.");
        end

        $display(
            "Releasing padded output and streaming frame 1 concurrently with deliberate stalls..."
        );

        fork
            drive_output_ready;
            send_frame_slow(1);
        join

        output_ready = 1'b0;
        input_valid = 1'b0;

        repeat (3) @(posedge clk);
        #1;

        if (input_sample_count != TOTAL_INPUT_COUNT) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Total input sample count expected=%0d observed=%0d",
                TOTAL_INPUT_COUNT,
                input_sample_count
            );
        end

        if (output_count != EXPECTED_OUTPUT_COUNT) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Padded output count expected=%0d observed=%0d",
                EXPECTED_OUTPUT_COUNT,
                output_count
            );
        end

        if (border_output_count != EXPECTED_BORDER_OUTPUTS) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Border output count expected=%0d observed=%0d",
                EXPECTED_BORDER_OUTPUTS,
                border_output_count
            );
        end

        if (interior_output_count != TOTAL_INPUT_COUNT) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Interior output count expected=%0d observed=%0d",
                TOTAL_INPUT_COUNT,
                interior_output_count
            );
        end

        if (dut.fifo_count != 0) begin
            error_count = error_count + 1;
            $display(
                "ERROR: FIFO not empty after two complete padded frames, occupancy=%0d",
                dut.fifo_count
            );
        end

        if (fifo_peak != FIFO_DEPTH) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Full-frame FIFO stress was not reached expected peak=%0d observed=%0d",
                FIFO_DEPTH,
                fifo_peak
            );
        end

        if (simultaneous_fifo_cycles == 0) begin
            error_count = error_count + 1;
            $display(
                "ERROR: Simultaneous FIFO enqueue/dequeue path was not exercised."
            );
        end

        if (downstream_stall_cycles == 0) begin
            error_count = error_count + 1;
            $display("ERROR: Downstream backpressure was not exercised.");
        end

        if (held_output_checks == 0) begin
            error_count = error_count + 1;
            $display("ERROR: No stalled-output stability checks were performed.");
        end

        if (overflow_error !== 1'b0) begin
            error_count = error_count + 1;
            $display("ERROR: overflow_error asserted.");
        end

        if (sequence_error !== 1'b0) begin
            error_count = error_count + 1;
            $display("ERROR: sequence_error asserted.");
        end

        if (unknown_count != 0) begin
            $display(
                "ERROR: Unknown-value checks reported %0d X/Z conditions.",
                unknown_count
            );
        end

        $display("================================================");
        $display("Streaming SAME-padding adapter verification complete");
        $display("Accepted unpadded samples = %0d", input_sample_count);
        $display("Expected padded outputs   = %0d", EXPECTED_OUTPUT_COUNT);
        $display("Observed padded outputs   = %0d", output_count);
        $display("Border zero outputs       = %0d", border_output_count);
        $display("Interior data outputs     = %0d", interior_output_count);
        $display("FIFO peak occupancy       = %0d", fifo_peak);
        $display("Simultaneous FIFO cycles  = %0d", simultaneous_fifo_cycles);
        $display("Downstream stall cycles   = %0d", downstream_stall_cycles);
        $display("Empty-wait cycles         = %0d", empty_wait_cycles);
        $display("Stalled-output checks     = %0d", held_output_checks);
        $display("overflow_error            = %0d", overflow_error);
        $display("sequence_error            = %0d", sequence_error);
        $display("X/Z errors                = %0d", unknown_count);
        $display("Total errors              = %0d", error_count);
        $display("================================================");

        if (error_count == 0) begin
            $display(
                "PASS: Full-frame buffering, exact SAME zero padding, two-frame ordering, simultaneous FIFO traffic, downstream backpressure and sticky error monitoring all matched the independent reference model."
            );
        end else begin
            $display(
                "FAIL: streaming_same_padding_adapter verification detected %0d errors.",
                error_count
            );
        end

        $finish;
    end

    initial begin
        repeat (4000) @(posedge clk);

        $display("ERROR: Testbench timeout before normal completion.");
        $finish;
    end

endmodule
