`timescale 1ns / 1ps

module cnn_feature_extractor_bram_system_tb;
    localparam CLOCK_PERIOD = 10;
    localparam IMAGE_TOTAL_VALUES               = 12288;
    localparam CONV1_WEIGHT_TOTAL_VALUES        = 432;
    localparam CONV1_BIAS_TOTAL_VALUES          = 16;
    localparam CONV2_WEIGHT_TOTAL_VALUES        = 4608;
    localparam CONV2_BIAS_TOTAL_VALUES          = 32;
    localparam CONV2_POOLED_OUTPUT_TOTAL_VALUES = 8192;
    reg clk;
    reg rst;
    reg start;
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
    wire done;
    reg signed [7:0] expected_conv2_pooled_output_memory_array [0:CONV2_POOLED_OUTPUT_TOTAL_VALUES-1];
    reg output_seen_array [0:CONV2_POOLED_OUTPUT_TOTAL_VALUES-1];
    integer image_file;
    integer conv1_weight_file;
    integer conv1_bias_file;
    integer conv2_weight_file;
    integer conv2_bias_file;
    integer expected_file;
    integer image_load_index;
    integer conv1_weight_load_index;
    integer conv1_bias_load_index;
    integer conv2_weight_load_index;
    integer conv2_bias_load_index;
    integer expected_load_index;
    integer output_seen_initialize_index;
    integer output_check_index;
    integer scan_status;
    integer mismatch_count;
    integer unknown_count;
    integer written_output_count;
    integer missing_output_count;
    integer duplicate_output_count;
    reg signed [7:0] expected_conv2_pooled_output_value;
    cnn_feature_extractor_bram_system dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .image_memory_write_enable(image_memory_write_enable),
        .image_memory_write_address(image_memory_write_address),
        .image_memory_write_data(image_memory_write_data),
        .conv1_weight_memory_write_enable(conv1_weight_memory_write_enable),
        .conv1_weight_memory_write_address(conv1_weight_memory_write_address),
        .conv1_weight_memory_write_data(conv1_weight_memory_write_data),
        .conv1_bias_memory_write_enable(conv1_bias_memory_write_enable),
        .conv1_bias_memory_write_address(conv1_bias_memory_write_address),
        .conv1_bias_memory_write_data(conv1_bias_memory_write_data),
        .conv2_weight_memory_write_enable(conv2_weight_memory_write_enable),
        .conv2_weight_memory_write_address(conv2_weight_memory_write_address),
        .conv2_weight_memory_write_data(conv2_weight_memory_write_data),
        .conv2_bias_memory_write_enable(conv2_bias_memory_write_enable),
        .conv2_bias_memory_write_address(conv2_bias_memory_write_address),
        .conv2_bias_memory_write_data(conv2_bias_memory_write_data),
        .conv2_pooled_output_read_address(conv2_pooled_output_read_address),
        .conv2_pooled_output_read_data(conv2_pooled_output_read_data),
        .conv2_pooled_output_write_address_monitor(conv2_pooled_output_write_address_monitor),
        .conv2_pooled_output_write_data_monitor(conv2_pooled_output_write_data_monitor),
        .conv2_pooled_output_write_enable_monitor(conv2_pooled_output_write_enable_monitor),
        .done(done)
    );
    always #(CLOCK_PERIOD / 2) clk = ~clk;
    task write_image_memory_value;
        input [13:0] task_write_address;
        input signed [7:0] task_write_data;
        begin
            @(posedge clk);
            #1;
            image_memory_write_enable = 1'b1;
            image_memory_write_address = task_write_address;
            image_memory_write_data = task_write_data;
            @(posedge clk);
            #1;
            image_memory_write_enable = 1'b0;
        end
    endtask
    task write_conv1_weight_memory_value;
        input [8:0] task_write_address;
        input signed [7:0] task_write_data;
        begin
            @(posedge clk);
            #1;
            conv1_weight_memory_write_enable = 1'b1;
            conv1_weight_memory_write_address = task_write_address;
            conv1_weight_memory_write_data = task_write_data;
            @(posedge clk);
            #1;
            conv1_weight_memory_write_enable = 1'b0;
        end
    endtask
    task write_conv1_bias_memory_value;
        input [3:0] task_write_address;
        input signed [31:0] task_write_data;
        begin
            @(posedge clk);
            #1;
            conv1_bias_memory_write_enable = 1'b1;
            conv1_bias_memory_write_address = task_write_address;
            conv1_bias_memory_write_data = task_write_data;
            @(posedge clk);
            #1;
            conv1_bias_memory_write_enable = 1'b0;
        end
    endtask
    task write_conv2_weight_memory_value;
        input [12:0] task_write_address;
        input signed [7:0] task_write_data;
        begin
            @(posedge clk);
            #1;
            conv2_weight_memory_write_enable = 1'b1;
            conv2_weight_memory_write_address = task_write_address;
            conv2_weight_memory_write_data = task_write_data;
            @(posedge clk);
            #1;
            conv2_weight_memory_write_enable = 1'b0;
        end
    endtask
    task write_conv2_bias_memory_value;
        input [4:0] task_write_address;
        input signed [31:0] task_write_data;
        begin
            @(posedge clk);
            #1;
            conv2_bias_memory_write_enable = 1'b1;
            conv2_bias_memory_write_address = task_write_address;
            conv2_bias_memory_write_data = task_write_data;
            @(posedge clk);
            #1;
            conv2_bias_memory_write_enable = 1'b0;
        end
    endtask
    always @(posedge clk) begin
        #1;
        if (!rst && conv2_pooled_output_write_enable_monitor) begin
            written_output_count = written_output_count + 1;
            if (output_seen_array[conv2_pooled_output_write_address_monitor] === 1'b1) begin
                duplicate_output_count = duplicate_output_count + 1;
                if (duplicate_output_count <= 20) begin
                    $display(
                        "DUPLICATE Conv2 output write at index %0d",
                        conv2_pooled_output_write_address_monitor
                    );
                end
            end
            output_seen_array[conv2_pooled_output_write_address_monitor] = 1'b1;
            expected_conv2_pooled_output_value =
                expected_conv2_pooled_output_memory_array[conv2_pooled_output_write_address_monitor];
            if ((^conv2_pooled_output_write_data_monitor) === 1'bx) begin
                unknown_count = unknown_count + 1;
                if (unknown_count <= 20) begin
                    $display(
                        "UNKNOWN X/Z at Conv2 pooled index %0d: got = %b, expected = %0d",
                        conv2_pooled_output_write_address_monitor,
                        conv2_pooled_output_write_data_monitor,
                        expected_conv2_pooled_output_value
                    );
                end
            end else if (conv2_pooled_output_write_data_monitor !== expected_conv2_pooled_output_value) begin
                mismatch_count = mismatch_count + 1;
                if (mismatch_count <= 20) begin
                    $display(
                        "MISMATCH at Conv2 pooled index %0d: expected = %0d, got = %0d",
                        conv2_pooled_output_write_address_monitor,
                        expected_conv2_pooled_output_value,
                        conv2_pooled_output_write_data_monitor
                    );
                end
            end
        end
    end
    initial begin
        clk = 1'b0;
        rst = 1'b1;
        start = 1'b0;
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
        mismatch_count = 0;
        unknown_count = 0;
        written_output_count = 0;
        missing_output_count = 0;
        duplicate_output_count = 0;
        for (
            output_seen_initialize_index = 0;
            output_seen_initialize_index < CONV2_POOLED_OUTPUT_TOTAL_VALUES;
            output_seen_initialize_index = output_seen_initialize_index + 1
        ) begin
            output_seen_array[output_seen_initialize_index] = 1'b0;
        end
        repeat(10) @(posedge clk);
        #1;
        rst = 1'b0;
        repeat(5) @(posedge clk);
        $display("Loading input image memory...");
        image_file = $fopen(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/vectors/in_img_int8.txt",
            "r"
        );
        if (image_file == 0) begin
            $display("ERROR: Could not open input image file.");
            $finish;
        end
        for (
            image_load_index = 0;
            image_load_index < IMAGE_TOTAL_VALUES;
            image_load_index = image_load_index + 1
        ) begin
            scan_status = $fscanf(image_file, "%d\n", image_memory_write_data);
            if (scan_status != 1) begin
                $display("ERROR: Failed reading input image value at index %0d", image_load_index);
                $finish;
            end
            write_image_memory_value(image_load_index[13:0], image_memory_write_data);
        end
        $fclose(image_file);
        $display("Loading Conv1 weight memory...");
        conv1_weight_file = $fopen(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/quant/W8_txt/conv1_w.txt",
            "r"
        );
        if (conv1_weight_file == 0) begin
            $display("ERROR: Could not open Conv1 weight file.");
            $finish;
        end
        for (
            conv1_weight_load_index = 0;
            conv1_weight_load_index < CONV1_WEIGHT_TOTAL_VALUES;
            conv1_weight_load_index = conv1_weight_load_index + 1
        ) begin
            scan_status = $fscanf(conv1_weight_file, "%d\n", conv1_weight_memory_write_data);
            if (scan_status != 1) begin
                $display("ERROR: Failed reading Conv1 weight value at index %0d", conv1_weight_load_index);
                $finish;
            end
            write_conv1_weight_memory_value(conv1_weight_load_index[8:0], conv1_weight_memory_write_data);
        end
        $fclose(conv1_weight_file);
        $display("Loading Conv1 bias memory...");
        conv1_bias_file = $fopen(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/quant/W8_txt/conv1_b_int32_correct.txt",
            "r"
        );
        if (conv1_bias_file == 0) begin
            $display("ERROR: Could not open Conv1 bias file.");
            $finish;
        end
        for (
            conv1_bias_load_index = 0;
            conv1_bias_load_index < CONV1_BIAS_TOTAL_VALUES;
            conv1_bias_load_index = conv1_bias_load_index + 1
        ) begin
            scan_status = $fscanf(conv1_bias_file, "%d\n", conv1_bias_memory_write_data);
            if (scan_status != 1) begin
                $display("ERROR: Failed reading Conv1 bias value at index %0d", conv1_bias_load_index);
                $finish;
            end
            write_conv1_bias_memory_value(conv1_bias_load_index[3:0], conv1_bias_memory_write_data);
        end
        $fclose(conv1_bias_file);
        $display("Loading Conv2 weight memory...");
        conv2_weight_file = $fopen(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/quant/W8_txt/conv2_w.txt",
            "r"
        );
        if (conv2_weight_file == 0) begin
            $display("ERROR: Could not open Conv2 weight file.");
            $finish;
        end
        for (
            conv2_weight_load_index = 0;
            conv2_weight_load_index < CONV2_WEIGHT_TOTAL_VALUES;
            conv2_weight_load_index = conv2_weight_load_index + 1
        ) begin
            scan_status = $fscanf(conv2_weight_file, "%d\n", conv2_weight_memory_write_data);
            if (scan_status != 1) begin
                $display("ERROR: Failed reading Conv2 weight value at index %0d", conv2_weight_load_index);
                $finish;
            end
            write_conv2_weight_memory_value(conv2_weight_load_index[12:0], conv2_weight_memory_write_data);
        end
        $fclose(conv2_weight_file);
        $display("Loading Conv2 bias memory...");
        conv2_bias_file = $fopen(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/quant/W8_txt/conv2_b_int32_correct.txt",
            "r"
        );
        if (conv2_bias_file == 0) begin
            $display("ERROR: Could not open Conv2 bias file.");
            $finish;
        end
        for (
            conv2_bias_load_index = 0;
            conv2_bias_load_index < CONV2_BIAS_TOTAL_VALUES;
            conv2_bias_load_index = conv2_bias_load_index + 1
        ) begin
            scan_status = $fscanf(conv2_bias_file, "%d\n", conv2_bias_memory_write_data);
            if (scan_status != 1) begin
                $display("ERROR: Failed reading Conv2 bias value at index %0d", conv2_bias_load_index);
                $finish;
            end
            write_conv2_bias_memory_value(conv2_bias_load_index[4:0], conv2_bias_memory_write_data);
        end
        $fclose(conv2_bias_file);
        $display("Loading expected Conv2 pooled output memory...");
        expected_file = $fopen(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/vectors/out_conv2_pool_int8_expected.txt",
            "r"
        );
        if (expected_file == 0) begin
            $display("ERROR: Could not open expected Conv2 pooled output file.");
            $finish;
        end
        for (
            expected_load_index = 0;
            expected_load_index < CONV2_POOLED_OUTPUT_TOTAL_VALUES;
            expected_load_index = expected_load_index + 1
        ) begin
            scan_status = $fscanf(expected_file, "%d\n", expected_conv2_pooled_output_memory_array[expected_load_index]);
            if (scan_status != 1) begin
                $display("ERROR: Failed reading expected Conv2 pooled value at index %0d", expected_load_index);
                $finish;
            end
        end
        $fclose(expected_file);
        repeat(10) @(posedge clk);
        $display("Starting CNN feature extractor final race-free write-stream comparison...");
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
            output_check_index < CONV2_POOLED_OUTPUT_TOTAL_VALUES;
            output_check_index = output_check_index + 1
        ) begin
            if (output_seen_array[output_check_index] !== 1'b1) begin
                missing_output_count = missing_output_count + 1;
                if (missing_output_count <= 20) begin
                    $display("MISSING Conv2 output write at index %0d", output_check_index);
                end
            end
        end
        $display("CNN feature extractor final monitor comparison completed.");
        $display("Total Conv2 written outputs = %0d", written_output_count);
        $display("Total Conv2 missing outputs = %0d", missing_output_count);
        $display("Total Conv2 duplicate outputs = %0d", duplicate_output_count);
        if (
            (mismatch_count == 0) &&
            (unknown_count == 0) &&
            (missing_output_count == 0) &&
            (duplicate_output_count == 0) &&
            (written_output_count == CONV2_POOLED_OUTPUT_TOTAL_VALUES)
        ) begin
            $display("PASS: CNN feature extractor final write-stream output matches golden Conv2 vector with no X/Z values.");
        end else begin
            $display(
                "FAIL: CNN feature extractor final write-stream has %0d mismatches, %0d unknown X/Z values, %0d missing outputs, %0d duplicate outputs, and %0d total writes.",
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