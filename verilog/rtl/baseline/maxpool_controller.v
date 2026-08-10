`timescale 1ns / 1ps

module maxpool_controller #(
    parameter integer INPUT_CHANNELS = 16,
    parameter integer INPUT_HEIGHT   = 64,
    parameter integer INPUT_WIDTH    = 64,
    parameter integer OUTPUT_HEIGHT  = 32,
    parameter integer OUTPUT_WIDTH   = 32,
    parameter integer INPUT_SIZE     = 16 * 64 * 64,
    parameter integer OUTPUT_SIZE    = 16 * 32 * 32
)(
    input  wire clk,
    input  wire rst,
    input  wire start,
    output reg  done
);
    localparam STATE_IDLE    = 3'd0;
    localparam STATE_COMPUTE = 3'd1;
    localparam STATE_STORE   = 3'd2;
    localparam STATE_NEXT    = 3'd3;
    localparam STATE_DONE    = 3'd4;
    reg [2:0] current_state;
    reg [5:0] channel_index;
    reg [6:0] output_row_index;
    reg [6:0] output_column_index;
    integer input_pixel_00_index;
    integer input_pixel_01_index;
    integer input_pixel_10_index;
    integer input_pixel_11_index;
    integer output_memory_index;
    reg signed [7:0] input_memory  [0:INPUT_SIZE-1];
    reg signed [7:0] output_memory [0:OUTPUT_SIZE-1];
    reg signed [7:0] pool_pixel_00;
    reg signed [7:0] pool_pixel_01;
    reg signed [7:0] pool_pixel_10;
    reg signed [7:0] pool_pixel_11;
    wire signed [7:0] pooled_pixel_output;
    maxpool2x2_int8 pool_unit (
        .pixel_00(pool_pixel_00),
        .pixel_01(pool_pixel_01),
        .pixel_10(pool_pixel_10),
        .pixel_11(pool_pixel_11),
        .pooled_out(pooled_pixel_output)
    );
    initial begin
        done = 1'b0;
        current_state = STATE_IDLE;
        channel_index = 0;
        output_row_index = 0;
        output_column_index = 0;
        pool_pixel_00 = 8'sd0;
        pool_pixel_01 = 8'sd0;
        pool_pixel_10 = 8'sd0;
        pool_pixel_11 = 8'sd0;
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
    function integer get_output_index;
        input integer channel_number;
        input integer row_number;
        input integer column_number;
        begin
            get_output_index =
                (channel_number * OUTPUT_HEIGHT * OUTPUT_WIDTH) +
                (row_number * OUTPUT_WIDTH) +
                column_number;
        end
    endfunction
    always @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
            current_state <= STATE_IDLE;
            channel_index <= 0;
            output_row_index <= 0;
            output_column_index <= 0;
            pool_pixel_00 <= 8'sd0;
            pool_pixel_01 <= 8'sd0;
            pool_pixel_10 <= 8'sd0;
            pool_pixel_11 <= 8'sd0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        channel_index <= 0;
                        output_row_index <= 0;
                        output_column_index <= 0;
                        current_state <= STATE_COMPUTE;
                    end
                end
                STATE_COMPUTE: begin
                    input_pixel_00_index =
                        get_input_index(channel_index,
                                        output_row_index * 2,
                                        output_column_index * 2);
                    input_pixel_01_index =
                        get_input_index(channel_index,
                                        output_row_index * 2,
                                        output_column_index * 2 + 1);
                    input_pixel_10_index =
                        get_input_index(channel_index,
                                        output_row_index * 2 + 1,
                                        output_column_index * 2);
                    input_pixel_11_index =
                        get_input_index(channel_index,
                                        output_row_index * 2 + 1,
                                        output_column_index * 2 + 1);
                    pool_pixel_00 <= input_memory[input_pixel_00_index];
                    pool_pixel_01 <= input_memory[input_pixel_01_index];
                    pool_pixel_10 <= input_memory[input_pixel_10_index];
                    pool_pixel_11 <= input_memory[input_pixel_11_index];
                    current_state <= STATE_STORE;
                end
                STATE_STORE: begin
                    output_memory_index =
                        get_output_index(channel_index,
                                         output_row_index,
                                         output_column_index);
                    output_memory[output_memory_index] <= pooled_pixel_output;

                    current_state <= STATE_NEXT;
                end
                STATE_NEXT: begin
                    if (output_column_index == OUTPUT_WIDTH - 1) begin
                        output_column_index <= 0;
                        if (output_row_index == OUTPUT_HEIGHT - 1) begin
                            output_row_index <= 0;
                            if (channel_index == INPUT_CHANNELS - 1) begin
                                current_state <= STATE_DONE;
                            end else begin
                                channel_index <= channel_index + 1;
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