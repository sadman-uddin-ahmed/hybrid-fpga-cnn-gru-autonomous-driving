`timescale 1ns / 1ps

module cnn_feature_nexys_video_top (
    input  wire       clk,
    input  wire       reset_button,
    input  wire       start_button,
    output wire [7:0] led
);
    // Internal outputs from the validated Basys-3-compatible design
    wire       led_done_internal;
    wire       led_busy_internal;
    wire       led_started_internal;
    wire       led_pass_internal;
    wire       led_fail_internal;
    wire [4:0] led_status_internal;
    // Validated CNN feature-extraction and temporal-buffer controller
    cnn_feature_demo_top cnn_feature_demo_top_inst (
        .clk          (clk),
        .reset_button (reset_button),
        .start_button (start_button),
        .led_done     (led_done_internal),
        .led_busy     (led_busy_internal),
        .led_started  (led_started_internal),
        .led_pass     (led_pass_internal),
        .led_fail     (led_fail_internal),
        .led_status   (led_status_internal)
    );
    // Nexys Video has eight user LEDs
    assign led[0] = led_done_internal;
    assign led[1] = led_busy_internal;
    assign led[2] = led_started_internal;
    assign led[3] = led_pass_internal;
    assign led[4] = led_fail_internal;
    assign led[5] = led_status_internal[0];
    assign led[6] = led_status_internal[1];
    assign led[7] = led_status_internal[2];
endmodule
