`timescale 1ns / 1ps

module conv2_controller_basic (
    input  wire clk,
    input  wire rst,
    input  wire start,
    output reg  done
);
    localparam INPUT_CHANNELS    = 16;
    localparam INPUT_HEIGHT      = 32;
    localparam INPUT_WIDTH       = 32;
    localparam OUTPUT_CHANNELS   = 32;
    localparam KERNEL_SIZE       = 3;
    localparam OUTPUT_HEIGHT     = 32;
    localparam OUTPUT_WIDTH      = 32;
    localparam INPUT_SIZE        = 16 * 32 * 32;
    localparam WEIGHT_SIZE       = 32 * 16 * 3 * 3;
    localparam BIAS_SIZE         = 32;
    localparam CONV_OUTPUT_SIZE  = 32 * 32 * 32;
    localparam STATE_IDLE        = 3'd0;
    localparam STATE_COMPUTE     = 3'd1;
    localparam STATE_STORE       = 3'd2;
    localparam STATE_NEXT        = 3'd3;
    localparam STATE_DONE        = 3'd4;
    reg [2:0] current_state;
    reg [5:0] output_channel_index;
    reg [5:0] output_row_index;
    reg [5:0] output_column_index;
    integer input_channel_index;
    integer kernel_row_index;
    integer kernel_column_index;
    integer input_row_index;
    integer input_column_index;
    integer input_memory_index;
    integer weight_memory_index;
    integer output_memory_index;
    reg signed [31:0] accumulator_value;
    reg signed [7:0]  input_memory  [0:INPUT_SIZE-1];
    reg signed [7:0]  weight_memory [0:WEIGHT_SIZE-1];
    reg signed [31:0] bias_memory   [0:BIAS_SIZE-1];
    reg signed [7:0]  conv_output_memory [0:CONV_OUTPUT_SIZE-1];
    wire signed [7:0] quantized_pixel_value;
    relu_quantize_int8 #(
        .SCALE_MULT(1516810),
        .SCALE_SHIFT(30)
    ) conv2_quantizer (
        .accumulator_in(accumulator_value),
        .quantized_out(quantized_pixel_value)
    );
    initial begin
        done = 1'b0;
        current_state = STATE_IDLE;
        output_channel_index = 0;
        output_row_index = 0;
        output_column_index = 0;
        accumulator_value = 0;
    end
    function integer get_input_index;
        input integer channel_number;
        input integer row_number;
        input integer column_number;
        begin
            get_input_index =
                (channel_number * INPUT_HEIGHT * INPUT_WIDTH) +
                (row_number * INPUT_WIDTH) +
                column_number;
        end
    endfunction
    function integer get_weight_index;
        input integer output_channel_number;
        input integer input_channel_number;
        input integer kernel_row_number;
        input integer kernel_column_number;
        begin
            get_weight_index =
                (((output_channel_number * INPUT_CHANNELS + input_channel_number)
                * KERNEL_SIZE + kernel_row_number)
                * KERNEL_SIZE + kernel_column_number);
        end
    endfunction
    function integer get_output_index;
        input integer output_channel_number;
        input integer row_number;
        input integer column_number;
        begin
            get_output_index =
                (output_channel_number * OUTPUT_HEIGHT * OUTPUT_WIDTH) +
                (row_number * OUTPUT_WIDTH) +
                column_number;
        end
    endfunction
    always @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
            current_state <= STATE_IDLE;
            output_channel_index <= 0;
            output_row_index <= 0;
            output_column_index <= 0;
            accumulator_value <= 0;
        end else begin
            case (current_state)

                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        output_channel_index <= 0;
                        output_row_index <= 0;
                        output_column_index <= 0;
                        current_state <= STATE_COMPUTE;
                    end
                end
                STATE_COMPUTE: begin
                    accumulator_value = bias_memory[output_channel_index];
                    for (input_channel_index = 0;
                         input_channel_index < INPUT_CHANNELS;
                         input_channel_index = input_channel_index + 1) begin
                        for (kernel_row_index = 0;
                             kernel_row_index < KERNEL_SIZE;
                             kernel_row_index = kernel_row_index + 1) begin
                            for (kernel_column_index = 0;
                                 kernel_column_index < KERNEL_SIZE;
                                 kernel_column_index = kernel_column_index + 1) begin
                                input_row_index = output_row_index + kernel_row_index - 1;
                                input_column_index = output_column_index + kernel_column_index - 1;
                                if ((input_row_index >= 0) &&
                                    (input_row_index < INPUT_HEIGHT) &&
                                    (input_column_index >= 0) &&
                                    (input_column_index < INPUT_WIDTH)) begin
                                    input_memory_index =
                                        get_input_index(input_channel_index,
                                                        input_row_index,
                                                        input_column_index);
                                    weight_memory_index =
                                        get_weight_index(output_channel_index,
                                                         input_channel_index,
                                                         kernel_row_index,
                                                         kernel_column_index);
                                    accumulator_value =
                                        accumulator_value +
                                        (input_memory[input_memory_index] *
                                         weight_memory[weight_memory_index]);
                                end
                            end
                        end
                    end
                    current_state <= STATE_STORE;
                end
                STATE_STORE: begin
                    output_memory_index =
                        get_output_index(output_channel_index,
                                         output_row_index,
                                         output_column_index);
                    conv_output_memory[output_memory_index] <= quantized_pixel_value;
                    current_state <= STATE_NEXT;
                end
                STATE_NEXT: begin
                    if (output_column_index == OUTPUT_WIDTH - 1) begin
                        output_column_index <= 0;

                        if (output_row_index == OUTPUT_HEIGHT - 1) begin
                            output_row_index <= 0;
                            if (output_channel_index == OUTPUT_CHANNELS - 1) begin
                                current_state <= STATE_DONE;
                            end else begin
                                output_channel_index <= output_channel_index + 1;
                                current_state <= STATE_COMPUTE;
                            end
                        end else begin
                            output_row_index <= output_row_index + 1;
                            current_state <= STATE_COMPUTE;
                        end
                    end else begin
                        output_column_index <= output_column_index + 1;
                        current_state <= STATE_COMPUTE;
                    end
                end
                STATE_DONE: begin
                    done <= 1'b1;
                    current_state <= STATE_DONE;
                end
                default: begin
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule