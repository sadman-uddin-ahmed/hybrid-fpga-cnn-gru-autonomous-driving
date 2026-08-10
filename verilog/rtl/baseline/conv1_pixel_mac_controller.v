`timescale 1ns / 1ps

module conv1_pixel_mac_controller (
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire signed [7:0]  pixel_value,
    input  wire signed [7:0]  weight_value,
    input  wire signed [31:0] bias_value,
    output reg  [1:0] input_channel_index,
    output reg  [1:0] kernel_row_index,
    output reg  [1:0] kernel_column_index,
    output reg  done,
    output wire signed [31:0] accumulator_output,
    output wire signed [7:0]  quantized_output
);
    localparam STATE_IDLE        = 3'd0;
    localparam STATE_LOAD_BIAS   = 3'd1;
    localparam STATE_MAC         = 3'd2;
    localparam STATE_NEXT_KERNEL = 3'd3;
    localparam STATE_DONE        = 3'd4;
    reg [2:0] current_state;
    reg signed [31:0] accumulator_value;
    assign accumulator_output = accumulator_value;
    relu_quantize_int8 #(
        .SCALE_MULT(1301962),
        .SCALE_SHIFT(30)
    ) conv1_quantizer (
        .accumulator_in(accumulator_value),
        .quantized_out(quantized_output)
    );
    initial begin
        current_state = STATE_IDLE;
        input_channel_index = 2'd0;
        kernel_row_index = 2'd0;
        kernel_column_index = 2'd0;
        accumulator_value = 32'sd0;
        done = 1'b0;
    end
    always @(posedge clk) begin
        if (rst) begin
            current_state <= STATE_IDLE;
            input_channel_index <= 2'd0;
            kernel_row_index <= 2'd0;
            kernel_column_index <= 2'd0;
            accumulator_value <= 32'sd0;
            done <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        input_channel_index <= 2'd0;
                        kernel_row_index <= 2'd0;
                        kernel_column_index <= 2'd0;
                        current_state <= STATE_LOAD_BIAS;
                    end
                end
                STATE_LOAD_BIAS: begin
                    accumulator_value <= bias_value;
                    current_state <= STATE_MAC;
                end
                STATE_MAC: begin
                    accumulator_value <= accumulator_value + (pixel_value * weight_value);
                    current_state <= STATE_NEXT_KERNEL;
                end
                STATE_NEXT_KERNEL: begin
                    if (kernel_column_index == 2'd2) begin
                        kernel_column_index <= 2'd0;
                        if (kernel_row_index == 2'd2) begin
                            kernel_row_index <= 2'd0;
                            if (input_channel_index == 2'd2) begin
                                current_state <= STATE_DONE;
                            end else begin
                                input_channel_index <= input_channel_index + 1'b1;
                                current_state <= STATE_MAC;
                            end
                        end else begin
                            kernel_row_index <= kernel_row_index + 1'b1;
                            current_state <= STATE_MAC;
                        end
                    end else begin
                        kernel_column_index <= kernel_column_index + 1'b1;
                        current_state <= STATE_MAC;
                    end
                end
                STATE_DONE: begin
                    done <= 1'b1;
                    // Important: After the parent controller sees done=1, this MAC controller must become reusable.
                    if (!start) begin
                        current_state <= STATE_IDLE;
                    end
                end
                default: begin
                    current_state <= STATE_IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule