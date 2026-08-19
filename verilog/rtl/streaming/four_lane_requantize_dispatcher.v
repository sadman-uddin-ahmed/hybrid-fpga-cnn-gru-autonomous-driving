`timescale 1ns / 1ps

module four_lane_requantize_dispatcher (
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    output wire                    input_ready,
    input  wire signed [63:0]      accumulated_sum_0,
    input  wire signed [63:0]      accumulated_sum_1,
    input  wire signed [63:0]      accumulated_sum_2,
    input  wire signed [63:0]      accumulated_sum_3,
    output reg  signed [63:0]      requantize_input_value,
    output reg  [1:0]              requantize_lane_index,
    output reg                     requantize_input_valid,
    output reg                     busy
);
    reg signed [63:0] stored_sum_0;
    reg signed [63:0] stored_sum_1;
    reg signed [63:0] stored_sum_2;
    reg signed [63:0] stored_sum_3;
    reg [1:0] current_lane_index;
    initial begin
        $display("ACTIVE RTL: four_lane_requantize_dispatcher FOUR-TO-ONE V1");
    end
    // A new group may be accepted while idle or while lane 3 of the current group is being issued.
    assign input_ready =
        !busy ||
        (busy && (current_lane_index == 2'd3));
    always @(posedge clk) begin
        if (reset) begin
            stored_sum_0          <= 64'sd0;
            stored_sum_1          <= 64'sd0;
            stored_sum_2          <= 64'sd0;
            stored_sum_3          <= 64'sd0;
            current_lane_index    <= 2'd0;
            requantize_input_value <= 64'sd0;
            requantize_lane_index  <= 2'd0;
            requantize_input_valid <= 1'b0;
            busy <= 1'b0;
        end else begin
            requantize_input_valid <= 1'b0;
            if (busy) begin
                requantize_input_valid <= 1'b1;
                requantize_lane_index  <= current_lane_index;
                case (current_lane_index)
                    2'd0: begin
                        requantize_input_value <= stored_sum_0;
                    end
                    2'd1: begin
                        requantize_input_value <= stored_sum_1;
                    end
                    2'd2: begin
                        requantize_input_value <= stored_sum_2;
                    end
                    default: begin
                        requantize_input_value <= stored_sum_3;
                    end
                endcase
                if (current_lane_index < 2'd3) begin
                    current_lane_index <=
                        current_lane_index + 2'd1;
                end else begin
                    if (input_valid) begin
                        stored_sum_0 <= accumulated_sum_0;
                        stored_sum_1 <= accumulated_sum_1;
                        stored_sum_2 <= accumulated_sum_2;
                        stored_sum_3 <= accumulated_sum_3;
                        current_lane_index <= 2'd0;
                        busy               <= 1'b1;
                    end else begin
                        current_lane_index <= 2'd0;
                        busy               <= 1'b0;
                    end
                end
            end else if (input_valid) begin
                stored_sum_0 <= accumulated_sum_0;
                stored_sum_1 <= accumulated_sum_1;
                stored_sum_2 <= accumulated_sum_2;
                stored_sum_3 <= accumulated_sum_3;
                current_lane_index <= 2'd0;
                busy               <= 1'b1;
            end
        end
    end
endmodule