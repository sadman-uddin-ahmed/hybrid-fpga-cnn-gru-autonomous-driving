`timescale 1ns / 1ps

module conv2_feature_map_controller (
    input  wire clk,
    input  wire rst,
    input  wire start,
    output reg  done
);
    localparam INPUT_CHANNELS   = 16;
    localparam INPUT_HEIGHT     = 32;
    localparam INPUT_WIDTH      = 32;
    localparam OUTPUT_CHANNELS  = 32;
    localparam OUTPUT_HEIGHT    = 32;
    localparam OUTPUT_WIDTH     = 32;
    localparam INPUT_SIZE       = 16 * 32 * 32;
    localparam WEIGHT_SIZE      = 32 * 16 * 3 * 3;
    localparam BIAS_SIZE        = 32;
    localparam OUTPUT_SIZE      = 32 * 32 * 32;
    localparam STATE_IDLE       = 4'd0;
    localparam STATE_PREPARE    = 4'd1;
    localparam STATE_START_MAC  = 4'd2;
    localparam STATE_WAIT_MAC   = 4'd3;
    localparam STATE_STORE      = 4'd4;
    localparam STATE_NEXT_PIXEL = 4'd5;
    localparam STATE_DONE       = 4'd6;
    reg [3:0] current_state;
    reg [5:0] output_channel_index;
    reg [5:0] output_row_index;
    reg [5:0] output_column_index;
    reg start_pixel_mac;
    wire pixel_mac_done;
    wire [4:0] mac_input_channel_index;
    wire [1:0] mac_kernel_row_index;
    wire [1:0] mac_kernel_column_index;
    reg signed [7:0]  selected_pixel_value;
    reg signed [7:0]  selected_weight_value;
    reg signed [31:0] selected_bias_value;
    wire signed [31:0] pixel_accumulator_output;
    wire signed [7:0]  pixel_quantized_output;
    integer input_row_index;
    integer input_column_index;
    integer input_memory_index;
    integer weight_memory_index;
    integer output_memory_index;
    reg signed [7:0]  input_memory  [0:INPUT_SIZE-1];
    reg signed [7:0]  weight_memory [0:WEIGHT_SIZE-1];
    reg signed [31:0] bias_memory   [0:BIAS_SIZE-1];
    reg signed [7:0]  conv2_output_memory [0:OUTPUT_SIZE-1];
    conv2_pixel_mac_controller pixel_mac_controller (
        .clk(clk),
        .rst(rst),
        .start(start_pixel_mac),
        .pixel_value(selected_pixel_value),
        .weight_value(selected_weight_value),
        .bias_value(selected_bias_value),
        .input_channel_index(mac_input_channel_index),
        .kernel_row_index(mac_kernel_row_index),
        .kernel_column_index(mac_kernel_column_index),
        .done(pixel_mac_done),
        .accumulator_output(pixel_accumulator_output),
        .quantized_output(pixel_quantized_output)
    );
    initial begin
        done = 1'b0;
        current_state = STATE_IDLE;
        output_channel_index = 0;
        output_row_index = 0;
        output_column_index = 0;
        start_pixel_mac = 1'b0;
        selected_pixel_value = 8'sd0;
        selected_weight_value = 8'sd0;
        selected_bias_value = 32'sd0;
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
                * 3 + kernel_row_number)
                * 3 + kernel_column_number);
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
    always @(*) begin
        input_row_index =
            output_row_index + mac_kernel_row_index - 1;
        input_column_index =
            output_column_index + mac_kernel_column_index - 1;
        if ((input_row_index >= 0) &&
            (input_row_index < INPUT_HEIGHT) &&
            (input_column_index >= 0) &&
            (input_column_index < INPUT_WIDTH)) begin

            input_memory_index =
                get_input_index(mac_input_channel_index,
                                input_row_index,
                                input_column_index);

            selected_pixel_value = input_memory[input_memory_index];
        end else begin
            selected_pixel_value = 8'sd0;
        end
        weight_memory_index =
            get_weight_index(output_channel_index,
                             mac_input_channel_index,
                             mac_kernel_row_index,
                             mac_kernel_column_index);

        selected_weight_value = weight_memory[weight_memory_index];
        selected_bias_value = bias_memory[output_channel_index];
    end
    always @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
            current_state <= STATE_IDLE;
            output_channel_index <= 0;
            output_row_index <= 0;
            output_column_index <= 0;
            start_pixel_mac <= 1'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    start_pixel_mac <= 1'b0;
                    if (start) begin
                        output_channel_index <= 0;
                        output_row_index <= 0;
                        output_column_index <= 0;
                        current_state <= STATE_PREPARE;
                    end
                end
                STATE_PREPARE: begin
                    start_pixel_mac <= 1'b0;
                    current_state <= STATE_START_MAC;
                end
                STATE_START_MAC: begin
                    start_pixel_mac <= 1'b1;
                    current_state <= STATE_WAIT_MAC;
                end
                STATE_WAIT_MAC: begin
                    start_pixel_mac <= 1'b0;
                    if (pixel_mac_done) begin
                        current_state <= STATE_STORE;
                    end
                end
                STATE_STORE: begin
                    output_memory_index =
                        get_output_index(output_channel_index,
                                         output_row_index,
                                         output_column_index);

                    conv2_output_memory[output_memory_index] <= pixel_quantized_output;

                    current_state <= STATE_NEXT_PIXEL;
                end
                STATE_NEXT_PIXEL: begin
                    if (output_column_index == OUTPUT_WIDTH - 1) begin
                        output_column_index <= 0;
                        if (output_row_index == OUTPUT_HEIGHT - 1) begin
                            output_row_index <= 0;
                            if (output_channel_index == OUTPUT_CHANNELS - 1) begin
                                current_state <= STATE_DONE;
                            end else begin
                                output_channel_index <= output_channel_index + 1'b1;
                                current_state <= STATE_PREPARE;
                            end
                        end else begin
                            output_row_index <= output_row_index + 1'b1;
                            current_state <= STATE_PREPARE;
                        end
                    end else begin
                        output_column_index <= output_column_index + 1'b1;
                        current_state <= STATE_PREPARE;
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