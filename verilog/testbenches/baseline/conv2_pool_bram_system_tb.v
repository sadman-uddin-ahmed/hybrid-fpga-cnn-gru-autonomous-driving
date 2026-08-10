`timescale 1ns / 1ps

module conv2_pool_bram_system_tb;
    localparam CLOCK_PERIOD = 10;
    localparam INPUT_TOTAL_VALUES         = 16384;
    localparam WEIGHT_TOTAL_VALUES        = 4608;
    localparam BIAS_TOTAL_VALUES          = 32;
    localparam POOLED_OUTPUT_TOTAL_VALUES = 8192;
    reg clk;
    reg rst;
    reg start;
    reg input_memory_write_enable;
    reg [13:0] input_memory_write_address;
    reg signed [7:0] input_memory_write_data;
    reg weight_memory_write_enable;
    reg [12:0] weight_memory_write_address;
    reg signed [7:0] weight_memory_write_data;
    reg bias_memory_write_enable;
    reg [4:0] bias_memory_write_address;
    reg signed [31:0] bias_memory_write_data;
    reg [12:0] pooled_output_read_address;
    wire signed [7:0] pooled_output_read_data;
    wire done;
    reg signed [7:0] expected_pooled_output_memory_array [0:POOLED_OUTPUT_TOTAL_VALUES-1];
    integer input_file;
    integer weight_file;
    integer bias_file;
    integer expected_file;
    integer input_load_index;
    integer weight_load_index;
    integer bias_load_index;
    integer expected_load_index;
    integer output_compare_index;
    integer mismatch_count;
    integer scan_status;
    reg signed [7:0] captured_pooled_output;
    reg signed [7:0] expected_pooled_output;
    conv2_pool_bram_system dut (
        .clk(clk),
        .rst(rst),
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

        .done(done)
    );
    always #(CLOCK_PERIOD / 2) clk = ~clk;
    task write_input_memory_value;
        input [13:0] task_write_address;
        input signed [7:0] task_write_data;
        begin
            @(posedge clk);
            input_memory_write_enable <= 1'b1;
            input_memory_write_address <= task_write_address;
            input_memory_write_data <= task_write_data;

            @(posedge clk);
            input_memory_write_enable <= 1'b0;
        end
    endtask
    task write_weight_memory_value;
        input [12:0] task_write_address;
        input signed [7:0] task_write_data;
        begin
            @(posedge clk);
            weight_memory_write_enable <= 1'b1;
            weight_memory_write_address <= task_write_address;
            weight_memory_write_data <= task_write_data;
            @(posedge clk);
            weight_memory_write_enable <= 1'b0;
        end
    endtask
    task write_bias_memory_value;
        input [4:0] task_write_address;
        input signed [31:0] task_write_data;
        begin
            @(posedge clk);
            bias_memory_write_enable <= 1'b1;
            bias_memory_write_address <= task_write_address;
            bias_memory_write_data <= task_write_data;
            @(posedge clk);
            bias_memory_write_enable <= 1'b0;
        end
    endtask
    task read_pooled_output_value;
        input [12:0] task_read_address;
        output signed [7:0] task_read_data;
        begin
            @(posedge clk);
            pooled_output_read_address <= task_read_address;
            @(posedge clk);
            @(posedge clk);
            task_read_data = pooled_output_read_data;
        end
    endtask
    initial begin
        clk = 1'b0;
        rst = 1'b1;
        start = 1'b0;
        input_memory_write_enable = 1'b0;
        input_memory_write_address = 14'd0;
        input_memory_write_data = 8'sd0;
        weight_memory_write_enable = 1'b0;
        weight_memory_write_address = 13'd0;
        weight_memory_write_data = 8'sd0;
        bias_memory_write_enable = 1'b0;
        bias_memory_write_address = 5'd0;
        bias_memory_write_data = 32'sd0;
        pooled_output_read_address = 13'd0;
        mismatch_count = 0;
        captured_pooled_output = 8'sd0;
        expected_pooled_output = 8'sd0;
        repeat(10) @(posedge clk);
        rst = 1'b0;
        repeat(5) @(posedge clk);
        $display("Loading Conv2 input feature-map memory...");
        input_file = $fopen("data/vectors/in_conv2_int8.txt", "r");

        if (input_file == 0) begin
            $display("ERROR: Could not open data/vectors/in_conv2_int8.txt");
            $finish;
        end
        for (
            input_load_index = 0;
            input_load_index < INPUT_TOTAL_VALUES;
            input_load_index = input_load_index + 1
        ) begin
            scan_status = $fscanf(input_file, "%d\n", input_memory_write_data);
            write_input_memory_value(input_load_index[13:0], input_memory_write_data);
        end
        $fclose(input_file);
        $display("Loading Conv2 weight memory...");
        weight_file = $fopen("data/quant/W8_txt/conv2_w.txt", "r");
        if (weight_file == 0) begin
            $display("ERROR: Could not open data/quant/W8_txt/conv2_w.txt");
            $finish;
        end
        for (
            weight_load_index = 0;
            weight_load_index < WEIGHT_TOTAL_VALUES;
            weight_load_index = weight_load_index + 1
        ) begin
            scan_status = $fscanf(weight_file, "%d\n", weight_memory_write_data);
            write_weight_memory_value(weight_load_index[12:0], weight_memory_write_data);
        end
        $fclose(weight_file);
        $display("Loading Conv2 bias memory...");
        bias_file = $fopen("data/quant/W8_txt/conv2_b_int32_correct.txt", "r");
        if (bias_file == 0) begin
            $display("ERROR: Could not open data/quant/W8_txt/conv2_b_int32_correct.txt");
            $finish;
        end
        for (
            bias_load_index = 0;
            bias_load_index < BIAS_TOTAL_VALUES;
            bias_load_index = bias_load_index + 1
        ) begin
            scan_status = $fscanf(bias_file, "%d\n", bias_memory_write_data);
            write_bias_memory_value(bias_load_index[4:0], bias_memory_write_data);
        end
        $fclose(bias_file);
        $display("Loading expected Conv2 pooled output memory...");
        expected_file = $fopen("data/vectors/out_conv2_pool_int8_expected.txt", "r");
        if (expected_file == 0) begin
            $display("ERROR: Could not open data/vectors/out_conv2_pool_int8_expected.txt");
            $finish;
        end
        for (
            expected_load_index = 0;
            expected_load_index < POOLED_OUTPUT_TOTAL_VALUES;
            expected_load_index = expected_load_index + 1
        ) begin
            scan_status = $fscanf(expected_file, "%d\n", expected_pooled_output_memory_array[expected_load_index]);
        end
        $fclose(expected_file);
        repeat(10) @(posedge clk);
        $display("Starting full Conv2 + MaxPool BRAM system...");
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        wait(done == 1'b1);
        $display("Conv2 + MaxPool BRAM system completed.");
        $display("Comparing pooled output with golden vector...");
        mismatch_count = 0;
        for (
            output_compare_index = 0;
            output_compare_index < POOLED_OUTPUT_TOTAL_VALUES;
            output_compare_index = output_compare_index + 1
        ) begin
            read_pooled_output_value(output_compare_index[12:0], captured_pooled_output);
            expected_pooled_output = expected_pooled_output_memory_array[output_compare_index];
            if (captured_pooled_output !== expected_pooled_output) begin
                mismatch_count = mismatch_count + 1;
                if (mismatch_count <= 50) begin
                    $display(
                        "MISMATCH at pooled index %0d: expected = %0d, got = %0d",
                        output_compare_index,
                        expected_pooled_output,
                        captured_pooled_output
                    );
                end
            end
        end
        if (mismatch_count == 0) begin
            $display("PASS: Full Conv2 + MaxPool BRAM system output matches golden vector.");
        end else begin
            $display("FAIL: Full Conv2 + MaxPool BRAM system has %0d mismatches.", mismatch_count);
        end
        $finish;
    end
endmodule