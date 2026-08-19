`timescale 1ns / 1ps

module cnn_feature_streaming_nexys_video_top (
    input  wire       clk,
    input  wire       reset_button,
    input  wire       start_button,
    output wire [7:0] led
);
    localparam integer IMAGE_WIDTH               = 64;
    localparam integer IMAGE_HEIGHT              = 64;
    localparam integer INPUT_CHANNELS            = 3;
    localparam integer PADDED_WIDTH              = 66;
    localparam integer PADDED_HEIGHT             = 66;
    localparam integer IMAGE_VALUES_PER_FRAME    = 12288;
    localparam integer CONV1_WEIGHT_COUNT        = 432;
    localparam integer CONV1_BIAS_COUNT          = 16;
    localparam integer CONV2_WEIGHT_COUNT        = 4608;
    localparam integer CONV2_BIAS_COUNT          = 32;
    localparam [3:0] STATE_IDLE                  = 4'd0;
    localparam [3:0] STATE_CAPTURE_RESET         = 4'd1;
    localparam [3:0] STATE_LOAD_CONV1_WEIGHT     = 4'd2;
    localparam [3:0] STATE_LOAD_CONV1_BIAS       = 4'd3;
    localparam [3:0] STATE_LOAD_CONV2_WEIGHT     = 4'd4;
    localparam [3:0] STATE_LOAD_CONV2_BIAS       = 4'd5;
    localparam [3:0] STATE_FRAME_PREP            = 4'd6;
    localparam [3:0] STATE_STREAM_REQUEST        = 4'd7;
    localparam [3:0] STATE_STREAM_ROM_WAIT       = 4'd8;
    localparam [3:0] STATE_STREAM_SEND           = 4'd9;
    localparam [3:0] STATE_WAIT_FRAME_DONE       = 4'd10;
    localparam [3:0] STATE_WAIT_CAPTURE_DONE     = 4'd11;
    localparam [3:0] STATE_RESULT_HOLD           = 4'd12;
    reg clk_div2_ff;
    wire cnn_core_clk;
    reg reset_button_sync_0;
    reg reset_button_sync_1;
    reg start_button_sync_0;
    reg start_button_sync_1;
    reg start_button_sync_2;
    wire reset_sync;
    wire start_button_rising_edge;
    reg [3:0] current_state;
    reg [1:0] current_frame_index;
    reg [6:0] padded_x;
    reg [6:0] padded_y;
    reg [1:0] input_channel_index;
    reg [13:0] image_rom_read_address;
    reg [1:0]  image_rom_read_frame;
    reg signed [7:0] image_rom_read_data;
    reg sample_is_border;
    reg [8:0]  conv1_weight_rom_address;
    reg signed [7:0] conv1_weight_rom_data;
    reg [8:0]  conv1_weight_write_address;
    reg        conv1_weight_write_valid;
    reg        conv1_weight_issue_done;
    reg [5:0]  conv1_bias_load_address;
    reg [12:0] conv2_weight_rom_address;
    reg signed [7:0] conv2_weight_rom_data;
    reg [12:0] conv2_weight_write_address;
    reg        conv2_weight_write_valid;
    reg        conv2_weight_issue_done;
    reg [5:0]  conv2_bias_load_address;
    wire conv1_weight_memory_write_enable;
    wire [12:0] conv1_weight_memory_write_address;
    wire signed [7:0] conv1_weight_memory_write_data;
    wire conv1_bias_memory_write_enable;
    wire signed [31:0] conv1_bias_memory_write_data;
    wire conv2_weight_memory_write_enable;
    wire [12:0] conv2_weight_memory_write_address;
    wire signed [7:0] conv2_weight_memory_write_data;
    wire conv2_bias_memory_write_enable;
    wire signed [31:0] conv2_bias_memory_write_data;
    wire input_valid;
    wire input_ready;
    wire signed [7:0] input_value;
    wire [7:0] conv1_requested_channel_index;
    wire [7:0] conv2_requested_channel_index;
    wire signed [7:0] feature_stream_value;
    wire [12:0] feature_stream_address;
    wire feature_stream_valid;
    wire feature_stream_frame_done;
    reg [14:0] temporal_feature_read_address;
    wire signed [7:0] temporal_feature_read_data;
    wire [2:0] temporal_captured_frame_count;
    wire temporal_capture_complete;
    wire reorder_capture_busy;
    wire reorder_drain_busy;
    wire conv1_requantize_busy;
    wire conv2_requantize_busy;
    wire conv2_padding_overflow_error;
    wire conv2_padding_sequence_error;
    wire reorder_sequence_error;
    wire reorder_metadata_error;
    wire reorder_overflow_error;
    reg started_flag;
    reg busy_flag;
    reg done_flag;
    reg pass_flag;
    reg fail_flag;
    wire any_runtime_error;
    wire feature_stream_parity;
    wire temporal_feature_parity;
    reg [13:0] requested_image_address;
    reg requested_sample_is_border;
    (* rom_style = "block" *)
    reg signed [7:0] image_rom_frame_0
        [0:IMAGE_VALUES_PER_FRAME-1];
    (* rom_style = "block" *)
    reg signed [7:0] image_rom_frame_1
        [0:IMAGE_VALUES_PER_FRAME-1];
    (* rom_style = "block" *)
    reg signed [7:0] image_rom_frame_2
        [0:IMAGE_VALUES_PER_FRAME-1];
    (* rom_style = "block" *)
    reg signed [7:0] image_rom_frame_3
        [0:IMAGE_VALUES_PER_FRAME-1];
    (* rom_style = "block" *)
    reg signed [7:0] conv1_weight_rom
        [0:CONV1_WEIGHT_COUNT-1];
    (* rom_style = "distributed" *)
    reg signed [31:0] conv1_bias_rom
        [0:CONV1_BIAS_COUNT-1];
    (* rom_style = "block" *)
    reg signed [7:0] conv2_weight_rom
        [0:CONV2_WEIGHT_COUNT-1];
    (* rom_style = "distributed" *)
    reg signed [31:0] conv2_bias_rom
        [0:CONV2_BIAS_COUNT-1];
    initial begin
        clk_div2_ff = 1'b0;
        reset_button_sync_0 = 1'b0;
        reset_button_sync_1 = 1'b0;
        start_button_sync_0 = 1'b0;
        start_button_sync_1 = 1'b0;
        start_button_sync_2 = 1'b0;
        $readmemh(
            "sequence_000_frame_0_input.mem",
            image_rom_frame_0
        );
        $readmemh(
            "sequence_000_frame_1_input.mem",
            image_rom_frame_1
        );
        $readmemh(
            "sequence_000_frame_2_input.mem",
            image_rom_frame_2
        );
        $readmemh(
            "sequence_000_frame_3_input.mem",
            image_rom_frame_3
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
        $display(
            "ACTIVE RTL: cnn_feature_streaming_nexys_video_top BRAM-FRIENDLY DATA-OBSERVABLE V3"
        );
    end
    BUFG cnn_core_clk_buf (
        .I(clk_div2_ff),
        .O(cnn_core_clk)
    );
    always @(posedge clk) begin
        clk_div2_ff <= ~clk_div2_ff;
    end
    always @(posedge cnn_core_clk) begin
        reset_button_sync_0 <= reset_button;
        reset_button_sync_1 <= reset_button_sync_0;

        start_button_sync_0 <= start_button;
        start_button_sync_1 <= start_button_sync_0;
        start_button_sync_2 <= start_button_sync_1;
    end
    always @(posedge cnn_core_clk) begin
        case (image_rom_read_frame)
            2'd0:
                image_rom_read_data <=
                    image_rom_frame_0[
                        image_rom_read_address
                    ];
            2'd1:
                image_rom_read_data <=
                    image_rom_frame_1[
                        image_rom_read_address
                    ];
            2'd2:
                image_rom_read_data <=
                    image_rom_frame_2[
                        image_rom_read_address
                    ];
            default:
                image_rom_read_data <=
                    image_rom_frame_3[
                        image_rom_read_address
                    ];
        endcase
        conv1_weight_rom_data <=
            conv1_weight_rom[
                conv1_weight_rom_address
            ];
        conv2_weight_rom_data <=
            conv2_weight_rom[
                conv2_weight_rom_address
            ];
    end
    always @(*) begin
        if (
            (padded_x == 0) ||
            (padded_x == PADDED_WIDTH - 1) ||
            (padded_y == 0) ||
            (padded_y == PADDED_HEIGHT - 1)
        ) begin
            requested_sample_is_border = 1'b1;
            requested_image_address = 14'd0;
        end else begin
            requested_sample_is_border = 1'b0;
            requested_image_address =
                ({12'd0, input_channel_index} << 12) +
                ({7'd0, (padded_y - 7'd1)} << 6) +
                (padded_x - 7'd1);
        end
    end
    assign reset_sync =
        reset_button_sync_1;
    assign start_button_rising_edge =
        start_button_sync_1 &
        ~start_button_sync_2;
    assign conv1_weight_memory_write_enable =
        conv1_weight_write_valid;
    assign conv1_weight_memory_write_address =
        {4'd0, conv1_weight_write_address};
    assign conv1_weight_memory_write_data =
        conv1_weight_rom_data;
    assign conv1_bias_memory_write_enable =
        (current_state == STATE_LOAD_CONV1_BIAS);
    assign conv1_bias_memory_write_data =
        conv1_bias_rom[
            conv1_bias_load_address
        ];
    assign conv2_weight_memory_write_enable =
        conv2_weight_write_valid;
    assign conv2_weight_memory_write_address =
        conv2_weight_write_address;
    assign conv2_weight_memory_write_data =
        conv2_weight_rom_data;
    assign conv2_bias_memory_write_enable =
        (current_state == STATE_LOAD_CONV2_BIAS);
    assign conv2_bias_memory_write_data =
        conv2_bias_rom[
            conv2_bias_load_address
        ];
    assign input_valid =
        (current_state == STATE_STREAM_SEND);
    assign input_value =
        sample_is_border ?
        8'sd0 :
        image_rom_read_data;
    assign any_runtime_error =
        conv2_padding_overflow_error |
        conv2_padding_sequence_error |
        reorder_sequence_error |
        reorder_metadata_error |
        reorder_overflow_error;
    assign feature_stream_parity =
        ^feature_stream_value;
    assign temporal_feature_parity =
        ^temporal_feature_read_data;
    assign led[0] = done_flag;
    assign led[1] = busy_flag;
    assign led[2] = started_flag;
    assign led[3] = pass_flag;
    assign led[4] = fail_flag;
    assign led[5] = temporal_capture_complete;
    assign led[6] = temporal_captured_frame_count[2];
    assign led[7] =
        busy_flag ?
        feature_stream_parity :
        temporal_feature_parity;
    streaming_cnn_temporal_feature_extractor cnn_temporal_inst (
        .clk(cnn_core_clk),
        .reset(reset_sync),
        .temporal_capture_reset(
            current_state == STATE_CAPTURE_RESET
        ),
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
            conv1_bias_load_address
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
            conv2_bias_load_address
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
        .feature_stream_value(
            feature_stream_value
        ),
        .feature_stream_address(
            feature_stream_address
        ),
        .feature_stream_valid(
            feature_stream_valid
        ),
        .feature_stream_frame_done(
            feature_stream_frame_done
        ),
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
        .reorder_capture_busy(
            reorder_capture_busy
        ),
        .reorder_drain_busy(
            reorder_drain_busy
        ),
        .conv1_requantize_busy(
            conv1_requantize_busy
        ),
        .conv2_requantize_busy(
            conv2_requantize_busy
        ),
        .conv2_padding_overflow_error(
            conv2_padding_overflow_error
        ),
        .conv2_padding_sequence_error(
            conv2_padding_sequence_error
        ),
        .reorder_sequence_error(
            reorder_sequence_error
        ),
        .reorder_metadata_error(
            reorder_metadata_error
        ),
        .reorder_overflow_error(
            reorder_overflow_error
        )
    );
    always @(posedge cnn_core_clk) begin
        if (reset_sync) begin
            current_state <= STATE_IDLE;
            current_frame_index <= 2'd0;
            padded_x <= 7'd0;
            padded_y <= 7'd0;
            input_channel_index <= 2'd0;
            image_rom_read_address <= 14'd0;
            image_rom_read_frame <= 2'd0;
            sample_is_border <= 1'b1;
            conv1_weight_rom_address <= 9'd0;
            conv1_weight_write_address <= 9'd0;
            conv1_weight_write_valid <= 1'b0;
            conv1_weight_issue_done <= 1'b0;
            conv1_bias_load_address <= 6'd0;
            conv2_weight_rom_address <= 13'd0;
            conv2_weight_write_address <= 13'd0;
            conv2_weight_write_valid <= 1'b0;
            conv2_weight_issue_done <= 1'b0;
            conv2_bias_load_address <= 6'd0;
            temporal_feature_read_address <= 15'd0;
            started_flag <= 1'b0;
            busy_flag <= 1'b0;
            done_flag <= 1'b0;
            pass_flag <= 1'b0;
            fail_flag <= 1'b0;
        end else begin
            if (any_runtime_error) begin
                fail_flag <= 1'b1;
            end
            case (current_state)
                STATE_IDLE: begin
                    busy_flag <= 1'b0;
                    done_flag <= 1'b0;
                    pass_flag <= 1'b0;
                    fail_flag <= 1'b0;
                    current_frame_index <= 2'd0;
                    padded_x <= 7'd0;
                    padded_y <= 7'd0;
                    input_channel_index <= 2'd0;
                    image_rom_read_address <= 14'd0;
                    image_rom_read_frame <= 2'd0;
                    sample_is_border <= 1'b1;
                    conv1_weight_rom_address <= 9'd0;
                    conv1_weight_write_address <= 9'd0;
                    conv1_weight_write_valid <= 1'b0;
                    conv1_weight_issue_done <= 1'b0;
                    conv1_bias_load_address <= 6'd0;
                    conv2_weight_rom_address <= 13'd0;
                    conv2_weight_write_address <= 13'd0;
                    conv2_weight_write_valid <= 1'b0;
                    conv2_weight_issue_done <= 1'b0;
                    conv2_bias_load_address <= 6'd0;
                    temporal_feature_read_address <= 15'd0;
                    if (start_button_rising_edge) begin
                        started_flag <= 1'b1;
                        busy_flag <= 1'b1;
                        current_state <= STATE_CAPTURE_RESET;
                    end
                end
                STATE_CAPTURE_RESET: begin
                    busy_flag <= 1'b1;
                    current_frame_index <= 2'd0;
                    padded_x <= 7'd0;
                    padded_y <= 7'd0;
                    input_channel_index <= 2'd0;
                    image_rom_read_address <= 14'd0;
                    image_rom_read_frame <= 2'd0;
                    sample_is_border <= 1'b1;
                    conv1_weight_rom_address <= 9'd0;
                    conv1_weight_write_address <= 9'd0;
                    conv1_weight_write_valid <= 1'b0;
                    conv1_weight_issue_done <= 1'b0;
                    conv1_bias_load_address <= 6'd0;
                    conv2_weight_rom_address <= 13'd0;
                    conv2_weight_write_address <= 13'd0;
                    conv2_weight_write_valid <= 1'b0;
                    conv2_weight_issue_done <= 1'b0;
                    conv2_bias_load_address <= 6'd0;
                    current_state <= STATE_LOAD_CONV1_WEIGHT;
                end
                STATE_LOAD_CONV1_WEIGHT: begin
                    busy_flag <= 1'b1;
                    if (!conv1_weight_issue_done) begin
                        conv1_weight_write_valid <= 1'b1;
                        conv1_weight_write_address <=
                            conv1_weight_rom_address;
                        if (
                            conv1_weight_rom_address ==
                            CONV1_WEIGHT_COUNT - 1
                        ) begin
                            conv1_weight_issue_done <= 1'b1;
                        end else begin
                            conv1_weight_rom_address <=
                                conv1_weight_rom_address + 9'd1;
                        end
                    end else begin
                        conv1_weight_write_valid <= 1'b0;
                        conv1_weight_issue_done <= 1'b0;
                        conv1_weight_rom_address <= 9'd0;
                        conv1_bias_load_address <= 6'd0;
                        current_state <= STATE_LOAD_CONV1_BIAS;
                    end
                end
                STATE_LOAD_CONV1_BIAS: begin
                    busy_flag <= 1'b1;
                    if (
                        conv1_bias_load_address ==
                        CONV1_BIAS_COUNT - 1
                    ) begin
                        conv1_bias_load_address <= 6'd0;
                        conv2_weight_rom_address <= 13'd0;
                        conv2_weight_write_address <= 13'd0;
                        conv2_weight_write_valid <= 1'b0;
                        conv2_weight_issue_done <= 1'b0;

                        current_state <= STATE_LOAD_CONV2_WEIGHT;
                    end else begin
                        conv1_bias_load_address <=
                            conv1_bias_load_address + 6'd1;
                    end
                end
                STATE_LOAD_CONV2_WEIGHT: begin
                    busy_flag <= 1'b1;
                    if (!conv2_weight_issue_done) begin
                        conv2_weight_write_valid <= 1'b1;
                        conv2_weight_write_address <=
                            conv2_weight_rom_address;
                        if (
                            conv2_weight_rom_address ==
                            CONV2_WEIGHT_COUNT - 1
                        ) begin
                            conv2_weight_issue_done <= 1'b1;
                        end else begin
                            conv2_weight_rom_address <=
                                conv2_weight_rom_address + 13'd1;
                        end
                    end else begin
                        conv2_weight_write_valid <= 1'b0;
                        conv2_weight_issue_done <= 1'b0;
                        conv2_weight_rom_address <= 13'd0;
                        conv2_bias_load_address <= 6'd0;
                        current_state <= STATE_LOAD_CONV2_BIAS;
                    end
                end
                STATE_LOAD_CONV2_BIAS: begin
                    busy_flag <= 1'b1;
                    if (
                        conv2_bias_load_address ==
                        CONV2_BIAS_COUNT - 1
                    ) begin
                        conv2_bias_load_address <= 6'd0;
                        current_state <= STATE_FRAME_PREP;
                    end else begin
                        conv2_bias_load_address <=
                            conv2_bias_load_address + 6'd1;
                    end
                end
                STATE_FRAME_PREP: begin
                    busy_flag <= 1'b1;
                    padded_x <= 7'd0;
                    padded_y <= 7'd0;
                    input_channel_index <= 2'd0;
                    image_rom_read_frame <=
                        current_frame_index;
                    image_rom_read_address <= 14'd0;
                    sample_is_border <= 1'b1;

                    current_state <= STATE_STREAM_REQUEST;
                end
                STATE_STREAM_REQUEST: begin
                    busy_flag <= 1'b1;
                    sample_is_border <=
                        requested_sample_is_border;
                    if (requested_sample_is_border) begin
                        current_state <= STATE_STREAM_SEND;
                    end else begin
                        image_rom_read_address <=
                            requested_image_address;
                        image_rom_read_frame <=
                            current_frame_index;
                        current_state <= STATE_STREAM_ROM_WAIT;
                    end
                end
                STATE_STREAM_ROM_WAIT: begin
                    busy_flag <= 1'b1;
                    current_state <= STATE_STREAM_SEND;
                end
                STATE_STREAM_SEND: begin
                    busy_flag <= 1'b1;
                    if (input_ready) begin
                        if (
                            input_channel_index ==
                            INPUT_CHANNELS - 1
                        ) begin
                            input_channel_index <= 2'd0;
                            if (
                                padded_x ==
                                PADDED_WIDTH - 1
                            ) begin
                                padded_x <= 7'd0;
                                if (
                                    padded_y ==
                                    PADDED_HEIGHT - 1
                                ) begin
                                    padded_y <= 7'd0;
                                    current_state <=
                                        STATE_WAIT_FRAME_DONE;
                                end else begin
                                    padded_y <=
                                        padded_y + 7'd1;
                                    current_state <=
                                        STATE_STREAM_REQUEST;
                                end
                            end else begin
                                padded_x <=
                                    padded_x + 7'd1;
                                current_state <=
                                    STATE_STREAM_REQUEST;
                            end
                        end else begin
                            input_channel_index <=
                                input_channel_index + 2'd1;
                            current_state <=
                                STATE_STREAM_REQUEST;
                        end
                    end
                end
                STATE_WAIT_FRAME_DONE: begin
                    busy_flag <= 1'b1;
                    if (feature_stream_frame_done) begin
                        if (current_frame_index == 2'd3) begin
                            current_state <=
                                STATE_WAIT_CAPTURE_DONE;
                        end else begin
                            current_frame_index <=
                                current_frame_index + 2'd1;
                            current_state <=
                                STATE_FRAME_PREP;
                        end
                    end
                end
                STATE_WAIT_CAPTURE_DONE: begin
                    busy_flag <= 1'b1;
                    if (temporal_capture_complete) begin
                        done_flag <= 1'b1;
                        busy_flag <= 1'b0;
                        if (
                            (temporal_captured_frame_count == 3'd4) &&
                            !any_runtime_error &&
                            !fail_flag
                        ) begin
                            pass_flag <= 1'b1;
                            fail_flag <= 1'b0;
                        end else begin
                            pass_flag <= 1'b0;
                            fail_flag <= 1'b1;
                        end
                        temporal_feature_read_address <= 15'd0;
                        current_state <= STATE_RESULT_HOLD;
                    end
                end
                STATE_RESULT_HOLD: begin
                    done_flag <= 1'b1;
                    busy_flag <= 1'b0;
                    temporal_feature_read_address <=
                        temporal_feature_read_address + 15'd1;
                    if (start_button_rising_edge) begin
                        done_flag <= 1'b0;
                        pass_flag <= 1'b0;
                        fail_flag <= 1'b0;
                        busy_flag <= 1'b1;
                        current_state <= STATE_CAPTURE_RESET;
                    end
                end
                default: begin
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule