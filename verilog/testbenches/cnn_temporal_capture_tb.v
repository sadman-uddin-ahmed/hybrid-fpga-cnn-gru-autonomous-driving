`timescale 1ns / 1ps
`default_nettype none

module cnn_temporal_capture_tb;
    localparam integer CLOCK_PERIOD                  = 10;
    localparam integer IMAGE_TOTAL_VALUES            = 12288;
    localparam integer CONV1_WEIGHT_TOTAL_VALUES     = 432;
    localparam integer CONV1_BIAS_TOTAL_VALUES       = 16;
    localparam integer CONV2_WEIGHT_TOTAL_VALUES     = 4608;
    localparam integer CONV2_BIAS_TOTAL_VALUES       = 32;
    localparam integer FEATURES_PER_FRAME            = 8192;
    localparam integer TEMPORAL_FRAME_COUNT          = 4;
    localparam integer TOTAL_TEMPORAL_FEATURE_VALUES = 32768;
    reg clk;
    reg rst;
    reg core_start;
    reg image_memory_write_enable;
    reg [13:0] image_memory_write_address;
    reg signed [7:0] image_memory_write_data;
    reg conv1_weight_memory_write_enable;
    reg [8:0] conv1_weight_memory_write_address;
    reg signed [7:0] conv1_weight_memory_write_data;
    reg conv1_bias_memory_write_enable;
    reg [3:0] conv1_bias_memory_write_address;
    reg signed [31:0] conv1_bias_memory_write_data;
    reg conv2_weight_memory_write_enable;
    reg [12:0] conv2_weight_memory_write_address;
    reg signed [7:0] conv2_weight_memory_write_data;
    reg conv2_bias_memory_write_enable;
    reg [4:0] conv2_bias_memory_write_address;
    reg signed [31:0] conv2_bias_memory_write_data;
    reg [12:0] conv2_pooled_output_read_address;
    wire signed [7:0] conv2_pooled_output_read_data;
    wire [12:0] conv2_pooled_output_write_address_monitor;
    wire signed [7:0] conv2_pooled_output_write_data_monitor;
    wire conv2_pooled_output_write_enable_monitor;
    wire core_done;
    reg temporal_capture_reset;
    reg [14:0] temporal_feature_read_address;
    wire signed [7:0] temporal_feature_read_data;
    wire [2:0] temporal_captured_frame_count;
    wire temporal_capture_complete;
    reg waveform_ready;
    reg captured_data_valid;
    reg simulation_pass;
    reg simulation_fail;
    wire safe_core_done;
    wire safe_output_write_enable;
    wire [12:0] safe_output_write_address;
    wire signed [7:0] safe_output_write_data;
    wire [2:0] safe_captured_frame_count;
    wire safe_capture_complete;
    wire [14:0] safe_feature_read_address;
    wire signed [7:0] safe_feature_read_data;
    reg signed [7:0] input_frame_0_rom [0:IMAGE_TOTAL_VALUES-1];
    reg signed [7:0] input_frame_1_rom [0:IMAGE_TOTAL_VALUES-1];
    reg signed [7:0] input_frame_2_rom [0:IMAGE_TOTAL_VALUES-1];
    reg signed [7:0] input_frame_3_rom [0:IMAGE_TOTAL_VALUES-1];
    reg signed [7:0] conv1_weight_rom [0:CONV1_WEIGHT_TOTAL_VALUES-1];
    reg signed [31:0] conv1_bias_rom [0:CONV1_BIAS_TOTAL_VALUES-1];
    reg signed [7:0] conv2_weight_rom [0:CONV2_WEIGHT_TOTAL_VALUES-1];
    reg signed [31:0] conv2_bias_rom [0:CONV2_BIAS_TOTAL_VALUES-1];
    reg signed [7:0] expected_frame_0_rom [0:FEATURES_PER_FRAME-1];
    reg signed [7:0] expected_frame_1_rom [0:FEATURES_PER_FRAME-1];
    reg signed [7:0] expected_frame_2_rom [0:FEATURES_PER_FRAME-1];
    reg signed [7:0] expected_frame_3_rom [0:FEATURES_PER_FRAME-1];
    integer image_load_index;
    integer conv1_weight_load_index;
    integer conv1_bias_load_index;
    integer conv2_weight_load_index;
    integer conv2_bias_load_index;
    integer frame_run_index;
    integer temporal_read_index;
    integer buffer_frame_index;
    integer buffer_feature_index;
    integer stream_expected_address;
    integer stream_total_write_count;
    integer stream_frame_write_count;
    integer stream_address_error_count;
    integer stream_unknown_value_count;
    integer stream_mismatch_count;
    integer buffer_unknown_value_count;
    integer buffer_mismatch_count;
    integer total_error_count;
    reg [1:0] current_expected_frame_index;
    reg signed [7:0] expected_stream_value;
    reg signed [7:0] expected_buffer_value;
    assign safe_core_done =
        (waveform_ready && (core_done === 1'b1)) ? 1'b1 : 1'b0;
    assign safe_output_write_enable =
        (waveform_ready &&
         (conv2_pooled_output_write_enable_monitor === 1'b1)) ?
        1'b1 :
        1'b0;
    assign safe_output_write_address =
        safe_output_write_enable ?
        conv2_pooled_output_write_address_monitor :
        13'd0;
    assign safe_output_write_data =
        safe_output_write_enable ?
        conv2_pooled_output_write_data_monitor :
        8'sd0;
    assign safe_captured_frame_count =
        waveform_ready ?
        temporal_captured_frame_count :
        3'd0;
    assign safe_capture_complete =
        (waveform_ready &&
         (temporal_capture_complete === 1'b1)) ?
        1'b1 :
        1'b0;
    assign safe_feature_read_address =
        captured_data_valid ?
        temporal_feature_read_address :
        15'd0;
    assign safe_feature_read_data =
        captured_data_valid ?
        temporal_feature_read_data :
        8'sd0;
    cnn_feature_extractor_bram_system cnn_feature_extractor_core_inst (
        .clk(clk),
        .rst(rst),
        .start(core_start),
        .image_memory_write_enable(
            image_memory_write_enable
        ),
        .image_memory_write_address(
            image_memory_write_address
        ),
        .image_memory_write_data(
            image_memory_write_data
        ),
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
        .conv2_pooled_output_read_address(
            conv2_pooled_output_read_address
        ),
        .conv2_pooled_output_read_data(
            conv2_pooled_output_read_data
        ),
        .conv2_pooled_output_write_address_monitor(
            conv2_pooled_output_write_address_monitor
        ),
        .conv2_pooled_output_write_data_monitor(
            conv2_pooled_output_write_data_monitor
        ),
        .conv2_pooled_output_write_enable_monitor(
            conv2_pooled_output_write_enable_monitor
        ),
        .done(core_done)
    );
    temporal_feature_buffer temporal_feature_buffer_inst (
        .clk(clk),
        .rst(rst),
        .capture_reset(
            temporal_capture_reset
        ),
        .feature_write_address(
            conv2_pooled_output_write_address_monitor
        ),
        .feature_write_data(
            conv2_pooled_output_write_data_monitor
        ),
        .feature_write_enable(
            conv2_pooled_output_write_enable_monitor
        ),
        .feature_read_address(
            temporal_feature_read_address
        ),
        .feature_read_data(
            temporal_feature_read_data
        ),
        .captured_frame_count(
            temporal_captured_frame_count
        ),
        .capture_complete(
            temporal_capture_complete
        )
    );
    always #(CLOCK_PERIOD / 2) begin
        clk = ~clk;
    end
    always @(posedge clk) begin
        if (rst) begin
            waveform_ready <= 1'b0;
        end else begin
            waveform_ready <= 1'b1;
        end
    end
    always @(negedge clk) begin
        if (rst || temporal_capture_reset) begin
            stream_expected_address    = 0;
            stream_total_write_count   = 0;
            stream_frame_write_count   = 0;
            stream_address_error_count = 0;
            stream_unknown_value_count = 0;
            stream_mismatch_count      = 0;
        end else if (
            conv2_pooled_output_write_enable_monitor === 1'b1
        ) begin
            stream_total_write_count =
                stream_total_write_count + 1;
            stream_frame_write_count =
                stream_frame_write_count + 1;
            if ((^conv2_pooled_output_write_address_monitor) === 1'bx) begin
                stream_address_error_count =
                    stream_address_error_count + 1;

                if (stream_address_error_count <= 10) begin
                    $display(
                        "ERROR: X/Z stream address during frame %0d.",
                        current_expected_frame_index
                    );
                end
            end else if (
                conv2_pooled_output_write_address_monitor !==
                stream_expected_address[12:0]
            ) begin
                stream_address_error_count =
                    stream_address_error_count + 1;
                if (stream_address_error_count <= 10) begin
                    $display(
                        "ERROR: frame=%0d expected address=%0d received=%0d",
                        current_expected_frame_index,
                        stream_expected_address,
                        conv2_pooled_output_write_address_monitor
                    );
                end
            end
            if ((^conv2_pooled_output_write_data_monitor) === 1'bx) begin
                stream_unknown_value_count =
                    stream_unknown_value_count + 1;
                if (stream_unknown_value_count <= 10) begin
                    $display(
                        "ERROR: X/Z feature data at frame=%0d address=%0d",
                        current_expected_frame_index,
                        conv2_pooled_output_write_address_monitor
                    );
                end
            end else begin
                case (current_expected_frame_index)
                    2'd0: begin
                        expected_stream_value = expected_frame_0_rom[
                            conv2_pooled_output_write_address_monitor
                        ];
                    end
                    2'd1: begin
                        expected_stream_value = expected_frame_1_rom[
                            conv2_pooled_output_write_address_monitor
                        ];
                    end
                    2'd2: begin
                        expected_stream_value = expected_frame_2_rom[
                            conv2_pooled_output_write_address_monitor
                        ];
                    end
                    default: begin
                        expected_stream_value = expected_frame_3_rom[
                            conv2_pooled_output_write_address_monitor
                        ];
                    end
                endcase
                if (
                    conv2_pooled_output_write_data_monitor !==
                    expected_stream_value
                ) begin
                    stream_mismatch_count =
                        stream_mismatch_count + 1;
                    if (stream_mismatch_count <= 10) begin
                        $display(
                            "ERROR: frame=%0d address=%0d expected=%0d received=%0d",
                            current_expected_frame_index,
                            conv2_pooled_output_write_address_monitor,
                            expected_stream_value,
                            conv2_pooled_output_write_data_monitor
                        );
                    end
                end
            end
            if (stream_expected_address == FEATURES_PER_FRAME - 1) begin
                stream_expected_address = 0;
            end else begin
                stream_expected_address =
                    stream_expected_address + 1;
            end
        end
    end
    task load_cnn_parameters;
        begin
            $display("Loading CNN parameters...");
            for (
                conv1_weight_load_index = 0;
                conv1_weight_load_index < CONV1_WEIGHT_TOTAL_VALUES;
                conv1_weight_load_index =
                    conv1_weight_load_index + 1
            ) begin
                @(negedge clk);
                conv1_weight_memory_write_enable = 1'b1;
                conv1_weight_memory_write_address =
                    conv1_weight_load_index[8:0];
                conv1_weight_memory_write_data =
                    conv1_weight_rom[conv1_weight_load_index];
            end
            @(negedge clk);
            conv1_weight_memory_write_enable = 1'b0;
            conv1_weight_memory_write_address = 9'd0;
            conv1_weight_memory_write_data = 8'sd0;
            for (
                conv1_bias_load_index = 0;
                conv1_bias_load_index < CONV1_BIAS_TOTAL_VALUES;
                conv1_bias_load_index =
                    conv1_bias_load_index + 1
            ) begin
                @(negedge clk);
                conv1_bias_memory_write_enable = 1'b1;
                conv1_bias_memory_write_address =
                    conv1_bias_load_index[3:0];
                conv1_bias_memory_write_data =
                    conv1_bias_rom[conv1_bias_load_index];
            end
            @(negedge clk);
            conv1_bias_memory_write_enable = 1'b0;
            conv1_bias_memory_write_address = 4'd0;
            conv1_bias_memory_write_data = 32'sd0;
            for (
                conv2_weight_load_index = 0;
                conv2_weight_load_index < CONV2_WEIGHT_TOTAL_VALUES;
                conv2_weight_load_index =
                    conv2_weight_load_index + 1
            ) begin
                @(negedge clk);
                conv2_weight_memory_write_enable = 1'b1;
                conv2_weight_memory_write_address =
                    conv2_weight_load_index[12:0];
                conv2_weight_memory_write_data =
                    conv2_weight_rom[conv2_weight_load_index];
            end
            @(negedge clk);
            conv2_weight_memory_write_enable = 1'b0;
            conv2_weight_memory_write_address = 13'd0;
            conv2_weight_memory_write_data = 8'sd0;
            for (
                conv2_bias_load_index = 0;
                conv2_bias_load_index < CONV2_BIAS_TOTAL_VALUES;
                conv2_bias_load_index =
                    conv2_bias_load_index + 1
            ) begin
                @(negedge clk);
                conv2_bias_memory_write_enable = 1'b1;
                conv2_bias_memory_write_address =
                    conv2_bias_load_index[4:0];
                conv2_bias_memory_write_data =
                    conv2_bias_rom[conv2_bias_load_index];
            end
            @(negedge clk);
            conv2_bias_memory_write_enable = 1'b0;
            conv2_bias_memory_write_address = 5'd0;
            conv2_bias_memory_write_data = 32'sd0;
        end
    endtask
    task load_temporal_input_frame;
        input integer frame_number;
        begin
            $display(
                "Loading temporal input frame %0d...",
                frame_number
            );
            for (
                image_load_index = 0;
                image_load_index < IMAGE_TOTAL_VALUES;
                image_load_index = image_load_index + 1
            ) begin
                @(negedge clk);
                image_memory_write_enable = 1'b1;
                image_memory_write_address =
                    image_load_index[13:0];
                case (frame_number)
                    0: begin
                        image_memory_write_data =
                            input_frame_0_rom[image_load_index];
                    end
                    1: begin
                        image_memory_write_data =
                            input_frame_1_rom[image_load_index];
                    end
                    2: begin
                        image_memory_write_data =
                            input_frame_2_rom[image_load_index];
                    end
                    default: begin
                        image_memory_write_data =
                            input_frame_3_rom[image_load_index];
                    end
                endcase
            end
            @(negedge clk);
            image_memory_write_enable = 1'b0;
            image_memory_write_address = 14'd0;
            image_memory_write_data = 8'sd0;
        end
    endtask
    task run_one_cnn_frame;
        input integer frame_number;
        begin
            current_expected_frame_index = frame_number[1:0];
            stream_expected_address = 0;
            stream_frame_write_count = 0;
            $display(
                "Running CNN feature extraction for frame %0d...",
                frame_number
            );
            @(negedge clk);
            core_start = 1'b1;
            @(negedge clk);
            core_start = 1'b0;
            wait (core_done === 1'b1);
            repeat (3) @(posedge clk);
            if (stream_frame_write_count != FEATURES_PER_FRAME) begin
                total_error_count = total_error_count + 1;
                $display(
                    "ERROR: frame=%0d expected %0d stream values received %0d",
                    frame_number,
                    FEATURES_PER_FRAME,
                    stream_frame_write_count
                );
            end else begin
                $display(
                    "CNN feature extraction completed for frame %0d.",
                    frame_number
                );
            end
        end
    endtask
    task verify_temporal_buffer;
        begin
            $display(
                "Checking all 32768 captured temporal-buffer values..."
            );
            for (
                temporal_read_index = 0;
                temporal_read_index < TOTAL_TEMPORAL_FEATURE_VALUES;
                temporal_read_index = temporal_read_index + 1
            ) begin
                buffer_frame_index =
                    temporal_read_index / FEATURES_PER_FRAME;
                buffer_feature_index =
                    temporal_read_index % FEATURES_PER_FRAME;
                @(negedge clk);
                temporal_feature_read_address =
                    temporal_read_index[14:0];
                @(posedge clk);
                #1;
                case (buffer_frame_index)
                    0: begin
                        expected_buffer_value = expected_frame_0_rom[
                            buffer_feature_index
                        ];
                    end
                    1: begin
                        expected_buffer_value = expected_frame_1_rom[
                            buffer_feature_index
                        ];
                    end
                    2: begin
                        expected_buffer_value = expected_frame_2_rom[
                            buffer_feature_index
                        ];
                    end
                    default: begin
                        expected_buffer_value = expected_frame_3_rom[
                            buffer_feature_index
                        ];
                    end
                endcase
                if ((^temporal_feature_read_data) === 1'bx) begin
                    buffer_unknown_value_count =
                        buffer_unknown_value_count + 1;
                    if (buffer_unknown_value_count <= 10) begin
                        $display(
                            "ERROR: X/Z buffer value at frame=%0d feature=%0d",
                            buffer_frame_index,
                            buffer_feature_index
                        );
                    end
                end else if (
                    temporal_feature_read_data !==
                    expected_buffer_value
                ) begin
                    buffer_mismatch_count =
                        buffer_mismatch_count + 1;
                    if (buffer_mismatch_count <= 10) begin
                        $display(
                            "ERROR: buffer frame=%0d feature=%0d expected=%0d received=%0d",
                            buffer_frame_index,
                            buffer_feature_index,
                            expected_buffer_value,
                            temporal_feature_read_data
                        );
                    end
                end
            end
        end
    endtask
    initial begin
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_0_input.mem",
            input_frame_0_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_1_input.mem",
            input_frame_1_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_2_input.mem",
            input_frame_2_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_3_input.mem",
            input_frame_3_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/conv1_w.mem",
            conv1_weight_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/conv1_b_int32_correct.mem",
            conv1_bias_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/conv2_w.mem",
            conv2_weight_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/conv2_b_int32_correct.mem",
            conv2_bias_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_0_expected.mem",
            expected_frame_0_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_1_expected.mem",
            expected_frame_1_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_2_expected.mem",
            expected_frame_2_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_3_expected.mem",
            expected_frame_3_rom
        );
    end
    initial begin
        clk = 1'b0;
        rst = 1'b1;
        core_start = 1'b0;
        image_memory_write_enable = 1'b0;
        image_memory_write_address = 14'd0;
        image_memory_write_data = 8'sd0;
        conv1_weight_memory_write_enable = 1'b0;
        conv1_weight_memory_write_address = 9'd0;
        conv1_weight_memory_write_data = 8'sd0;
        conv1_bias_memory_write_enable = 1'b0;
        conv1_bias_memory_write_address = 4'd0;
        conv1_bias_memory_write_data = 32'sd0;
        conv2_weight_memory_write_enable = 1'b0;
        conv2_weight_memory_write_address = 13'd0;
        conv2_weight_memory_write_data = 8'sd0;
        conv2_bias_memory_write_enable = 1'b0;
        conv2_bias_memory_write_address = 5'd0;
        conv2_bias_memory_write_data = 32'sd0;
        conv2_pooled_output_read_address = 13'd0;
        temporal_capture_reset = 1'b1;
        temporal_feature_read_address = 15'd0;
        waveform_ready = 1'b0;
        captured_data_valid = 1'b0;
        simulation_pass = 1'b0;
        simulation_fail = 1'b0;
        image_load_index = 0;
        conv1_weight_load_index = 0;
        conv1_bias_load_index = 0;
        conv2_weight_load_index = 0;
        conv2_bias_load_index = 0;
        frame_run_index = 0;
        temporal_read_index = 0;
        buffer_frame_index = 0;
        buffer_feature_index = 0;
        stream_expected_address = 0;
        stream_total_write_count = 0;
        stream_frame_write_count = 0;
        stream_address_error_count = 0;
        stream_unknown_value_count = 0;
        stream_mismatch_count = 0;
        buffer_unknown_value_count = 0;
        buffer_mismatch_count = 0;
        total_error_count = 0;
        current_expected_frame_index = 2'd0;
        expected_stream_value = 8'sd0;
        expected_buffer_value = 8'sd0;
        repeat (8) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        @(negedge clk);
        temporal_capture_reset = 1'b0;
        load_cnn_parameters;
        for (
            frame_run_index = 0;
            frame_run_index < TEMPORAL_FRAME_COUNT;
            frame_run_index = frame_run_index + 1
        ) begin
            load_temporal_input_frame(frame_run_index);
            run_one_cnn_frame(frame_run_index);
        end
        repeat (5) @(posedge clk);
        if (temporal_captured_frame_count !== 3'd4) begin
            total_error_count = total_error_count + 1;

            $display(
                "ERROR: captured_frame_count expected=4 received=%0d",
                temporal_captured_frame_count
            );
        end
        if (temporal_capture_complete !== 1'b1) begin
            total_error_count = total_error_count + 1;

            $display(
                "ERROR: temporal_capture_complete was not asserted."
            );
        end
        if (stream_total_write_count !== TOTAL_TEMPORAL_FEATURE_VALUES) begin
            total_error_count = total_error_count + 1;
            $display(
                "ERROR: stream count expected=%0d received=%0d",
                TOTAL_TEMPORAL_FEATURE_VALUES,
                stream_total_write_count
            );
        end
        captured_data_valid = 1'b1;
        verify_temporal_buffer;
        total_error_count = total_error_count +
                            stream_address_error_count +
                            stream_unknown_value_count +
                            stream_mismatch_count +
                            buffer_unknown_value_count +
                            buffer_mismatch_count;
        $display("================================================");
        $display("CNN temporal capture verification complete");
        $display("Captured frames       = %0d",
                 temporal_captured_frame_count);
        $display("Streamed values       = %0d",
                 stream_total_write_count);
        $display("Stream address errors = %0d",
                 stream_address_error_count);
        $display("Stream X/Z values     = %0d",
                 stream_unknown_value_count);
        $display("Stream mismatches     = %0d",
                 stream_mismatch_count);
        $display("Buffer X/Z values     = %0d",
                 buffer_unknown_value_count);
        $display("Buffer mismatches     = %0d",
                 buffer_mismatch_count);
        $display("================================================");
        if (total_error_count == 0) begin
            simulation_pass = 1'b1;
            $display(
                "PASS: Four distinct temporal CNN frames were captured in BRAM with full expected-vector agreement."
            );
        end else begin
            simulation_fail = 1'b1;
            $display(
                "FAIL: CNN temporal capture verification found %0d errors.",
                total_error_count
            );
        end
        #20;
        $finish;
    end
endmodule
`default_nettype wire
