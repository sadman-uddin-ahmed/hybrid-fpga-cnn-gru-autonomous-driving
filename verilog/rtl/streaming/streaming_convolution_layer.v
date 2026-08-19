`timescale 1ns / 1ps

module streaming_convolution_layer #(
    parameter integer IMAGE_WIDTH          = 64,
    parameter integer IMAGE_HEIGHT         = 64,
    parameter integer INPUT_CHANNELS       = 3,
    parameter integer OUTPUT_CHANNELS      = 16,
    parameter integer OUTPUT_GROUPS        = OUTPUT_CHANNELS / 4,
    parameter integer MIN_GROUP_CYCLES     = 4,
    parameter integer SCALE_MULT           = 1301962,
    parameter integer SCALE_SHIFT          = 30,
    parameter integer METADATA_FIFO_DEPTH  = 32
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    input_valid,
    output wire                    input_ready,
    input  wire signed [7:0]       input_value,
    input  wire                    weight_memory_write_enable,
    input  wire [12:0]             weight_memory_write_address,
    input  wire signed [7:0]       weight_memory_write_data,
    input  wire                    bias_memory_write_enable,
    input  wire [5:0]              bias_memory_write_address,
    input  wire signed [31:0]      bias_memory_write_data,
    output wire [7:0]              requested_channel_index,
    output wire signed [7:0]       output_value,
    output wire [7:0]              output_x,
    output wire [7:0]              output_y,
    output wire [7:0]              output_group_index,
    output wire [1:0]              output_lane_index,
    output wire [7:0]              output_channel_index,
    output wire                    output_valid,
    output wire                    requantize_busy
);
    function integer clog2;
        input integer value;
        integer working_value;
        begin
            if (value <= 2) begin
                clog2 = 1;
            end else begin
                working_value = value - 1;
                clog2 = 0;

                while (working_value > 0) begin
                    working_value = working_value >> 1;
                    clog2 = clog2 + 1;
                end
            end
        end
    endfunction
    localparam integer METADATA_ADDRESS_WIDTH =
        clog2(METADATA_FIFO_DEPTH);
    localparam integer METADATA_COUNT_WIDTH =
        clog2(METADATA_FIFO_DEPTH + 1);
    // Spatial frontend transaction.
    wire signed [7:0] frontend_output_window_value_0;
    wire signed [7:0] frontend_output_window_value_1;
    wire signed [7:0] frontend_output_window_value_2;
    wire signed [7:0] frontend_output_window_value_3;
    wire signed [7:0] frontend_output_window_value_4;
    wire signed [7:0] frontend_output_window_value_5;
    wire signed [7:0] frontend_output_window_value_6;
    wire signed [7:0] frontend_output_window_value_7;
    wire signed [7:0] frontend_output_window_value_8;
    wire [7:0] frontend_output_x;
    wire [7:0] frontend_output_y;
    wire [7:0] frontend_output_channel_index;
    wire [7:0] frontend_output_group_index;
    wire       frontend_output_first_input_channel;
    wire       frontend_output_last_input_channel;
    wire       frontend_output_valid;
    wire       frontend_output_ready;
    // Parameter-bank outputs for the four K9 lanes.
    wire signed [7:0] weight_lane_0_value_0;
    wire signed [7:0] weight_lane_0_value_1;
    wire signed [7:0] weight_lane_0_value_2;
    wire signed [7:0] weight_lane_0_value_3;
    wire signed [7:0] weight_lane_0_value_4;
    wire signed [7:0] weight_lane_0_value_5;
    wire signed [7:0] weight_lane_0_value_6;
    wire signed [7:0] weight_lane_0_value_7;
    wire signed [7:0] weight_lane_0_value_8;
    wire signed [7:0] weight_lane_1_value_0;
    wire signed [7:0] weight_lane_1_value_1;
    wire signed [7:0] weight_lane_1_value_2;
    wire signed [7:0] weight_lane_1_value_3;
    wire signed [7:0] weight_lane_1_value_4;
    wire signed [7:0] weight_lane_1_value_5;
    wire signed [7:0] weight_lane_1_value_6;
    wire signed [7:0] weight_lane_1_value_7;
    wire signed [7:0] weight_lane_1_value_8;
    wire signed [7:0] weight_lane_2_value_0;
    wire signed [7:0] weight_lane_2_value_1;
    wire signed [7:0] weight_lane_2_value_2;
    wire signed [7:0] weight_lane_2_value_3;
    wire signed [7:0] weight_lane_2_value_4;
    wire signed [7:0] weight_lane_2_value_5;
    wire signed [7:0] weight_lane_2_value_6;
    wire signed [7:0] weight_lane_2_value_7;
    wire signed [7:0] weight_lane_2_value_8;
    wire signed [7:0] weight_lane_3_value_0;
    wire signed [7:0] weight_lane_3_value_1;
    wire signed [7:0] weight_lane_3_value_2;
    wire signed [7:0] weight_lane_3_value_3;
    wire signed [7:0] weight_lane_3_value_4;
    wire signed [7:0] weight_lane_3_value_5;
    wire signed [7:0] weight_lane_3_value_6;
    wire signed [7:0] weight_lane_3_value_7;
    wire signed [7:0] weight_lane_3_value_8;
    wire signed [31:0] bias_value_0;
    wire signed [31:0] bias_value_1;
    wire signed [31:0] bias_value_2;
    wire signed [31:0] bias_value_3;
    wire                    datapath_input_valid;
    wire                    datapath_input_ready;
    wire signed [7:0]       datapath_output_value;
    wire [1:0]              datapath_output_lane_index;
    wire                    datapath_output_valid;
    // Completed-group metadata stays at the FIFO head for all four lane outputs.
    (* ram_style = "distributed" *)
    reg [7:0] metadata_x_memory [0:METADATA_FIFO_DEPTH-1];
    (* ram_style = "distributed" *)
    reg [7:0] metadata_y_memory [0:METADATA_FIFO_DEPTH-1];
    (* ram_style = "distributed" *)
    reg [7:0] metadata_group_memory [0:METADATA_FIFO_DEPTH-1];
    reg [METADATA_ADDRESS_WIDTH-1:0] metadata_write_pointer;
    reg [METADATA_ADDRESS_WIDTH-1:0] metadata_read_pointer;
    reg [METADATA_COUNT_WIDTH-1:0]   metadata_fifo_count;
    wire metadata_fifo_empty;
    wire metadata_fifo_full;
    wire metadata_available;
    wire metadata_dequeue;
    wire metadata_can_accept;
    wire metadata_enqueue;
    wire [7:0] metadata_head_x;
    wire [7:0] metadata_head_y;
    wire [7:0] metadata_head_group;
    // A group is retired only after its lane-3 output is emitted.
    assign metadata_fifo_empty =
        (metadata_fifo_count == {METADATA_COUNT_WIDTH{1'b0}});
    assign metadata_fifo_full =
        (metadata_fifo_count == METADATA_FIFO_DEPTH);
    assign metadata_available =
        !metadata_fifo_empty;
    assign metadata_dequeue =
        datapath_output_valid &&
        metadata_available &&
        (datapath_output_lane_index == 2'd3);
    assign metadata_can_accept =
        !metadata_fifo_full ||
        metadata_dequeue;
    // Backpressure follows the arithmetic input-ready signal and FIFO capacity.
    assign frontend_output_ready =
        datapath_input_ready &&
        (!frontend_output_last_input_channel ||
         metadata_can_accept);
    assign datapath_input_valid =
        frontend_output_valid &&
        (!frontend_output_last_input_channel ||
         metadata_can_accept);
    assign metadata_enqueue =
        frontend_output_valid &&
        frontend_output_ready &&
        frontend_output_last_input_channel;
    assign metadata_head_x =
        metadata_available ? metadata_x_memory[metadata_read_pointer] : 8'd0;
    assign metadata_head_y =
        metadata_available ? metadata_y_memory[metadata_read_pointer] : 8'd0;
    assign metadata_head_group =
        metadata_available ? metadata_group_memory[metadata_read_pointer] : 8'd0;
    assign output_value =
        datapath_output_value;
    assign output_x =
        metadata_head_x;
    assign output_y =
        metadata_head_y;
    assign output_group_index =
        metadata_head_group;
    assign output_lane_index =
        datapath_output_lane_index;
    assign output_channel_index =
        (metadata_head_group << 2) +
        {{6{1'b0}}, datapath_output_lane_index};
    assign output_valid =
        datapath_output_valid &&
        metadata_available;
    // Capture x, y and group when the last input channel is accepted.
    always @(posedge clk) begin
        if (reset) begin
            metadata_write_pointer <= {METADATA_ADDRESS_WIDTH{1'b0}};
            metadata_read_pointer  <= {METADATA_ADDRESS_WIDTH{1'b0}};
            metadata_fifo_count    <= {METADATA_COUNT_WIDTH{1'b0}};
        end else begin
            if (metadata_enqueue) begin
                metadata_x_memory[metadata_write_pointer] <=
                    frontend_output_x;
                metadata_y_memory[metadata_write_pointer] <=
                    frontend_output_y;
                metadata_group_memory[metadata_write_pointer] <=
                    frontend_output_group_index;
                if (
                    metadata_write_pointer ==
                    (METADATA_FIFO_DEPTH - 1)
                ) begin
                    metadata_write_pointer <= {METADATA_ADDRESS_WIDTH{1'b0}};
                end else begin
                    metadata_write_pointer <=
                        metadata_write_pointer + 1'b1;
                end
            end
            if (metadata_dequeue) begin
                if (
                    metadata_read_pointer ==
                    (METADATA_FIFO_DEPTH - 1)
                ) begin
                    metadata_read_pointer <= {METADATA_ADDRESS_WIDTH{1'b0}};
                end else begin
                    metadata_read_pointer <=
                        metadata_read_pointer + 1'b1;
                end
            end
            case ({metadata_enqueue, metadata_dequeue})
                2'b10: begin
                    metadata_fifo_count <=
                        metadata_fifo_count + 1'b1;
                end

                2'b01: begin
                    metadata_fifo_count <=
                        metadata_fifo_count - 1'b1;
                end
                default: begin
                    metadata_fifo_count <=
                        metadata_fifo_count;
                end
            endcase
        end
    end
    streaming_spatial_frontend #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .OUTPUT_GROUPS(OUTPUT_GROUPS)
    ) spatial_frontend_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .input_value(input_value),
        .requested_channel_index(
            requested_channel_index
        ),
        .output_window_value_0(
            frontend_output_window_value_0
        ),
        .output_window_value_1(
            frontend_output_window_value_1
        ),
        .output_window_value_2(
            frontend_output_window_value_2
        ),
        .output_window_value_3(
            frontend_output_window_value_3
        ),
        .output_window_value_4(
            frontend_output_window_value_4
        ),
        .output_window_value_5(
            frontend_output_window_value_5
        ),
        .output_window_value_6(
            frontend_output_window_value_6
        ),
        .output_window_value_7(
            frontend_output_window_value_7
        ),
        .output_window_value_8(
            frontend_output_window_value_8
        ),
        .output_x(frontend_output_x),
        .output_y(frontend_output_y),
        .output_channel_index(
            frontend_output_channel_index
        ),
        .output_group_index(
            frontend_output_group_index
        ),
        .output_first_input_channel(
            frontend_output_first_input_channel
        ),
        .output_last_input_channel(
            frontend_output_last_input_channel
        ),
        .output_valid(frontend_output_valid),
        .output_ready(frontend_output_ready)
    );
    streaming_convolution_parameter_bank #(
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .OUTPUT_CHANNELS(OUTPUT_CHANNELS)
    ) parameter_bank_inst (
        .clk(clk),
        .weight_memory_write_enable(
            weight_memory_write_enable
        ),
        .weight_memory_write_address(
            weight_memory_write_address
        ),
        .weight_memory_write_data(
            weight_memory_write_data
        ),
        .bias_memory_write_enable(
            bias_memory_write_enable
        ),
        .bias_memory_write_address(
            bias_memory_write_address
        ),
        .bias_memory_write_data(
            bias_memory_write_data
        ),
        .output_group_index(
            frontend_output_group_index
        ),
        .input_channel_index(
            frontend_output_channel_index
        ),
        .weight_lane_0_value_0(weight_lane_0_value_0),
        .weight_lane_0_value_1(weight_lane_0_value_1),
        .weight_lane_0_value_2(weight_lane_0_value_2),
        .weight_lane_0_value_3(weight_lane_0_value_3),
        .weight_lane_0_value_4(weight_lane_0_value_4),
        .weight_lane_0_value_5(weight_lane_0_value_5),
        .weight_lane_0_value_6(weight_lane_0_value_6),
        .weight_lane_0_value_7(weight_lane_0_value_7),
        .weight_lane_0_value_8(weight_lane_0_value_8),
        .weight_lane_1_value_0(weight_lane_1_value_0),
        .weight_lane_1_value_1(weight_lane_1_value_1),
        .weight_lane_1_value_2(weight_lane_1_value_2),
        .weight_lane_1_value_3(weight_lane_1_value_3),
        .weight_lane_1_value_4(weight_lane_1_value_4),
        .weight_lane_1_value_5(weight_lane_1_value_5),
        .weight_lane_1_value_6(weight_lane_1_value_6),
        .weight_lane_1_value_7(weight_lane_1_value_7),
        .weight_lane_1_value_8(weight_lane_1_value_8),
        .weight_lane_2_value_0(weight_lane_2_value_0),
        .weight_lane_2_value_1(weight_lane_2_value_1),
        .weight_lane_2_value_2(weight_lane_2_value_2),
        .weight_lane_2_value_3(weight_lane_2_value_3),
        .weight_lane_2_value_4(weight_lane_2_value_4),
        .weight_lane_2_value_5(weight_lane_2_value_5),
        .weight_lane_2_value_6(weight_lane_2_value_6),
        .weight_lane_2_value_7(weight_lane_2_value_7),
        .weight_lane_2_value_8(weight_lane_2_value_8),
        .weight_lane_3_value_0(weight_lane_3_value_0),
        .weight_lane_3_value_1(weight_lane_3_value_1),
        .weight_lane_3_value_2(weight_lane_3_value_2),
        .weight_lane_3_value_3(weight_lane_3_value_3),
        .weight_lane_3_value_4(weight_lane_3_value_4),
        .weight_lane_3_value_5(weight_lane_3_value_5),
        .weight_lane_3_value_6(weight_lane_3_value_6),
        .weight_lane_3_value_7(weight_lane_3_value_7),
        .weight_lane_3_value_8(weight_lane_3_value_8),
        .bias_value_0(bias_value_0),
        .bias_value_1(bias_value_1),
        .bias_value_2(bias_value_2),
        .bias_value_3(bias_value_3)
    );
    convolution_four_lane_datapath #(
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .MIN_GROUP_CYCLES(MIN_GROUP_CYCLES),
        .SCALE_MULT(SCALE_MULT),
        .SCALE_SHIFT(SCALE_SHIFT)
    ) convolution_datapath_inst (
        .clk(clk),
        .reset(reset),
        .input_valid(datapath_input_valid),
        .input_ready(datapath_input_ready),
        .first_input_channel(
            frontend_output_first_input_channel
        ),
        .last_input_channel(
            frontend_output_last_input_channel
        ),
        .input_value_0(frontend_output_window_value_0),
        .input_value_1(frontend_output_window_value_1),
        .input_value_2(frontend_output_window_value_2),
        .input_value_3(frontend_output_window_value_3),
        .input_value_4(frontend_output_window_value_4),
        .input_value_5(frontend_output_window_value_5),
        .input_value_6(frontend_output_window_value_6),
        .input_value_7(frontend_output_window_value_7),
        .input_value_8(frontend_output_window_value_8),
        .weight_lane_0_value_0(weight_lane_0_value_0),
        .weight_lane_0_value_1(weight_lane_0_value_1),
        .weight_lane_0_value_2(weight_lane_0_value_2),
        .weight_lane_0_value_3(weight_lane_0_value_3),
        .weight_lane_0_value_4(weight_lane_0_value_4),
        .weight_lane_0_value_5(weight_lane_0_value_5),
        .weight_lane_0_value_6(weight_lane_0_value_6),
        .weight_lane_0_value_7(weight_lane_0_value_7),
        .weight_lane_0_value_8(weight_lane_0_value_8),
        .weight_lane_1_value_0(weight_lane_1_value_0),
        .weight_lane_1_value_1(weight_lane_1_value_1),
        .weight_lane_1_value_2(weight_lane_1_value_2),
        .weight_lane_1_value_3(weight_lane_1_value_3),
        .weight_lane_1_value_4(weight_lane_1_value_4),
        .weight_lane_1_value_5(weight_lane_1_value_5),
        .weight_lane_1_value_6(weight_lane_1_value_6),
        .weight_lane_1_value_7(weight_lane_1_value_7),
        .weight_lane_1_value_8(weight_lane_1_value_8),
        .weight_lane_2_value_0(weight_lane_2_value_0),
        .weight_lane_2_value_1(weight_lane_2_value_1),
        .weight_lane_2_value_2(weight_lane_2_value_2),
        .weight_lane_2_value_3(weight_lane_2_value_3),
        .weight_lane_2_value_4(weight_lane_2_value_4),
        .weight_lane_2_value_5(weight_lane_2_value_5),
        .weight_lane_2_value_6(weight_lane_2_value_6),
        .weight_lane_2_value_7(weight_lane_2_value_7),
        .weight_lane_2_value_8(weight_lane_2_value_8),
        .weight_lane_3_value_0(weight_lane_3_value_0),
        .weight_lane_3_value_1(weight_lane_3_value_1),
        .weight_lane_3_value_2(weight_lane_3_value_2),
        .weight_lane_3_value_3(weight_lane_3_value_3),
        .weight_lane_3_value_4(weight_lane_3_value_4),
        .weight_lane_3_value_5(weight_lane_3_value_5),
        .weight_lane_3_value_6(weight_lane_3_value_6),
        .weight_lane_3_value_7(weight_lane_3_value_7),
        .weight_lane_3_value_8(weight_lane_3_value_8),
        .bias_value_0(bias_value_0),
        .bias_value_1(bias_value_1),
        .bias_value_2(bias_value_2),
        .bias_value_3(bias_value_3),
        .output_value(datapath_output_value),
        .output_lane_index(datapath_output_lane_index),
        .output_valid(datapath_output_valid),
        .requantize_busy(requantize_busy)
    );
    initial begin
        $display(
            "ACTIVE RTL: streaming_convolution_layer CANDIDATE-A INTEGRATION V1"
        );
    end
endmodule
