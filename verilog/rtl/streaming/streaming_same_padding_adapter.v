`timescale 1ns / 1ps

module streaming_same_padding_adapter #(
    parameter integer IMAGE_WIDTH  = 32,
    parameter integer IMAGE_HEIGHT = 32,
    parameter integer CHANNELS     = 16,
    parameter integer FIFO_DEPTH   = IMAGE_WIDTH * IMAGE_HEIGHT * CHANNELS
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire signed [7:0]       input_value,
    input  wire [7:0]              input_x,
    input  wire [7:0]              input_y,
    input  wire [7:0]              input_channel_index,
    input  wire                    input_valid,
    output wire signed [7:0]       output_value,
    output wire [7:0]              output_padded_x,
    output wire [7:0]              output_padded_y,
    output wire [7:0]              output_channel_index,
    output wire                    output_valid,
    input  wire                    output_ready,
    output reg                     overflow_error,
    output reg                     sequence_error
);
    function integer calculate_width;
        input integer value;
        integer working_value;
        begin
            working_value = value - 1;
            calculate_width = 0;
            while (working_value > 0) begin
                calculate_width = calculate_width + 1;
                working_value = working_value >> 1;
            end
            if (calculate_width == 0) begin
                calculate_width = 1;
            end
        end
    endfunction
    localparam integer POINTER_WIDTH = calculate_width(FIFO_DEPTH);
    localparam integer COUNT_WIDTH   = calculate_width(FIFO_DEPTH + 1);
    localparam integer PADDED_WIDTH  = IMAGE_WIDTH + 2;
    localparam integer PADDED_HEIGHT = IMAGE_HEIGHT + 2;
    (* ram_style = "block" *)
    reg signed [7:0] fifo_memory [0:FIFO_DEPTH-1];
    reg signed [7:0] fifo_head_data;
    reg [POINTER_WIDTH-1:0] write_pointer;
    reg [POINTER_WIDTH-1:0] read_pointer;
    reg [COUNT_WIDTH-1:0]   fifo_count;
    reg [7:0] expected_input_x;
    reg [7:0] expected_input_y;
    reg [7:0] expected_input_channel;
    reg [7:0] padded_x;
    reg [7:0] padded_y;
    reg [7:0] padded_channel;
    wire fifo_empty;
    wire fifo_full;
    wire border_position;
    wire output_fire;
    wire fifo_dequeue;
    wire fifo_enqueue;
    assign fifo_empty = (fifo_count == {COUNT_WIDTH{1'b0}});
    assign fifo_full  = (fifo_count == FIFO_DEPTH);
    assign border_position =
        (padded_x == 8'd0) ||
        (padded_y == 8'd0) ||
        (padded_x == (PADDED_WIDTH - 1)) ||
        (padded_y == (PADDED_HEIGHT - 1));
    assign output_value =
        border_position ?
        8'sd0 :
        fifo_head_data;
    assign output_padded_x = padded_x;
    assign output_padded_y = padded_y;
    assign output_channel_index = padded_channel;
    assign output_valid =
        !reset &&
        (border_position || !fifo_empty);
    assign output_fire = output_valid && output_ready;
    assign fifo_dequeue = output_fire && !border_position;
    assign fifo_enqueue =
        input_valid &&
        (!fifo_full || fifo_dequeue);
    always @(posedge clk) begin
        if (reset) begin
            fifo_head_data <= 8'sd0;
            write_pointer <= {POINTER_WIDTH{1'b0}};
            read_pointer <= {POINTER_WIDTH{1'b0}};
            fifo_count <= {COUNT_WIDTH{1'b0}};
            expected_input_x <= 8'd0;
            expected_input_y <= 8'd0;
            expected_input_channel <= 8'd0;
            padded_x <= 8'd0;
            padded_y <= 8'd0;
            padded_channel <= 8'd0;
            overflow_error <= 1'b0;
            sequence_error <= 1'b0;
        end else begin
            if (input_valid) begin
                if (
                    (input_x != expected_input_x) ||
                    (input_y != expected_input_y) ||
                    (input_channel_index != expected_input_channel)
                ) begin
                    sequence_error <= 1'b1;
                end
                if (expected_input_channel < (CHANNELS - 1)) begin
                    expected_input_channel <=
                        expected_input_channel + 8'd1;
                end else begin
                    expected_input_channel <= 8'd0;
                    if (expected_input_x < (IMAGE_WIDTH - 1)) begin
                        expected_input_x <= expected_input_x + 8'd1;
                    end else begin
                        expected_input_x <= 8'd0;
                        if (expected_input_y < (IMAGE_HEIGHT - 1)) begin
                            expected_input_y <= expected_input_y + 8'd1;
                        end else begin
                            expected_input_y <= 8'd0;
                        end
                    end
                end
            end
            if (input_valid && fifo_full && !fifo_dequeue) begin
                overflow_error <= 1'b1;
            end
            case ({fifo_enqueue, fifo_dequeue})
                2'b10: begin
                    if (fifo_empty) begin
                        fifo_head_data <= input_value;
                    end else begin
                        fifo_memory[write_pointer] <= input_value;

                        if (write_pointer == (FIFO_DEPTH - 1)) begin
                            write_pointer <= {POINTER_WIDTH{1'b0}};
                        end else begin
                            write_pointer <= write_pointer + 1'b1;
                        end
                    end
                    fifo_count <= fifo_count + 1'b1;
                end
                2'b01: begin
                    if (fifo_count > 1) begin
                        fifo_head_data <= fifo_memory[read_pointer];

                        if (read_pointer == (FIFO_DEPTH - 1)) begin
                            read_pointer <= {POINTER_WIDTH{1'b0}};
                        end else begin
                            read_pointer <= read_pointer + 1'b1;
                        end
                    end
                    fifo_count <= fifo_count - 1'b1;
                end
                2'b11: begin
                    if (fifo_count == 1) begin
                        fifo_head_data <= input_value;
                    end else begin
                        fifo_head_data <= fifo_memory[read_pointer];
                        fifo_memory[write_pointer] <= input_value;
                        if (read_pointer == (FIFO_DEPTH - 1)) begin
                            read_pointer <= {POINTER_WIDTH{1'b0}};
                        end else begin
                            read_pointer <= read_pointer + 1'b1;
                        end
                        if (write_pointer == (FIFO_DEPTH - 1)) begin
                            write_pointer <= {POINTER_WIDTH{1'b0}};
                        end else begin
                            write_pointer <= write_pointer + 1'b1;
                        end
                    end
                    fifo_count <= fifo_count;
                end
                default: begin
                    fifo_count <= fifo_count;
                end
            endcase
            if (output_fire) begin
                if (padded_channel < (CHANNELS - 1)) begin
                    padded_channel <= padded_channel + 8'd1;
                end else begin
                    padded_channel <= 8'd0;
                    if (padded_x < (PADDED_WIDTH - 1)) begin
                        padded_x <= padded_x + 8'd1;
                    end else begin
                        padded_x <= 8'd0;
                        if (padded_y < (PADDED_HEIGHT - 1)) begin
                            padded_y <= padded_y + 8'd1;
                        end else begin
                            padded_y <= 8'd0;
                        end
                    end
                end
            end
        end
    end
    initial begin
        $display(
            "ACTIVE RTL: streaming_same_padding_adapter FRAME-SAFE FIFO V1"
        );
        if (
            (IMAGE_WIDTH < 1) ||
            (IMAGE_HEIGHT < 1) ||
            (IMAGE_WIDTH > 253) ||
            (IMAGE_HEIGHT > 253)
        ) begin
            $display(
                "ERROR: streaming_same_padding_adapter image dimensions are outside the supported 1..253 range."
            );
        end
        if ((CHANNELS < 1) || (CHANNELS > 256)) begin
            $display(
                "ERROR: streaming_same_padding_adapter CHANNELS must be in the range 1..256."
            );
        end
        if (FIFO_DEPTH < (IMAGE_WIDTH * IMAGE_HEIGHT * CHANNELS)) begin
            $display(
                "WARNING: FIFO_DEPTH is smaller than one complete unpadded input frame."
            );
        end
    end
endmodule