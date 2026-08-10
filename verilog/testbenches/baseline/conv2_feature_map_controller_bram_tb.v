`timescale 1ns / 1ps

module conv2_feature_map_controller_bram_tb;
    localparam CLOCK_PERIOD = 10;
    localparam INPUT_TOTAL_VALUES    = 16384;
    localparam WEIGHT_TOTAL_VALUES   = 4608;
    localparam BIAS_TOTAL_VALUES     = 32;
    localparam EXPECTED_TOTAL_VALUES = 8192;
    reg clk;
    reg rst;
    reg start;
    wire [13:0] input_read_address;
    reg signed [7:0] input_read_data;
    wire [12:0] weight_read_address;
    reg signed [7:0] weight_read_data;
    wire [4:0] bias_read_address;
    reg signed [31:0] bias_read_data;
    wire [14:0] output_write_address;
    wire signed [7:0] output_write_data;
    wire output_write_enable;
    wire done;
    reg signed [7:0] input_memory_array [0:INPUT_TOTAL_VALUES-1];
    reg signed [7:0] weight_memory_array [0:WEIGHT_TOTAL_VALUES-1];
    reg signed [31:0] bias_memory_array [0:BIAS_TOTAL_VALUES-1];
    reg signed [7:0] expected_pool_memory_array [0:EXPECTED_TOTAL_VALUES-1];
    integer input_file;
    integer weight_file;
    integer bias_file;
    integer expected_file;
    integer input_load_index;
    integer weight_load_index;
    integer bias_load_index;
    integer expected_load_index;
    integer scan_status;
    reg signed [7:0] captured_conv2_pixel_00;
    reg signed [7:0] captured_conv2_pixel_01;
    reg signed [7:0] captured_conv2_pixel_10;
    reg signed [7:0] captured_conv2_pixel_11;
    reg captured_pixel_00_valid;
    reg captured_pixel_01_valid;
    reg captured_pixel_10_valid;
    reg captured_pixel_11_valid;
    reg signed [7:0] calculated_pool_output;
    reg signed [7:0] expected_pool_output;
    conv2_feature_map_controller_bram dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_read_address(input_read_address),
        .input_read_data(input_read_data),
        .weight_read_address(weight_read_address),
        .weight_read_data(weight_read_data),
        .bias_read_address(bias_read_address),
        .bias_read_data(bias_read_data),
        .output_write_address(output_write_address),
        .output_write_data(output_write_data),
        .output_write_enable(output_write_enable),
        .done(done)
    );
    always #(CLOCK_PERIOD / 2) clk = ~clk;
    always @(posedge clk) begin
        input_read_data  <= input_memory_array[input_read_address];
        weight_read_data <= weight_memory_array[weight_read_address];
        bias_read_data   <= bias_memory_array[bias_read_address];
    end
    always @(posedge clk) begin
        if (rst) begin
            captured_conv2_pixel_00 <= 8'sd0;
            captured_conv2_pixel_01 <= 8'sd0;
            captured_conv2_pixel_10 <= 8'sd0;
            captured_conv2_pixel_11 <= 8'sd0;
            captured_pixel_00_valid <= 1'b0;
            captured_pixel_01_valid <= 1'b0;
            captured_pixel_10_valid <= 1'b0;
            captured_pixel_11_valid <= 1'b0;
        end else begin
            if (output_write_enable) begin
                if (output_write_address == 15'd0) begin
                    captured_conv2_pixel_00 <= output_write_data;
                    captured_pixel_00_valid <= 1'b1;
                    $display("Captured Conv2 raw output address 0  = %0d", output_write_data);
                end
                if (output_write_address == 15'd1) begin
                    captured_conv2_pixel_01 <= output_write_data;
                    captured_pixel_01_valid <= 1'b1;
                    $display("Captured Conv2 raw output address 1  = %0d", output_write_data);
                end
                if (output_write_address == 15'd32) begin
                    captured_conv2_pixel_10 <= output_write_data;
                    captured_pixel_10_valid <= 1'b1;
                    $display("Captured Conv2 raw output address 32 = %0d", output_write_data);
                end
                if (output_write_address == 15'd33) begin
                    captured_conv2_pixel_11 <= output_write_data;
                    captured_pixel_11_valid <= 1'b1;
                    $display("Captured Conv2 raw output address 33 = %0d", output_write_data);
                end
            end
        end
    end
    initial begin
        clk = 1'b0;
        rst = 1'b1;
        start = 1'b0;
        input_read_data = 8'sd0;
        weight_read_data = 8'sd0;
        bias_read_data = 32'sd0;
        calculated_pool_output = 8'sd0;
        expected_pool_output = 8'sd0;
        $display("Loading Conv2 input feature-map memory...");
        input_file = $fopen("data/vectors/in_conv2_int8.txt", "r");
        if (input_file == 0) begin
            $display("ERROR: Could not open data/vectors/in_conv2_int8.txt");
            $finish;
        end
        for (input_load_index = 0; input_load_index < INPUT_TOTAL_VALUES; input_load_index = input_load_index + 1) begin
            scan_status = $fscanf(input_file, "%d\n", input_memory_array[input_load_index]);
        end
        $fclose(input_file);
        $display("Loading Conv2 weight memory...");
        weight_file = $fopen("data/quant/W8_txt/conv2_w.txt", "r");
        if (weight_file == 0) begin
            $display("ERROR: Could not open data/quant/W8_txt/conv2_w.txt");
            $finish;
        end
        for (weight_load_index = 0; weight_load_index < WEIGHT_TOTAL_VALUES; weight_load_index = weight_load_index + 1) begin
            scan_status = $fscanf(weight_file, "%d\n", weight_memory_array[weight_load_index]);
        end
        $fclose(weight_file);
        $display("Loading Conv2 bias memory...");
        bias_file = $fopen("data/quant/W8_txt/conv2_b_int32_correct.txt", "r");
        if (bias_file == 0) begin
            $display("ERROR: Could not open data/quant/W8_txt/conv2_b_int32_correct.txt");
            $finish;
        end
        for (bias_load_index = 0; bias_load_index < BIAS_TOTAL_VALUES; bias_load_index = bias_load_index + 1) begin
            scan_status = $fscanf(bias_file, "%d\n", bias_memory_array[bias_load_index]);
        end
        $fclose(bias_file);
        $display("Loading Conv2 pooled expected output memory...");
        expected_file = $fopen("data/vectors/out_conv2_pool_int8_expected.txt", "r");
        if (expected_file == 0) begin
            $display("ERROR: Could not open data/vectors/out_conv2_pool_int8_expected.txt");
            $finish;
        end
        for (expected_load_index = 0; expected_load_index < EXPECTED_TOTAL_VALUES; expected_load_index = expected_load_index + 1) begin
            scan_status = $fscanf(expected_file, "%d\n", expected_pool_memory_array[expected_load_index]);
        end
        $fclose(expected_file);
        repeat(5) @(posedge clk);
        rst = 1'b0;
        repeat(5) @(posedge clk);
        $display("Starting Conv2 feature-map controller partial simulation...");
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        wait (
            captured_pixel_00_valid &&
            captured_pixel_01_valid &&
            captured_pixel_10_valid &&
            captured_pixel_11_valid
        );
        repeat(2) @(posedge clk);
        calculated_pool_output = captured_conv2_pixel_00;
        if (captured_conv2_pixel_01 > calculated_pool_output) begin
            calculated_pool_output = captured_conv2_pixel_01;
        end
        if (captured_conv2_pixel_10 > calculated_pool_output) begin
            calculated_pool_output = captured_conv2_pixel_10;
        end
        if (captured_conv2_pixel_11 > calculated_pool_output) begin
            calculated_pool_output = captured_conv2_pixel_11;
        end
        expected_pool_output = expected_pool_memory_array[0];
        $display("Conv2 raw pixel 00 = %0d", captured_conv2_pixel_00);
        $display("Conv2 raw pixel 01 = %0d", captured_conv2_pixel_01);
        $display("Conv2 raw pixel 10 = %0d", captured_conv2_pixel_10);
        $display("Conv2 raw pixel 11 = %0d", captured_conv2_pixel_11);
        $display("Calculated pooled output = %0d", calculated_pool_output);
        $display("Expected pooled output   = %0d", expected_pool_output);
        if (calculated_pool_output == expected_pool_output) begin
            $display("PASS: Conv2 feature-map controller produced correct first 2x2 pooled window.");
        end else begin
            $display("FAIL: Conv2 feature-map controller first pooled window mismatch.");
        end
        $finish;
    end
endmodule