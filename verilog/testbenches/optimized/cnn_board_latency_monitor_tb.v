`timescale 1ns / 1ps
`default_nettype none

module cnn_board_latency_monitor_tb;
    localparam integer BOARD_CLOCK_PERIOD_NS = 10;
    localparam integer FRAME_COUNT           = 4;
    localparam [63:0]  SAFETY_TIMEOUT_NS     = 64'd7000000000;
    reg clk;
    reg reset_button;
    reg start_button;
    wire led_done;
    wire led_busy;
    wire led_started;
    wire led_pass;
    wire led_fail;
    wire [4:0] led_status;
    // Testbench-only waveform signals.
    // These do not exist in the hardware bitstream. They are only for clean simulation observation.
    reg [15:0] waveform_pass_marker_8645;
    reg [15:0] waveform_result_code;
    reg [4:0]  waveform_current_state;
    reg [1:0]  waveform_frame_index;
    reg [14:0] waveform_temporal_read_address;
    reg [12:0] waveform_last_feature_address;
    reg signed [7:0] waveform_last_feature_data;
    reg [31:0] waveform_feature_write_count;
    reg [63:0] waveform_latency_board_cycles;
    reg [63:0] waveform_latency_time_ns;
    reg waveform_latency_active;
    reg waveform_latency_done;
    reg waveform_safe_write_enable;
    // Safe LED mirrors for clean waveform screenshots.
    // These convert initial X/Z states into known 0/1 values.
    reg safe_led_done;
    reg safe_led_busy;
    reg safe_led_started;
    reg safe_led_pass;
    reg safe_led_fail;
    reg [4:0] safe_led_status;
    time start_time_ns;
    time done_time_ns;
    time total_latency_ns;
    real total_latency_ms;
    real average_latency_per_frame_ms;
    real estimated_frame_throughput_fps;
    cnn_feature_demo_top dut (
        .clk(clk),
        .reset_button(reset_button),
        .start_button(start_button),
        .led_done(led_done),
        .led_busy(led_busy),
        .led_started(led_started),
        .led_pass(led_pass),
        .led_fail(led_fail),
        .led_status(led_status)
    );
    always #(BOARD_CLOCK_PERIOD_NS / 2) begin
        clk = ~clk;
    end
    // Clean waveform monitor. This avoids showing X/Z values when internal CNN output signals are not valid.
    always @(posedge clk) begin
        waveform_pass_marker_8645 <= 16'h8645;
        // Safe LED mirrors for screenshots and result checking.
        safe_led_done    <= (led_done    === 1'b1) ? 1'b1 : 1'b0;
        safe_led_busy    <= (led_busy    === 1'b1) ? 1'b1 : 1'b0;
        safe_led_started <= (led_started === 1'b1) ? 1'b1 : 1'b0;
        safe_led_pass    <= (led_pass    === 1'b1) ? 1'b1 : 1'b0;
        safe_led_fail    <= (led_fail    === 1'b1) ? 1'b1 : 1'b0;
        if ((^led_status) === 1'bx) begin
            safe_led_status <= 5'd0;
        end else begin
            safe_led_status <= led_status;
        end
        // Safe internal-state mirrors. These keep waveform values green before the DUT settles.
        if ((^dut.current_state) === 1'bx) begin
            waveform_current_state <= 5'd0;
        end else begin
            waveform_current_state <= dut.current_state;
        end
        if ((^dut.current_frame_index) === 1'bx) begin
            waveform_frame_index <= 2'd0;
        end else begin
            waveform_frame_index <= dut.current_frame_index;
        end
        if ((^dut.temporal_feature_read_address) === 1'bx) begin
            waveform_temporal_read_address <= 15'd0;
        end else begin
            waveform_temporal_read_address <= dut.temporal_feature_read_address;
        end
        if (waveform_latency_active && !waveform_latency_done) begin
            waveform_latency_board_cycles <= waveform_latency_board_cycles + 64'd1;
        end
        if (dut.conv2_pooled_output_write_enable_monitor === 1'b1) begin
            waveform_safe_write_enable <= 1'b1;

            if ((^dut.conv2_pooled_output_write_address_monitor) !== 1'bx) begin
                waveform_last_feature_address <=
                    dut.conv2_pooled_output_write_address_monitor;
            end
            if ((^dut.conv2_pooled_output_write_data_monitor) !== 1'bx) begin
                waveform_last_feature_data <=
                    dut.conv2_pooled_output_write_data_monitor;
            end
            waveform_feature_write_count <= waveform_feature_write_count + 32'd1;
        end else begin
            waveform_safe_write_enable <= 1'b0;
        end
        if ((safe_led_done === 1'b1) &&
            (safe_led_busy === 1'b0) &&
            (safe_led_started === 1'b1) &&
            (safe_led_pass === 1'b1) &&
            (safe_led_fail === 1'b0)) begin
            waveform_result_code <= 16'h8645;
        end else if (led_fail === 1'b1) begin
            waveform_result_code <= 16'hFFFF;
        end else begin
            waveform_result_code <= 16'h0000;
        end
    end
    initial begin
        clk = 1'b0;
        // Keep reset active from time zero so DUT registers settle cleanly.
        reset_button = 1'b1;
        start_button = 1'b0;
        waveform_pass_marker_8645 = 16'h8645;
        waveform_result_code = 16'h0000;
        waveform_current_state = 5'd0;
        waveform_frame_index = 2'd0;
        waveform_temporal_read_address = 15'd0;
        waveform_last_feature_address = 13'd0;
        waveform_last_feature_data = 8'sd0;
        waveform_feature_write_count = 32'd0;
        waveform_latency_board_cycles = 64'd0;
        waveform_latency_time_ns = 64'd0;
        waveform_latency_active = 1'b0;
        waveform_latency_done = 1'b0;
        waveform_safe_write_enable = 1'b0;
        safe_led_done = 1'b0;
        safe_led_busy = 1'b0;
        safe_led_started = 1'b0;
        safe_led_pass = 1'b0;
        safe_led_fail = 1'b0;
        safe_led_status = 5'd0;
        start_time_ns = 0;
        done_time_ns = 0;
        total_latency_ns = 0;
        total_latency_ms = 0.0;
        average_latency_per_frame_ms = 0.0;
        estimated_frame_throughput_fps = 0.0;
        $display("================================================");
        $display("Board-level latency and waveform monitor started");
        $display("Target top module: cnn_feature_demo_top");
        $display("Board clock: 100 MHz");
        $display("Internal CNN core clock: 50 MHz");
        $display("Waveform PASS marker: 8645");
        $display("Safety timeout: 7 seconds simulated time");
        $display("================================================");
        // Equivalent to holding BTNC from time zero, then releasing it.
        $display("Holding reset button active from time zero...");
        repeat (30) @(posedge clk);
        reset_button = 1'b0;
        $display("Reset button released.");
        repeat (20) @(posedge clk);
        // Equivalent to manually pressing BTNU.
        $display("Applying start button pulse...");
        @(posedge clk);
        start_button = 1'b1;
        repeat (10) @(posedge clk);
        start_button = 1'b0;
        // Start latency measurement when the design confirms that the start command has been accepted.
        wait (led_started === 1'b1);
        start_time_ns = $time;
        waveform_latency_active = 1'b1;
        $display("Start accepted at time = %0t ns", start_time_ns);
        // End latency measurement when the same terminal condition observed on the physical board is reached.
        wait ((led_done === 1'b1) && (led_pass === 1'b1));
        done_time_ns = $time;
        waveform_latency_done = 1'b1;
        waveform_latency_active = 1'b0;
        total_latency_ns = done_time_ns - start_time_ns;
        waveform_latency_time_ns = total_latency_ns;
        total_latency_ms = total_latency_ns / 1000000.0;
        average_latency_per_frame_ms = total_latency_ms / FRAME_COUNT;
        estimated_frame_throughput_fps =
            FRAME_COUNT / (total_latency_ns / 1000000000.0);
        // Allow safe LED mirrors and waveform_result_code to update cleanly before printing.
        repeat (3) @(posedge clk);
        $display("================================================");
        $display("Board-level latency result");
        $display("Start accepted time              = %0t ns", start_time_ns);
        $display("Done and Pass time               = %0t ns", done_time_ns);
        $display("Total four-frame latency         = %0t ns", total_latency_ns);
        $display("Total four-frame latency         = %0.6f ms", total_latency_ms);
        $display("Average latency per frame        = %0.6f ms/frame", average_latency_per_frame_ms);
        $display("Estimated frame throughput       = %0.6f frames/second", estimated_frame_throughput_fps);
        $display("Feature writes observed          = %0d", waveform_feature_write_count);
        $display("Waveform result code             = %h", waveform_result_code);
        $display("Final LED states:");
        $display("  Done    = %b", safe_led_done);
        $display("  Busy    = %b", safe_led_busy);
        $display("  Started = %b", safe_led_started);
        $display("  Pass    = %b", safe_led_pass);
        $display("  Fail    = %b", safe_led_fail);
        $display("  Status  = %b", safe_led_status);
        $display("================================================");
        if ((safe_led_done === 1'b1) &&
            (safe_led_busy === 1'b0) &&
            (safe_led_started === 1'b1) &&
            (safe_led_pass === 1'b1) &&
            (safe_led_fail === 1'b0)) begin
            $display("PASS: Board-level latency simulation completed successfully.");
            $display("PASS MARKER: 8645");
        end else begin
            $display("FAIL: Board-level latency simulation completed, but final LED state was not the expected PASS state.");
        end
        #100;
        $finish;
    end
    initial begin
        // Safety timeout: 7 seconds simulated time.
        #(SAFETY_TIMEOUT_NS);
        $display("ERROR: Latency monitor timed out before Done and Pass were asserted.");
        $display("Final LED states at timeout:");
        $display("  Done    = %b", safe_led_done);
        $display("  Busy    = %b", safe_led_busy);
        $display("  Started = %b", safe_led_started);
        $display("  Pass    = %b", safe_led_pass);
        $display("  Fail    = %b", safe_led_fail);
        $display("  Status  = %b", safe_led_status);
        $finish;
    end
endmodule
`default_nettype wire
