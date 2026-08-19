`timescale 1ns / 1ps

module convolution_group_cadence_controller #(
    parameter integer INPUT_CHANNELS    = 3,
    parameter integer MIN_GROUP_CYCLES  = 4
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    output wire                    input_ready,
    input  wire                    first_input_channel,
    input  wire                    last_input_channel,
    output wire                    output_valid,
    output wire                    output_first_input_channel,
    output wire                    output_last_input_channel
);
    localparam integer REQUIRED_GAP =
        (MIN_GROUP_CYCLES > INPUT_CHANNELS) ?
        (MIN_GROUP_CYCLES - INPUT_CHANNELS) : 0;
    reg [7:0] cooldown_count;
    initial begin
        $display("ACTIVE RTL: convolution_group_cadence_controller GROUP-CADENCE V1");
    end
    assign input_ready =
        (cooldown_count == 8'd0);
    assign output_valid =
        input_valid && input_ready;
    assign output_first_input_channel =
        first_input_channel && output_valid;
    assign output_last_input_channel =
        last_input_channel && output_valid;
    always @(posedge clk) begin
        if (reset) begin
            cooldown_count <= 8'd0;
        end else begin
            if (cooldown_count != 8'd0) begin
                cooldown_count <=
                    cooldown_count - 8'd1;
            end
            if (
                input_valid &&
                input_ready &&
                last_input_channel
            ) begin
                cooldown_count <= REQUIRED_GAP;
            end
        end
    end
endmodule