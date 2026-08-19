`timescale 1ns / 1ps

module streaming_cnn_temporal_feature_extractor_tb;

    localparam integer IMAGE_WIDTH                  = 64;
    localparam integer IMAGE_HEIGHT                 = 64;
    localparam integer CONV1_INPUT_CHANNELS         = 3;
    localparam integer CONV1_OUTPUT_CHANNELS        = 16;
    localparam integer CONV1_OUTPUT_GROUPS          = 4;
    localparam integer CONV1_MIN_GROUP_CYCLES       = 4;
    localparam integer CONV1_SCALE_MULT             = 1301962;
    localparam integer CONV1_SCALE_SHIFT            = 30;
    localparam integer CONV2_OUTPUT_CHANNELS        = 32;
    localparam integer CONV2_OUTPUT_GROUPS          = 8;
    localparam integer CONV2_MIN_GROUP_CYCLES       = 16;
    localparam integer CONV2_SCALE_MULT             = 1516810;
    localparam integer CONV2_SCALE_SHIFT            = 30;

    localparam integer FRAME_COUNT                  = 4;
    localparam integer PADDED_WIDTH                 = IMAGE_WIDTH + 2;
    localparam integer PADDED_HEIGHT                = IMAGE_HEIGHT + 2;

    localparam integer IMAGE_INPUT_COUNT            =
        IMAGE_WIDTH * IMAGE_HEIGHT * CONV1_INPUT_CHANNELS;

    localparam integer PADDED_INPUT_COUNT           =
        PADDED_WIDTH * PADDED_HEIGHT * CONV1_INPUT_CHANNELS;

    localparam integer CONV1_WEIGHT_COUNT           =
        CONV1_OUTPUT_CHANNELS * CONV1_INPUT_CHANNELS * 9;

    localparam integer CONV1_BIAS_COUNT             =
        CONV1_OUTPUT_CHANNELS;

    localparam integer POOL1_WIDTH                  =
        IMAGE_WIDTH / 2;

    localparam integer POOL1_HEIGHT                 =
        IMAGE_HEIGHT / 2;

    localparam integer POOL1_OUTPUT_COUNT           =
        POOL1_WIDTH * POOL1_HEIGHT * CONV1_OUTPUT_CHANNELS;

    localparam integer CONV2_WEIGHT_COUNT           =
        CONV2_OUTPUT_CHANNELS * CONV1_OUTPUT_CHANNELS * 9;

    localparam integer CONV2_BIAS_COUNT             =
        CONV2_OUTPUT_CHANNELS;

    localparam integer FINAL_FEATURE_WIDTH          =
        IMAGE_WIDTH / 4;

    localparam integer FINAL_FEATURE_HEIGHT         =
        IMAGE_HEIGHT / 4;

    localparam integer FEATURES_PER_FRAME           =
        FINAL_FEATURE_WIDTH *
        FINAL_FEATURE_HEIGHT *
        CONV2_OUTPUT_CHANNELS;

    localparam integer TOTAL_TEMPORAL_FEATURES      =
        FRAME_COUNT * FEATURES_PER_FRAME;

    localparam integer CONV2_PADDING_FIFO_DEPTH     =
        POOL1_OUTPUT_COUNT;

    localparam integer CLOCK_HALF_PERIOD            = 5;
    localparam integer MAX_CLOCK_TOGGLES            = 6000000;
    localparam integer MAX_FRAME_WAIT_CYCLES        = 500000;
    localparam integer MAX_CAPTURE_WAIT_CYCLES      = 10000;
    localparam integer MAX_REPORTED_ERRORS          = 20;

    reg                     clk;
    reg                     reset;
    reg                     temporal_capture_reset;

    reg                     input_valid;
    wire                    input_ready;
    reg signed [7:0]        input_value;

    reg                     conv1_weight_memory_write_enable;
    reg [12:0]              conv1_weight_memory_write_address;
    reg signed [7:0]        conv1_weight_memory_write_data;

    reg                     conv1_bias_memory_write_enable;
    reg [5:0]               conv1_bias_memory_write_address;
    reg signed [31:0]       conv1_bias_memory_write_data;

    reg                     conv2_weight_memory_write_enable;
    reg [12:0]              conv2_weight_memory_write_address;
    reg signed [7:0]        conv2_weight_memory_write_data;

    reg                     conv2_bias_memory_write_enable;
    reg [5:0]               conv2_bias_memory_write_address;
    reg signed [31:0]       conv2_bias_memory_write_data;

    wire [7:0]              conv1_requested_channel_index;
    wire [7:0]              conv2_requested_channel_index;

    wire signed [7:0]       feature_stream_value;
    wire [12:0]             feature_stream_address;
    wire                    feature_stream_valid;
    wire                    feature_stream_frame_done;

    reg [14:0]              temporal_feature_read_address;
    wire signed [7:0]       temporal_feature_read_data;
    wire [2:0]              temporal_captured_frame_count;
    wire                    temporal_capture_complete;

    wire                    reorder_capture_busy;
    wire                    reorder_drain_busy;

    wire                    conv1_requantize_busy;
    wire                    conv2_requantize_busy;

    wire                    conv2_padding_overflow_error;
    wire                    conv2_padding_sequence_error;

    wire                    reorder_sequence_error;
    wire                    reorder_metadata_error;
    wire                    reorder_overflow_error;

    reg signed [7:0]        input_frame_0_rom
        [0:IMAGE_INPUT_COUNT-1];

    reg signed [7:0]        input_frame_1_rom
        [0:IMAGE_INPUT_COUNT-1];

    reg signed [7:0]        input_frame_2_rom
        [0:IMAGE_INPUT_COUNT-1];

    reg signed [7:0]        input_frame_3_rom
        [0:IMAGE_INPUT_COUNT-1];

    reg signed [7:0]        conv1_weight_rom
        [0:CONV1_WEIGHT_COUNT-1];

    reg signed [31:0]       conv1_bias_rom
        [0:CONV1_BIAS_COUNT-1];

    reg signed [7:0]        conv2_weight_rom
        [0:CONV2_WEIGHT_COUNT-1];

    reg signed [31:0]       conv2_bias_rom
        [0:CONV2_BIAS_COUNT-1];

    reg signed [7:0]        expected_frame_0_rom
        [0:FEATURES_PER_FRAME-1];

    reg signed [7:0]        expected_frame_1_rom
        [0:FEATURES_PER_FRAME-1];

    reg signed [7:0]        expected_frame_2_rom
        [0:FEATURES_PER_FRAME-1];

    reg signed [7:0]        expected_frame_3_rom
        [0:FEATURES_PER_FRAME-1];

    reg                     stream_output_seen
        [0:TOTAL_TEMPORAL_FEATURES-1];

    integer accepted_padded_input_count;
    integer expected_total_padded_inputs;
    integer upstream_backpressure_cycles;

    integer stream_output_count;
    integer stream_frame_done_count;

    integer conv1_weight_load_count;
    integer conv1_bias_load_count;
    integer conv2_weight_load_count;
    integer conv2_bias_load_count;

    integer conv1_requantize_busy_cycles;
    integer conv2_requantize_busy_cycles;
    integer reorder_capture_busy_cycles;
    integer reorder_drain_busy_cycles;

    integer stream_mismatch_count;
    integer stream_address_error_count;
    integer stream_unknown_count;
    integer stream_duplicate_count;
    integer stream_missing_count;
    integer stream_extra_count;
    integer stream_frame_done_error_count;

    integer buffer_read_count;
    integer buffer_mismatch_count;
    integer buffer_unknown_count;

    integer frame_run_index;
    integer frame_wait_cycle_count;
    integer capture_wait_cycle_count;
    integer temporal_read_index;
    integer temporal_read_frame_index;
    integer temporal_read_feature_index;
    integer initialization_index;

    integer monitor_frame_index;
    integer monitor_feature_index;
    integer monitor_temporal_index;

    reg signed [7:0] expected_monitor_value;
    reg signed [7:0] expected_buffer_value;

    integer error_count;

    reg simulation_complete;
    reg simulation_pass;
    reg simulation_fail;

    streaming_cnn_temporal_feature_extractor #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .CONV1_INPUT_CHANNELS(CONV1_INPUT_CHANNELS),
        .CONV1_OUTPUT_CHANNELS(CONV1_OUTPUT_CHANNELS),
        .CONV1_OUTPUT_GROUPS(CONV1_OUTPUT_GROUPS),
        .CONV1_MIN_GROUP_CYCLES(CONV1_MIN_GROUP_CYCLES),
        .CONV1_SCALE_MULT(CONV1_SCALE_MULT),
        .CONV1_SCALE_SHIFT(CONV1_SCALE_SHIFT),
        .CONV1_METADATA_FIFO_DEPTH(32),
        .CONV2_OUTPUT_CHANNELS(CONV2_OUTPUT_CHANNELS),
        .CONV2_OUTPUT_GROUPS(CONV2_OUTPUT_GROUPS),
        .CONV2_MIN_GROUP_CYCLES(CONV2_MIN_GROUP_CYCLES),
        .CONV2_SCALE_MULT(CONV2_SCALE_MULT),
        .CONV2_SCALE_SHIFT(CONV2_SCALE_SHIFT),
        .CONV2_PADDING_FIFO_DEPTH(CONV2_PADDING_FIFO_DEPTH),
        .CONV2_METADATA_FIFO_DEPTH(32)
    ) dut (
        .clk(clk),
        .reset(reset),
        .temporal_capture_reset(temporal_capture_reset),

        .input_valid(input_valid),
        .input_ready(input_ready),
        .input_value(input_value),

        .conv1_weight_memory_write_enable(
            conv1_weight_memory_write_enable
        ),
        .conv1_weight_memory_write_address(
            conv1_weight_memory_write_address
        ),
        .conv1_weight_memory_write_data(
            conv1_weight_memory_write_data
        ),

        .conv1_bias_memory_write_enable(
            conv1_bias_memory_write_enable
        ),
        .conv1_bias_memory_write_address(
            conv1_bias_memory_write_address
        ),
        .conv1_bias_memory_write_data(
            conv1_bias_memory_write_data
        ),

        .conv2_weight_memory_write_enable(
            conv2_weight_memory_write_enable
        ),
        .conv2_weight_memory_write_address(
            conv2_weight_memory_write_address
        ),
        .conv2_weight_memory_write_data(
            conv2_weight_memory_write_data
        ),

        .conv2_bias_memory_write_enable(
            conv2_bias_memory_write_enable
        ),
        .conv2_bias_memory_write_address(
            conv2_bias_memory_write_address
        ),
        .conv2_bias_memory_write_data(
            conv2_bias_memory_write_data
        ),

        .conv1_requested_channel_index(
            conv1_requested_channel_index
        ),
        .conv2_requested_channel_index(
            conv2_requested_channel_index
        ),

        .feature_stream_value(feature_stream_value),
        .feature_stream_address(feature_stream_address),
        .feature_stream_valid(feature_stream_valid),
        .feature_stream_frame_done(feature_stream_frame_done),

        .temporal_feature_read_address(
            temporal_feature_read_address
        ),
        .temporal_feature_read_data(
            temporal_feature_read_data
        ),
        .temporal_captured_frame_count(
            temporal_captured_frame_count
        ),
        .temporal_capture_complete(
            temporal_capture_complete
        ),

        .reorder_capture_busy(reorder_capture_busy),
        .reorder_drain_busy(reorder_drain_busy),

        .conv1_requantize_busy(conv1_requantize_busy),
        .conv2_requantize_busy(conv2_requantize_busy),

        .conv2_padding_overflow_error(
            conv2_padding_overflow_error
        ),
        .conv2_padding_sequence_error(
            conv2_padding_sequence_error
        ),

        .reorder_sequence_error(reorder_sequence_error),
        .reorder_metadata_error(reorder_metadata_error),
        .reorder_overflow_error(reorder_overflow_error)
    );

    function signed [7:0] frame_input_value;
        input integer frame_number;
        input integer source_address;
        begin
            case (frame_number)
                0: frame_input_value =
                    input_frame_0_rom[source_address];

                1: frame_input_value =
                    input_frame_1_rom[source_address];

                2: frame_input_value =
                    input_frame_2_rom[source_address];

                default: frame_input_value =
                    input_frame_3_rom[source_address];
            endcase
        end
    endfunction

    function signed [7:0] frame_expected_value;
        input integer frame_number;
        input integer feature_address;
        begin
            case (frame_number)
                0: frame_expected_value =
                    expected_frame_0_rom[feature_address];

                1: frame_expected_value =
                    expected_frame_1_rom[feature_address];

                2: frame_expected_value =
                    expected_frame_2_rom[feature_address];

                default: frame_expected_value =
                    expected_frame_3_rom[feature_address];
            endcase
        end
    endfunction

    function signed [7:0] padded_frame_input_value;
        input integer frame_number;
        input integer padded_x;
        input integer padded_y;
        input integer channel_index;
        integer source_x;
        integer source_y;
        integer source_address;
        begin
            if (
                (padded_x == 0) ||
                (padded_x == PADDED_WIDTH - 1) ||
                (padded_y == 0) ||
                (padded_y == PADDED_HEIGHT - 1)
            ) begin
                padded_frame_input_value = 8'sd0;
            end else begin
                source_x = padded_x - 1;
                source_y = padded_y - 1;

                source_address =
                    (channel_index * IMAGE_WIDTH * IMAGE_HEIGHT) +
                    (source_y * IMAGE_WIDTH) +
                    source_x;

                padded_frame_input_value =
                    frame_input_value(
                        frame_number,
                        source_address
                    );
            end
        end
    endfunction

    task load_conv1_parameters;
        integer parameter_index;
        begin
            $display(
                "Loading actual Conv1 parameters once..."
            );

            for (
                parameter_index = 0;
                parameter_index < CONV1_WEIGHT_COUNT;
                parameter_index = parameter_index + 1
            ) begin
                @(negedge clk);

                conv1_weight_memory_write_enable = 1'b1;
                conv1_weight_memory_write_address =
                    parameter_index[12:0];
                conv1_weight_memory_write_data =
                    conv1_weight_rom[parameter_index];
            end

            @(negedge clk);

            conv1_weight_memory_write_enable = 1'b0;
            conv1_weight_memory_write_address = 13'd0;
            conv1_weight_memory_write_data = 8'sd0;

            for (
                parameter_index = 0;
                parameter_index < CONV1_BIAS_COUNT;
                parameter_index = parameter_index + 1
            ) begin
                @(negedge clk);

                conv1_bias_memory_write_enable = 1'b1;
                conv1_bias_memory_write_address =
                    parameter_index[5:0];
                conv1_bias_memory_write_data =
                    conv1_bias_rom[parameter_index];
            end

            @(negedge clk);

            conv1_bias_memory_write_enable = 1'b0;
            conv1_bias_memory_write_address = 6'd0;
            conv1_bias_memory_write_data = 32'sd0;

            conv1_weight_load_count =
                CONV1_WEIGHT_COUNT;

            conv1_bias_load_count =
                CONV1_BIAS_COUNT;

            $display(
                "Loaded %0d Conv1 weights and %0d Conv1 biases.",
                conv1_weight_load_count,
                conv1_bias_load_count
            );
        end
    endtask

    task load_conv2_parameters;
        integer parameter_index;
        begin
            $display(
                "Loading actual Conv2 parameters once..."
            );

            for (
                parameter_index = 0;
                parameter_index < CONV2_WEIGHT_COUNT;
                parameter_index = parameter_index + 1
            ) begin
                @(negedge clk);

                conv2_weight_memory_write_enable = 1'b1;
                conv2_weight_memory_write_address =
                    parameter_index[12:0];
                conv2_weight_memory_write_data =
                    conv2_weight_rom[parameter_index];
            end

            @(negedge clk);

            conv2_weight_memory_write_enable = 1'b0;
            conv2_weight_memory_write_address = 13'd0;
            conv2_weight_memory_write_data = 8'sd0;

            for (
                parameter_index = 0;
                parameter_index < CONV2_BIAS_COUNT;
                parameter_index = parameter_index + 1
            ) begin
                @(negedge clk);

                conv2_bias_memory_write_enable = 1'b1;
                conv2_bias_memory_write_address =
                    parameter_index[5:0];
                conv2_bias_memory_write_data =
                    conv2_bias_rom[parameter_index];
            end

            @(negedge clk);

            conv2_bias_memory_write_enable = 1'b0;
            conv2_bias_memory_write_address = 6'd0;
            conv2_bias_memory_write_data = 32'sd0;

            conv2_weight_load_count =
                CONV2_WEIGHT_COUNT;

            conv2_bias_load_count =
                CONV2_BIAS_COUNT;

            $display(
                "Loaded %0d Conv2 weights and %0d Conv2 biases.",
                conv2_weight_load_count,
                conv2_bias_load_count
            );
        end
    endtask

    task send_padded_sample;
        input signed [7:0] sample_value;
        integer sample_accepted;
        begin
            sample_accepted = 0;

            while (!sample_accepted) begin
                @(negedge clk);

                input_valid = 1'b1;
                input_value = sample_value;

                if (input_ready === 1'b1) begin
                    @(posedge clk);
                    sample_accepted = 1;
                end else begin
                    upstream_backpressure_cycles =
                        upstream_backpressure_cycles + 1;
                end
            end
        end
    endtask

    task send_real_frame;
        input integer frame_number;
        integer padded_x;
        integer padded_y;
        integer channel_index;
        reg signed [7:0] padded_value;
        begin
            $display(
                "Sending real frame %0d through complete CNN + temporal-capture path...",
                frame_number
            );

            for (
                padded_y = 0;
                padded_y < PADDED_HEIGHT;
                padded_y = padded_y + 1
            ) begin
                for (
                    padded_x = 0;
                    padded_x < PADDED_WIDTH;
                    padded_x = padded_x + 1
                ) begin
                    for (
                        channel_index = 0;
                        channel_index < CONV1_INPUT_CHANNELS;
                        channel_index = channel_index + 1
                    ) begin
                        padded_value =
                            padded_frame_input_value(
                                frame_number,
                                padded_x,
                                padded_y,
                                channel_index
                            );

                        send_padded_sample(
                            padded_value
                        );
                    end
                end
            end

            @(negedge clk);

            input_valid = 1'b0;
            input_value = 8'sd0;
        end
    endtask

    task verify_temporal_buffer;
        begin
            $display(
                "Reading back and checking all %0d temporal-buffer values...",
                TOTAL_TEMPORAL_FEATURES
            );

            for (
                temporal_read_index = 0;
                temporal_read_index < TOTAL_TEMPORAL_FEATURES;
                temporal_read_index = temporal_read_index + 1
            ) begin
                temporal_read_frame_index =
                    temporal_read_index / FEATURES_PER_FRAME;

                temporal_read_feature_index =
                    temporal_read_index % FEATURES_PER_FRAME;

                expected_buffer_value =
                    frame_expected_value(
                        temporal_read_frame_index,
                        temporal_read_feature_index
                    );

                @(negedge clk);

                temporal_feature_read_address =
                    temporal_read_index[14:0];

                @(posedge clk);
                #1;

                buffer_read_count =
                    buffer_read_count + 1;

                if (
                    (^temporal_feature_read_data) === 1'bx
                ) begin
                    buffer_unknown_count =
                        buffer_unknown_count + 1;

                    error_count =
                        error_count + 1;

                    if (
                        buffer_unknown_count <=
                        MAX_REPORTED_ERRORS
                    ) begin
                        $display(
                            "ERROR: Temporal buffer X/Z at frame=%0d feature=%0d address=%0d.",
                            temporal_read_frame_index,
                            temporal_read_feature_index,
                            temporal_read_index
                        );
                    end
                end else if (
                    temporal_feature_read_data !==
                    expected_buffer_value
                ) begin
                    buffer_mismatch_count =
                        buffer_mismatch_count + 1;

                    error_count =
                        error_count + 1;

                    if (
                        buffer_mismatch_count <=
                        MAX_REPORTED_ERRORS
                    ) begin
                        $display(
                            "ERROR: Temporal buffer frame=%0d feature=%0d address=%0d expected=%0d received=%0d.",
                            temporal_read_frame_index,
                            temporal_read_feature_index,
                            temporal_read_index,
                            $signed(expected_buffer_value),
                            $signed(temporal_feature_read_data)
                        );
                    end
                end
            end
        end
    endtask

    initial begin
        clk = 1'b0;

        repeat (MAX_CLOCK_TOGGLES) begin
            #CLOCK_HALF_PERIOD clk = ~clk;
        end

        if (!simulation_complete) begin
            $display(
                "FAIL: Temporal integration regression exceeded the finite clock budget."
            );
            $finish;
        end
    end

    always @(posedge clk) begin
        if (!reset) begin
            if (input_valid && input_ready) begin
                accepted_padded_input_count =
                    accepted_padded_input_count + 1;
            end

            if (conv1_requantize_busy) begin
                conv1_requantize_busy_cycles =
                    conv1_requantize_busy_cycles + 1;
            end

            if (conv2_requantize_busy) begin
                conv2_requantize_busy_cycles =
                    conv2_requantize_busy_cycles + 1;
            end

            if (reorder_capture_busy) begin
                reorder_capture_busy_cycles =
                    reorder_capture_busy_cycles + 1;
            end

            if (reorder_drain_busy) begin
                reorder_drain_busy_cycles =
                    reorder_drain_busy_cycles + 1;
            end
        end
    end

    always @(posedge clk) begin
        #1;

        if (!reset && !temporal_capture_reset) begin
            if (feature_stream_valid) begin
                monitor_frame_index =
                    stream_output_count / FEATURES_PER_FRAME;

                monitor_feature_index =
                    stream_output_count % FEATURES_PER_FRAME;

                monitor_temporal_index =
                    (monitor_frame_index * FEATURES_PER_FRAME) +
                    monitor_feature_index;

                if (
                    (^feature_stream_value === 1'bx) ||
                    (^feature_stream_address === 1'bx)
                ) begin
                    stream_unknown_count =
                        stream_unknown_count + 1;

                    error_count =
                        error_count + 1;

                    if (
                        stream_unknown_count <=
                        MAX_REPORTED_ERRORS
                    ) begin
                        $display(
                            "ERROR: X/Z on live feature stream at temporal index %0d.",
                            stream_output_count
                        );
                    end
                end

                if (
                    stream_output_count >=
                    TOTAL_TEMPORAL_FEATURES
                ) begin
                    stream_extra_count =
                        stream_extra_count + 1;

                    error_count =
                        error_count + 1;

                    if (
                        stream_extra_count <=
                        MAX_REPORTED_ERRORS
                    ) begin
                        $display(
                            "ERROR: Extra feature stream output address=%0d value=%0d.",
                            feature_stream_address,
                            $signed(feature_stream_value)
                        );
                    end
                end else begin
                    if (
                        feature_stream_address !==
                        monitor_feature_index[12:0]
                    ) begin
                        stream_address_error_count =
                            stream_address_error_count + 1;

                        error_count =
                            error_count + 1;

                        if (
                            stream_address_error_count <=
                            MAX_REPORTED_ERRORS
                        ) begin
                            $display(
                                "ERROR: Frame %0d stream feature %0d address expected=%0d received=%0d.",
                                monitor_frame_index,
                                monitor_feature_index,
                                monitor_feature_index,
                                feature_stream_address
                            );
                        end
                    end

                    expected_monitor_value =
                        frame_expected_value(
                            monitor_frame_index,
                            monitor_feature_index
                        );

                    if (
                        feature_stream_value !==
                        expected_monitor_value
                    ) begin
                        stream_mismatch_count =
                            stream_mismatch_count + 1;

                        error_count =
                            error_count + 1;

                        if (
                            stream_mismatch_count <=
                            MAX_REPORTED_ERRORS
                        ) begin
                            $display(
                                "ERROR: Frame %0d stream feature %0d expected=%0d received=%0d.",
                                monitor_frame_index,
                                monitor_feature_index,
                                $signed(expected_monitor_value),
                                $signed(feature_stream_value)
                            );
                        end
                    end

                    if (
                        stream_output_seen[
                            monitor_temporal_index
                        ]
                    ) begin
                        stream_duplicate_count =
                            stream_duplicate_count + 1;

                        error_count =
                            error_count + 1;

                        if (
                            stream_duplicate_count <=
                            MAX_REPORTED_ERRORS
                        ) begin
                            $display(
                                "ERROR: Duplicate live stream temporal index %0d.",
                                monitor_temporal_index
                            );
                        end
                    end else begin
                        stream_output_seen[
                            monitor_temporal_index
                        ] = 1'b1;
                    end
                end

                stream_output_count =
                    stream_output_count + 1;
            end

            if (feature_stream_frame_done) begin
                if (!feature_stream_valid) begin
                    stream_frame_done_error_count =
                        stream_frame_done_error_count + 1;

                    error_count =
                        error_count + 1;

                    $display(
                        "ERROR: feature_stream_frame_done asserted without feature_stream_valid."
                    );
                end

                if (
                    feature_stream_address !==
                    FEATURES_PER_FRAME - 1
                ) begin
                    stream_frame_done_error_count =
                        stream_frame_done_error_count + 1;

                    error_count =
                        error_count + 1;

                    $display(
                        "ERROR: Frame %0d stream done at address %0d instead of %0d.",
                        stream_frame_done_count,
                        feature_stream_address,
                        FEATURES_PER_FRAME - 1
                    );
                end

                stream_frame_done_count =
                    stream_frame_done_count + 1;

                $display(
                    "Live stream frame %0d completed.",
                    stream_frame_done_count - 1
                );
            end
        end
    end

    initial begin
        $readmemh(
            "sequence_000_frame_0_input.mem",
            input_frame_0_rom
        );

        $readmemh(
            "sequence_000_frame_1_input.mem",
            input_frame_1_rom
        );

        $readmemh(
            "sequence_000_frame_2_input.mem",
            input_frame_2_rom
        );

        $readmemh(
            "sequence_000_frame_3_input.mem",
            input_frame_3_rom
        );

        $readmemh(
            "conv1_w.mem",
            conv1_weight_rom
        );

        $readmemh(
            "conv1_b_int32_correct.mem",
            conv1_bias_rom
        );

        $readmemh(
            "conv2_w.mem",
            conv2_weight_rom
        );

        $readmemh(
            "conv2_b_int32_correct.mem",
            conv2_bias_rom
        );

        $readmemh(
            "sequence_000_frame_0_expected.mem",
            expected_frame_0_rom
        );

        $readmemh(
            "sequence_000_frame_1_expected.mem",
            expected_frame_1_rom
        );

        $readmemh(
            "sequence_000_frame_2_expected.mem",
            expected_frame_2_rom
        );

        $readmemh(
            "sequence_000_frame_3_expected.mem",
            expected_frame_3_rom
        );
    end

    initial begin
        reset = 1'b1;
        temporal_capture_reset = 1'b1;

        input_valid = 1'b0;
        input_value = 8'sd0;

        conv1_weight_memory_write_enable = 1'b0;
        conv1_weight_memory_write_address = 13'd0;
        conv1_weight_memory_write_data = 8'sd0;

        conv1_bias_memory_write_enable = 1'b0;
        conv1_bias_memory_write_address = 6'd0;
        conv1_bias_memory_write_data = 32'sd0;

        conv2_weight_memory_write_enable = 1'b0;
        conv2_weight_memory_write_address = 13'd0;
        conv2_weight_memory_write_data = 8'sd0;

        conv2_bias_memory_write_enable = 1'b0;
        conv2_bias_memory_write_address = 6'd0;
        conv2_bias_memory_write_data = 32'sd0;

        temporal_feature_read_address = 15'd0;

        accepted_padded_input_count = 0;
        expected_total_padded_inputs =
            FRAME_COUNT * PADDED_INPUT_COUNT;

        upstream_backpressure_cycles = 0;

        stream_output_count = 0;
        stream_frame_done_count = 0;

        conv1_weight_load_count = 0;
        conv1_bias_load_count = 0;
        conv2_weight_load_count = 0;
        conv2_bias_load_count = 0;

        conv1_requantize_busy_cycles = 0;
        conv2_requantize_busy_cycles = 0;
        reorder_capture_busy_cycles = 0;
        reorder_drain_busy_cycles = 0;

        stream_mismatch_count = 0;
        stream_address_error_count = 0;
        stream_unknown_count = 0;
        stream_duplicate_count = 0;
        stream_missing_count = 0;
        stream_extra_count = 0;
        stream_frame_done_error_count = 0;

        buffer_read_count = 0;
        buffer_mismatch_count = 0;
        buffer_unknown_count = 0;

        error_count = 0;

        simulation_complete = 1'b0;
        simulation_pass = 1'b0;
        simulation_fail = 1'b0;

        for (
            initialization_index = 0;
            initialization_index < TOTAL_TEMPORAL_FEATURES;
            initialization_index = initialization_index + 1
        ) begin
            stream_output_seen[
                initialization_index
            ] = 1'b0;
        end

        $display(
            "ACTIVE TB: streaming_cnn_temporal_feature_extractor_tb ACTUAL-VECTORS TEMPORAL-BRAM V1"
        );

        repeat (6) @(posedge clk);

        load_conv1_parameters();
        load_conv2_parameters();

        repeat (3) @(posedge clk);

        @(negedge clk);

        reset = 1'b0;
        temporal_capture_reset = 1'b1;

        repeat (2) @(posedge clk);

        @(negedge clk);

        temporal_capture_reset = 1'b0;

        repeat (3) @(posedge clk);

        for (
            frame_run_index = 0;
            frame_run_index < FRAME_COUNT;
            frame_run_index = frame_run_index + 1
        ) begin
            if (frame_run_index != 0) begin
                while (!reorder_capture_busy) begin
                    @(posedge clk);
                end

                repeat (5) @(posedge clk);
            end

            send_real_frame(
                frame_run_index
            );

            frame_wait_cycle_count = 0;

            while (
                (stream_frame_done_count < frame_run_index + 1) &&
                (frame_wait_cycle_count < MAX_FRAME_WAIT_CYCLES)
            ) begin
                @(posedge clk);

                frame_wait_cycle_count =
                    frame_wait_cycle_count + 1;
            end

            if (
                stream_frame_done_count <
                frame_run_index + 1
            ) begin
                error_count =
                    error_count + 1;

                $display(
                    "ERROR: Timed out waiting for live stream frame %0d completion.",
                    frame_run_index
                );
            end
        end

        capture_wait_cycle_count = 0;

        while (
            (temporal_capture_complete !== 1'b1) &&
            (capture_wait_cycle_count < MAX_CAPTURE_WAIT_CYCLES)
        ) begin
            @(posedge clk);

            capture_wait_cycle_count =
                capture_wait_cycle_count + 1;
        end

        if (
            temporal_capture_complete !== 1'b1
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: temporal_capture_complete did not assert."
            );
        end

        if (
            temporal_captured_frame_count !== 3'd4
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: temporal_captured_frame_count expected=4 received=%0d.",
                temporal_captured_frame_count
            );
        end

        repeat (5) @(posedge clk);

        verify_temporal_buffer();

        for (
            initialization_index = 0;
            initialization_index < TOTAL_TEMPORAL_FEATURES;
            initialization_index = initialization_index + 1
        ) begin
            if (
                !stream_output_seen[
                    initialization_index
                ]
            ) begin
                stream_missing_count =
                    stream_missing_count + 1;

                error_count =
                    error_count + 1;

                if (
                    stream_missing_count <=
                    MAX_REPORTED_ERRORS
                ) begin
                    $display(
                        "ERROR: Missing live stream temporal index %0d.",
                        initialization_index
                    );
                end
            end
        end

        if (
            accepted_padded_input_count !=
            expected_total_padded_inputs
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Accepted padded inputs expected=%0d received=%0d.",
                expected_total_padded_inputs,
                accepted_padded_input_count
            );
        end

        if (
            stream_output_count !=
            TOTAL_TEMPORAL_FEATURES
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Live stream outputs expected=%0d received=%0d.",
                TOTAL_TEMPORAL_FEATURES,
                stream_output_count
            );
        end

        if (
            stream_frame_done_count !=
            FRAME_COUNT
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Live stream frame-done count expected=%0d received=%0d.",
                FRAME_COUNT,
                stream_frame_done_count
            );
        end

        if (
            buffer_read_count !=
            TOTAL_TEMPORAL_FEATURES
        ) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: Temporal buffer read count expected=%0d received=%0d.",
                TOTAL_TEMPORAL_FEATURES,
                buffer_read_count
            );
        end

        if (conv2_padding_overflow_error) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: conv2_padding_overflow_error asserted."
            );
        end

        if (conv2_padding_sequence_error) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: conv2_padding_sequence_error asserted."
            );
        end

        if (reorder_sequence_error) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: reorder_sequence_error asserted."
            );
        end

        if (reorder_metadata_error) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: reorder_metadata_error asserted."
            );
        end

        if (reorder_overflow_error) begin
            error_count =
                error_count + 1;

            $display(
                "ERROR: reorder_overflow_error asserted."
            );
        end

        $display(
            "================================================"
        );
        $display(
            "Streaming CNN + temporal BRAM verification complete"
        );
        $display(
            "Frames processed               = %0d",
            FRAME_COUNT
        );
        $display(
            "Conv1 weights loaded           = %0d",
            conv1_weight_load_count
        );
        $display(
            "Conv1 biases loaded            = %0d",
            conv1_bias_load_count
        );
        $display(
            "Conv2 weights loaded           = %0d",
            conv2_weight_load_count
        );
        $display(
            "Conv2 biases loaded            = %0d",
            conv2_bias_load_count
        );
        $display(
            "Accepted padded inputs         = %0d",
            accepted_padded_input_count
        );
        $display(
            "Expected padded inputs         = %0d",
            expected_total_padded_inputs
        );
        $display(
            "Upstream backpressure cycles  = %0d",
            upstream_backpressure_cycles
        );
        $display(
            "Live feature stream values     = %0d",
            stream_output_count
        );
        $display(
            "Expected stream values         = %0d",
            TOTAL_TEMPORAL_FEATURES
        );
        $display(
            "Live frame-done pulses         = %0d",
            stream_frame_done_count
        );
        $display(
            "Captured temporal frames       = %0d",
            temporal_captured_frame_count
        );
        $display(
            "temporal_capture_complete      = %0d",
            temporal_capture_complete
        );
        $display(
            "Temporal buffer values checked = %0d",
            buffer_read_count
        );
        $display(
            "Conv1 requantize busy cycles   = %0d",
            conv1_requantize_busy_cycles
        );
        $display(
            "Conv2 requantize busy cycles   = %0d",
            conv2_requantize_busy_cycles
        );
        $display(
            "Reorder capture-busy cycles    = %0d",
            reorder_capture_busy_cycles
        );
        $display(
            "Reorder drain-busy cycles      = %0d",
            reorder_drain_busy_cycles
        );
        $display(
            "Stream mismatches              = %0d",
            stream_mismatch_count
        );
        $display(
            "Stream address errors          = %0d",
            stream_address_error_count
        );
        $display(
            "Stream frame-done errors       = %0d",
            stream_frame_done_error_count
        );
        $display(
            "Stream duplicate outputs       = %0d",
            stream_duplicate_count
        );
        $display(
            "Stream missing outputs         = %0d",
            stream_missing_count
        );
        $display(
            "Stream extra outputs           = %0d",
            stream_extra_count
        );
        $display(
            "Stream X/Z errors              = %0d",
            stream_unknown_count
        );
        $display(
            "Buffer mismatches              = %0d",
            buffer_mismatch_count
        );
        $display(
            "Buffer X/Z errors              = %0d",
            buffer_unknown_count
        );
        $display(
            "conv2_padding_overflow_error   = %0d",
            conv2_padding_overflow_error
        );
        $display(
            "conv2_padding_sequence_error   = %0d",
            conv2_padding_sequence_error
        );
        $display(
            "reorder_sequence_error         = %0d",
            reorder_sequence_error
        );
        $display(
            "reorder_metadata_error         = %0d",
            reorder_metadata_error
        );
        $display(
            "reorder_overflow_error         = %0d",
            reorder_overflow_error
        );
        $display(
            "Total errors                   = %0d",
            error_count
        );
        $display(
            "================================================"
        );

        if (error_count == 0) begin
            simulation_pass = 1'b1;

            $display(
                "PASS: Four real frames produced 32768 exact live CNN features and all 32768 values were captured and read back from temporal BRAM with full expected-vector agreement."
            );
        end else begin
            simulation_fail = 1'b1;

            $display(
                "FAIL: Streaming CNN + temporal BRAM regression found %0d total errors.",
                error_count
            );
        end

        simulation_complete = 1'b1;

        #20;
        $finish;
    end

endmodule
