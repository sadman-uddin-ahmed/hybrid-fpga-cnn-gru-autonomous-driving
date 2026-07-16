`timescale 1ns / 1ps

module conv1_pool_bram_system_tb;

    localparam CLOCK_PERIOD = 10;

    localparam INPUT_TOTAL_VALUES         = 12288;
    localparam WEIGHT_TOTAL_VALUES        = 432;
    localparam BIAS_TOTAL_VALUES          = 16;
    localparam POOLED_OUTPUT_TOTAL_VALUES = 16384;

    reg clk;
    reg reset;
    reg start;

    reg input_memory_write_enable;
    reg [13:0] input_memory_write_address;
    reg signed [7:0] input_memory_write_data;

    reg weight_memory_write_enable;
    reg [8:0] weight_memory_write_address;
    reg signed [7:0] weight_memory_write_data;

    reg bias_memory_write_enable;
    reg [3:0] bias_memory_write_address;
    reg signed [31:0] bias_memory_write_data;

    reg [13:0] pooled_output_read_address;
    wire signed [7:0] pooled_output_read_data;

    wire [13:0] pooled_output_write_address_monitor;
    wire signed [7:0] pooled_output_write_data_monitor;
    wire pooled_output_write_enable_monitor;

    wire done;

    reg signed [7:0] expected_pooled_output_memory_array [0:POOLED_OUTPUT_TOTAL_VALUES-1];
    reg output_seen_array [0:POOLED_OUTPUT_TOTAL_VALUES-1];

    integer input_file;
    integer weight_file;
    integer bias_file;
    integer expected_file;

    integer input_load_index;
    integer weight_load_index;
    integer bias_load_index;
    integer expected_load_index;
    integer output_seen_initialize_index;
    integer output_check_index;

    integer scan_status;
    integer mismatch_count;
    integer unknown_count;
    integer written_output_count;
    integer missing_output_count;
    integer duplicate_output_count;

    reg signed [7:0] expected_pooled_output_value;

    conv1_pool_bram_system dut (
        .clk(clk),
        .reset(reset),
        .start(start),

        .input_memory_write_enable(input_memory_write_enable),
        .input_memory_write_address(input_memory_write_address),
        .input_memory_write_data(input_memory_write_data),

        .weight_memory_write_enable(weight_memory_write_enable),
        .weight_memory_write_address(weight_memory_write_address),
        .weight_memory_write_data(weight_memory_write_data),

        .bias_memory_write_enable(bias_memory_write_enable),
        .bias_memory_write_address(bias_memory_write_address),
        .bias_memory_write_data(bias_memory_write_data),

        .pooled_output_read_address(pooled_output_read_address),
        .pooled_output_read_data(pooled_output_read_data),

        .pooled_output_write_address_monitor(pooled_output_write_address_monitor),
        .pooled_output_write_data_monitor(pooled_output_write_data_monitor),
        .pooled_output_write_enable_monitor(pooled_output_write_enable_monitor),

        .done(done)
    );

    always #(CLOCK_PERIOD / 2) clk = ~clk;

    task write_input_memory_value;
        input [13:0] task_write_address;
        input signed [7:0] task_write_data;
        begin
            @(posedge clk);
            #1;
            input_memory_write_enable = 1'b1;
            input_memory_write_address = task_write_address;
            input_memory_write_data = task_write_data;

            @(posedge clk);
            #1;
            input_memory_write_enable = 1'b0;
        end
    endtask

    task write_weight_memory_value;
        input [8:0] task_write_address;
        input signed [7:0] task_write_data;
        begin
            @(posedge clk);
            #1;
            weight_memory_write_enable = 1'b1;
            weight_memory_write_address = task_write_address;
            weight_memory_write_data = task_write_data;

            @(posedge clk);
            #1;
            weight_memory_write_enable = 1'b0;
        end
    endtask

    task write_bias_memory_value;
        input [3:0] task_write_address;
        input signed [31:0] task_write_data;
        begin
            @(posedge clk);
            #1;
            bias_memory_write_enable = 1'b1;
            bias_memory_write_address = task_write_address;
            bias_memory_write_data = task_write_data;

            @(posedge clk);
            #1;
            bias_memory_write_enable = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        #1;

        if (!reset && pooled_output_write_enable_monitor) begin
            written_output_count = written_output_count + 1;

            if (output_seen_array[pooled_output_write_address_monitor] === 1'b1) begin
                duplicate_output_count = duplicate_output_count + 1;

                if (duplicate_output_count <= 20) begin
                    $display(
                        "DUPLICATE output write at pooled index %0d",
                        pooled_output_write_address_monitor
                    );
                end
            end

            output_seen_array[pooled_output_write_address_monitor] = 1'b1;
            expected_pooled_output_value =
                expected_pooled_output_memory_array[pooled_output_write_address_monitor];

            if ((^pooled_output_write_data_monitor) === 1'bx) begin
                unknown_count = unknown_count + 1;

                if (unknown_count <= 20) begin
                    $display(
                        "UNKNOWN X/Z at pooled index %0d: got = %b, expected = %0d",
                        pooled_output_write_address_monitor,
                        pooled_output_write_data_monitor,
                        expected_pooled_output_value
                    );
                end
            end else if (pooled_output_write_data_monitor !== expected_pooled_output_value) begin
                mismatch_count = mismatch_count + 1;

                if (mismatch_count <= 20) begin
                    $display(
                        "MISMATCH at pooled index %0d: expected = %0d, got = %0d",
                        pooled_output_write_address_monitor,
                        expected_pooled_output_value,
                        pooled_output_write_data_monitor
                    );
                end
            end
        end
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        start = 1'b0;

        input_memory_write_enable = 1'b0;
        input_memory_write_address = 14'd0;
        input_memory_write_data = 8'sd0;

        weight_memory_write_enable = 1'b0;
        weight_memory_write_address = 9'd0;
        weight_memory_write_data = 8'sd0;

        bias_memory_write_enable = 1'b0;
        bias_memory_write_address = 4'd0;
        bias_memory_write_data = 32'sd0;

        pooled_output_read_address = 14'd0;

        mismatch_count = 0;
        unknown_count = 0;
        written_output_count = 0;
        missing_output_count = 0;
        duplicate_output_count = 0;

        for (
            output_seen_initialize_index = 0;
            output_seen_initialize_index < POOLED_OUTPUT_TOTAL_VALUES;
            output_seen_initialize_index = output_seen_initialize_index + 1
        ) begin
            output_seen_array[output_seen_initialize_index] = 1'b0;
        end

        repeat(10) @(posedge clk);
        #1;
        reset = 1'b0;
        repeat(5) @(posedge clk);

        $display("Loading Conv1 input image memory...");
        input_file = $fopen(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/vectors/in_img_int8.txt",
            "r"
        );

        if (input_file == 0) begin
            $display("ERROR: Could not open input image file.");
            $finish;
        end

        for (
            input_load_index = 0;
            input_load_index < INPUT_TOTAL_VALUES;
            input_load_index = input_load_index + 1
        ) begin
            scan_status = $fscanf(input_file, "%d\n", input_memory_write_data);

            if (scan_status != 1) begin
                $display("ERROR: Failed reading Conv1 input value at index %0d", input_load_index);
                $finish;
            end

            write_input_memory_value(input_load_index[13:0], input_memory_write_data);
        end

        $fclose(input_file);

        $display("Loading Conv1 weight memory...");
        weight_file = $fopen(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/quant/W8_txt/conv1_w.txt",
            "r"
        );

        if (weight_file == 0) begin
            $display("ERROR: Could not open Conv1 weight file.");
            $finish;
        end

        for (
            weight_load_index = 0;
            weight_load_index < WEIGHT_TOTAL_VALUES;
            weight_load_index = weight_load_index + 1
        ) begin
            scan_status = $fscanf(weight_file, "%d\n", weight_memory_write_data);

            if (scan_status != 1) begin
                $display("ERROR: Failed reading Conv1 weight value at index %0d", weight_load_index);
                $finish;
            end

            write_weight_memory_value(weight_load_index[8:0], weight_memory_write_data);
        end

        $fclose(weight_file);

        $display("Loading Conv1 bias memory...");
        bias_file = $fopen(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/quant/W8_txt/conv1_b_int32_correct.txt",
            "r"
        );

        if (bias_file == 0) begin
            $display("ERROR: Could not open Conv1 bias file.");
            $finish;
        end

        for (
            bias_load_index = 0;
            bias_load_index < BIAS_TOTAL_VALUES;
            bias_load_index = bias_load_index + 1
        ) begin
            scan_status = $fscanf(bias_file, "%d\n", bias_memory_write_data);

            if (scan_status != 1) begin
                $display("ERROR: Failed reading Conv1 bias value at index %0d", bias_load_index);
                $finish;
            end

            write_bias_memory_value(bias_load_index[3:0], bias_memory_write_data);
        end

        $fclose(bias_file);

        $display("Loading expected Conv1 pooled output memory...");
        expected_file = $fopen(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/vectors/out_conv1_pool_int8_expected.txt",
            "r"
        );

        if (expected_file == 0) begin
            $display("ERROR: Could not open expected Conv1 pooled output file.");
            $finish;
        end

        for (
            expected_load_index = 0;
            expected_load_index < POOLED_OUTPUT_TOTAL_VALUES;
            expected_load_index = expected_load_index + 1
        ) begin
            scan_status = $fscanf(expected_file, "%d\n", expected_pooled_output_memory_array[expected_load_index]);

            if (scan_status != 1) begin
                $display("ERROR: Failed reading expected Conv1 pooled value at index %0d", expected_load_index);
                $finish;
            end
        end

        $fclose(expected_file);

        repeat(10) @(posedge clk);

        $display("Starting Conv1 race-free write-stream comparison...");
        @(posedge clk);
        #1;
        start = 1'b1;

        @(posedge clk);
        #1;
        start = 1'b0;

        wait(done == 1'b1);

        repeat(5) @(posedge clk);

        for (
            output_check_index = 0;
            output_check_index < POOLED_OUTPUT_TOTAL_VALUES;
            output_check_index = output_check_index + 1
        ) begin
            if (output_seen_array[output_check_index] !== 1'b1) begin
                missing_output_count = missing_output_count + 1;

                if (missing_output_count <= 20) begin
                    $display("MISSING output write at pooled index %0d", output_check_index);
                end
            end
        end

        $display("Conv1 race-free monitor comparison completed.");
        $display("Total written outputs = %0d", written_output_count);
        $display("Total missing outputs = %0d", missing_output_count);
        $display("Total duplicate outputs = %0d", duplicate_output_count);

        if (
            (mismatch_count == 0) &&
            (unknown_count == 0) &&
            (missing_output_count == 0) &&
            (duplicate_output_count == 0) &&
            (written_output_count == POOLED_OUTPUT_TOTAL_VALUES)
        ) begin
            $display("PASS: Conv1 race-free write-stream output matches golden vector with no X/Z values.");
        end else begin
            $display(
                "FAIL: Conv1 race-free write-stream has %0d mismatches, %0d unknown X/Z values, %0d missing outputs, %0d duplicate outputs, and %0d total writes.",
                mismatch_count,
                unknown_count,
                missing_output_count,
                duplicate_output_count,
                written_output_count
            );
        end

        $finish;
    end

endmodule