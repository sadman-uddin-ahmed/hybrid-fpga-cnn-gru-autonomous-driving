`timescale 1ns / 1ps

module temporal_feature_buffer_tb;
    localparam FEATURE_VALUES_PER_FRAME = 8192;
    localparam TOTAL_FRAME_COUNT        = 4;
    reg clk;
    reg rst;
    reg capture_reset;
    reg [12:0] feature_write_address;
    reg signed [7:0] feature_write_data;
    reg feature_write_enable;
    reg [14:0] feature_read_address;
    wire signed [7:0] feature_read_data;
    wire [2:0] captured_frame_count;
    wire capture_complete;
    integer frame_index;
    integer feature_index;
    integer expected_value;
    integer error_count;
    temporal_feature_buffer temporal_feature_buffer_inst (
        .clk(clk),
        .rst(rst),
        .capture_reset(capture_reset),
        .feature_write_address(feature_write_address),
        .feature_write_data(feature_write_data),
        .feature_write_enable(feature_write_enable),
        .feature_read_address(feature_read_address),
        .feature_read_data(feature_read_data),
        .captured_frame_count(captured_frame_count),
        .capture_complete(capture_complete)
    );
    always begin
        #10 clk = ~clk;
    end
    task write_one_frame;
        input integer input_frame_index;
        begin
            for (feature_index = 0;
                 feature_index < FEATURE_VALUES_PER_FRAME;
                 feature_index = feature_index + 1) begin
                @(negedge clk);
                feature_write_address = feature_index[12:0];
                feature_write_data =
                    ((input_frame_index * 17) + feature_index) % 128;
                feature_write_enable = 1'b1;
            end
            @(negedge clk);
            feature_write_enable = 1'b0;
        end
    endtask
    task check_memory_value;
        input integer input_frame_index;
        input integer input_feature_index;
        begin
            @(negedge clk);
            feature_read_address =
                (input_frame_index * FEATURE_VALUES_PER_FRAME) +
                input_feature_index;
            @(posedge clk);
            #1;
            expected_value =
                ((input_frame_index * 17) + input_feature_index) % 128;
            if (feature_read_data !== expected_value[7:0]) begin
                error_count = error_count + 1;
                $display(
                    "ERROR: frame=%0d feature=%0d expected=%0d received=%0d",
                    input_frame_index,
                    input_feature_index,
                    expected_value,
                    feature_read_data
                );
            end else begin
                $display(
                    "PASS: frame=%0d feature=%0d value=%0d",
                    input_frame_index,
                    input_feature_index,
                    feature_read_data
                );
            end
        end
    endtask
    initial begin
        clk                   = 1'b0;
        rst                   = 1'b1;
        capture_reset         = 1'b0;
        feature_write_address = 13'd0;
        feature_write_data    = 8'sd0;
        feature_write_enable  = 1'b0;
        feature_read_address  = 15'd0;
        error_count           = 0;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        @(negedge clk);
        capture_reset = 1'b1;
        @(negedge clk);
        capture_reset = 1'b0;
        $display("Writing frame 0...");
        write_one_frame(0);
        $display("Writing frame 1...");
        write_one_frame(1);
        $display("Writing frame 2...");
        write_one_frame(2);
        $display("Writing frame 3...");
        write_one_frame(3);
        repeat (3) @(posedge clk);
        if (captured_frame_count !== 3'd4) begin
            error_count = error_count + 1;
            $display(
                "ERROR: expected captured_frame_count=4, received=%0d",
                captured_frame_count
            );
        end else begin
            $display(
                "PASS: captured_frame_count=%0d",
                captured_frame_count
            );
        end
        if (capture_complete !== 1'b1) begin
            error_count = error_count + 1;
            $display("ERROR: capture_complete was not asserted.");
        end else begin
            $display("PASS: capture_complete asserted.");
        end
        check_memory_value(0, 0);
        check_memory_value(0, 8191);
        check_memory_value(1, 0);
        check_memory_value(1, 8191);
        check_memory_value(2, 0);
        check_memory_value(2, 8191);
        check_memory_value(3, 0);
        check_memory_value(3, 8191);
        if (error_count == 0) begin
            $display("TEMPORAL FEATURE BUFFER TEST PASSED.");
        end else begin
            $display(
                "TEMPORAL FEATURE BUFFER TEST FAILED. Errors=%0d",
                error_count
            );
        end
        $finish;
    end
endmodule
