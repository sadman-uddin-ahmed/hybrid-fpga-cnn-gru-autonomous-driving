`timescale 1ns / 1ps

module cnn_feature_demo_top (
    input  wire       clk,
    input  wire       reset_button,
    input  wire       start_button,
    output wire       led_done,
    output wire       led_busy,
    output wire       led_started,
    output wire       led_pass,
    output wire       led_fail,
    output wire [4:0] led_status
);
    localparam integer IMAGE_TOTAL_VALUES = 12288;
    localparam [4:0] STATE_IDLE              = 5'd0;
    localparam [4:0] STATE_CAPTURE_RESET     = 5'd1;
    localparam [4:0] STATE_LOAD_IMAGE        = 5'd2;
    localparam [4:0] STATE_LOAD_CONV1_WEIGHT = 5'd3;
    localparam [4:0] STATE_LOAD_CONV1_BIAS   = 5'd4;
    localparam [4:0] STATE_LOAD_CONV2_WEIGHT = 5'd5;
    localparam [4:0] STATE_LOAD_CONV2_BIAS   = 5'd6;
    localparam [4:0] STATE_START_CORE        = 5'd7;
    localparam [4:0] STATE_WAIT_CORE_DONE    = 5'd8;
    localparam [4:0] STATE_WAIT_CAPTURE_DONE = 5'd9;
    localparam [4:0] STATE_RESULT_HOLD       = 5'd10;
    reg clk_div2_ff = 1'b0;
    wire cnn_core_clk;
    reg [4:0] current_state;
    reg reset_button_sync_0;
    reg reset_button_sync_1;
    reg start_button_sync_0;
    reg start_button_sync_1;
    reg start_button_sync_2;
    wire reset_sync;
    wire start_button_rising_edge;
    reg core_start;
    wire core_done;
    reg started_flag;
    reg busy_flag;
    reg done_flag;
    reg pass_flag;
    reg fail_flag;
    reg [1:0] current_frame_index;
    reg [13:0] image_load_address;
    reg [8:0]  conv1_weight_load_address;
    reg [3:0]  conv1_bias_load_address;
    reg [12:0] conv2_weight_load_address;
    reg [4:0]  conv2_bias_load_address;
    reg image_memory_write_enable;
    reg conv1_weight_memory_write_enable;
    reg conv1_bias_memory_write_enable;
    reg conv2_weight_memory_write_enable;
    reg conv2_bias_memory_write_enable;
    wire signed [7:0]  image_memory_write_data;
    wire signed [7:0]  conv1_weight_memory_write_data;
    wire signed [31:0] conv1_bias_memory_write_data;
    wire signed [7:0]  conv2_weight_memory_write_data;
    wire signed [31:0] conv2_bias_memory_write_data;
    wire signed [7:0] unused_conv2_pooled_output_read_data;
    wire [12:0]       conv2_pooled_output_write_address_monitor;
    wire signed [7:0] conv2_pooled_output_write_data_monitor;
    wire              conv2_pooled_output_write_enable_monitor;
    reg temporal_capture_reset;
    reg [14:0] temporal_feature_read_address;
    wire signed [7:0] temporal_feature_read_data;
    wire [2:0]        temporal_captured_frame_count;
    wire              temporal_capture_complete;
    wire temporal_feature_parity;
    (* rom_style = "block" *)
    reg signed [7:0] image_rom_frame_0 [0:IMAGE_TOTAL_VALUES-1];
    (* rom_style = "block" *)
    reg signed [7:0] image_rom_frame_1 [0:IMAGE_TOTAL_VALUES-1];
    (* rom_style = "block" *)
    reg signed [7:0] image_rom_frame_2 [0:IMAGE_TOTAL_VALUES-1];
    (* rom_style = "block" *)
    reg signed [7:0] image_rom_frame_3 [0:IMAGE_TOTAL_VALUES-1];
    (* rom_style = "block" *)
    reg signed [7:0] conv1_weight_rom [0:431];
    (* rom_style = "distributed" *)
    reg signed [31:0] conv1_bias_rom [0:15];
    (* rom_style = "block" *)
    reg signed [7:0] conv2_weight_rom [0:4607];
    (* rom_style = "distributed" *)
    reg signed [31:0] conv2_bias_rom [0:31];
    BUFG cnn_core_clk_buf (
        .I(clk_div2_ff),
        .O(cnn_core_clk)
    );
    /*
     * Keep the divided 50 MHz clock running during reset. The controller reset is synchronised on cnn_core_clk.
     Therefore that clock must remain active while reset_button is asserted.
     */
    always @(posedge clk) begin
        clk_div2_ff <= ~clk_div2_ff;
    end
    initial begin
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_0_input.mem",
            image_rom_frame_0
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_1_input.mem",
            image_rom_frame_1
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_2_input.mem",
            image_rom_frame_2
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/temporal_inputs/sequence_000_frame_3_input.mem",
            image_rom_frame_3
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/conv1_w.mem",
            conv1_weight_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/conv1_b_int32_correct.mem",
            conv1_bias_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/conv2_w.mem",
            conv2_weight_rom
        );
        $readmemh(
            "D:/LJMU/Modules/MSc_Dissertation/Dissertation_Framework/Codes/Verilog_HDL/cnn_fpga_accelerator/data/mem/conv2_b_int32_correct.mem",
            conv2_bias_rom
        );
    end
    assign reset_sync = reset_button_sync_1;
    assign start_button_rising_edge =
        start_button_sync_1 & ~start_button_sync_2;
    assign image_memory_write_data =
        (current_frame_index == 2'd0) ?
        image_rom_frame_0[image_load_address] :
        (current_frame_index == 2'd1) ?
        image_rom_frame_1[image_load_address] :
        (current_frame_index == 2'd2) ?
        image_rom_frame_2[image_load_address] :
        image_rom_frame_3[image_load_address];
    assign conv1_weight_memory_write_data =
        conv1_weight_rom[conv1_weight_load_address];
    assign conv1_bias_memory_write_data =
        conv1_bias_rom[conv1_bias_load_address];
    assign conv2_weight_memory_write_data =
        conv2_weight_rom[conv2_weight_load_address];
    assign conv2_bias_memory_write_data =
        conv2_bias_rom[conv2_bias_load_address];
    assign temporal_feature_parity =
        ^temporal_feature_read_data;
    assign led_done    = done_flag;
    assign led_busy    = busy_flag;
    assign led_started = started_flag;
    assign led_pass    = pass_flag;
    assign led_fail    = fail_flag;
    assign led_status =
        done_flag ?
        {
            temporal_feature_read_data[3:1],
            temporal_feature_read_data[0],
            temporal_feature_parity
        } :
        current_state;
    always @(posedge cnn_core_clk) begin
        reset_button_sync_0 <= reset_button;
        reset_button_sync_1 <= reset_button_sync_0;
        start_button_sync_0 <= start_button;
        start_button_sync_1 <= start_button_sync_0;
        start_button_sync_2 <= start_button_sync_1;
    end
    cnn_feature_extractor_bram_system cnn_feature_extractor_core_inst (
        .clk(cnn_core_clk),
        .rst(reset_sync),
        .start(core_start),
        .image_memory_write_enable(
            image_memory_write_enable
        ),
        .image_memory_write_address(
            image_load_address
        ),
        .image_memory_write_data(
            image_memory_write_data
        ),
        .conv1_weight_memory_write_enable(
            conv1_weight_memory_write_enable
        ),
        .conv1_weight_memory_write_address(
            conv1_weight_load_address
        ),
        .conv1_weight_memory_write_data(
            conv1_weight_memory_write_data
        ),
        .conv1_bias_memory_write_enable(
            conv1_bias_memory_write_enable
        ),
        .conv1_bias_memory_write_address(
            conv1_bias_load_address
        ),
        .conv1_bias_memory_write_data(
            conv1_bias_memory_write_data
        ),
        .conv2_weight_memory_write_enable(
            conv2_weight_memory_write_enable
        ),
        .conv2_weight_memory_write_address(
            conv2_weight_load_address
        ),
        .conv2_weight_memory_write_data(
            conv2_weight_memory_write_data
        ),
        .conv2_bias_memory_write_enable(
            conv2_bias_memory_write_enable
        ),
        .conv2_bias_memory_write_address(
            conv2_bias_load_address
        ),
        .conv2_bias_memory_write_data(
            conv2_bias_memory_write_data
        ),
        .conv2_pooled_output_read_address(
            13'd0
        ),
        .conv2_pooled_output_read_data(
            unused_conv2_pooled_output_read_data
        ),
        .conv2_pooled_output_write_address_monitor(
            conv2_pooled_output_write_address_monitor
        ),
        .conv2_pooled_output_write_data_monitor(
            conv2_pooled_output_write_data_monitor
        ),
        .conv2_pooled_output_write_enable_monitor(
            conv2_pooled_output_write_enable_monitor
        ),
        .done(core_done)
    );
    temporal_feature_buffer temporal_feature_buffer_inst (
        .clk(cnn_core_clk),
        .rst(reset_sync),
        .capture_reset(
            temporal_capture_reset
        ),
        .feature_write_address(
            conv2_pooled_output_write_address_monitor
        ),
        .feature_write_data(
            conv2_pooled_output_write_data_monitor
        ),
        .feature_write_enable(
            conv2_pooled_output_write_enable_monitor
        ),
        .feature_read_address(
            temporal_feature_read_address
        ),
        .feature_read_data(
            temporal_feature_read_data
        ),
        .captured_frame_count(
            temporal_captured_frame_count
        ),
        .capture_complete(
            temporal_capture_complete
        )
    );
    always @(posedge cnn_core_clk) begin
        if (reset_sync) begin
            current_state <= STATE_IDLE;
            core_start <= 1'b0;
            started_flag <= 1'b0;
            busy_flag    <= 1'b0;
            done_flag    <= 1'b0;
            pass_flag    <= 1'b0;
            fail_flag    <= 1'b0;
            current_frame_index <= 2'd0;
            image_load_address        <= 14'd0;
            conv1_weight_load_address <= 9'd0;
            conv1_bias_load_address   <= 4'd0;
            conv2_weight_load_address <= 13'd0;
            conv2_bias_load_address   <= 5'd0;
            image_memory_write_enable        <= 1'b0;
            conv1_weight_memory_write_enable <= 1'b0;
            conv1_bias_memory_write_enable   <= 1'b0;
            conv2_weight_memory_write_enable <= 1'b0;
            conv2_bias_memory_write_enable   <= 1'b0;
            temporal_capture_reset        <= 1'b0;
            temporal_feature_read_address <= 15'd0;
        end else begin
            core_start <= 1'b0;
            image_memory_write_enable        <= 1'b0;
            conv1_weight_memory_write_enable <= 1'b0;
            conv1_bias_memory_write_enable   <= 1'b0;
            conv2_weight_memory_write_enable <= 1'b0;
            conv2_bias_memory_write_enable   <= 1'b0;
            temporal_capture_reset <= 1'b0;
            case (current_state)
                STATE_IDLE: begin
                    busy_flag <= 1'b0;
                    done_flag <= 1'b0;
                    pass_flag <= 1'b0;
                    fail_flag <= 1'b0;
                    current_frame_index <= 2'd0;
                    image_load_address        <= 14'd0;
                    conv1_weight_load_address <= 9'd0;
                    conv1_bias_load_address   <= 4'd0;
                    conv2_weight_load_address <= 13'd0;
                    conv2_bias_load_address   <= 5'd0;
                    temporal_feature_read_address <= 15'd0;
                    if (start_button_rising_edge) begin
                        started_flag  <= 1'b1;
                        busy_flag     <= 1'b1;
                        current_state <= STATE_CAPTURE_RESET;
                    end
                end
                STATE_CAPTURE_RESET: begin
                    busy_flag              <= 1'b1;
                    temporal_capture_reset <= 1'b1;
                    current_frame_index    <= 2'd0;
                    image_load_address     <= 14'd0;
                    temporal_feature_read_address <= 15'd0;
                    current_state <= STATE_LOAD_IMAGE;
                end
                STATE_LOAD_IMAGE: begin
                    busy_flag <= 1'b1;
                    image_memory_write_enable <= 1'b1;
                    if (image_load_address == IMAGE_TOTAL_VALUES - 1) begin
                        image_load_address <= 14'd0;
                        if (current_frame_index == 2'd0) begin
                            current_state <= STATE_LOAD_CONV1_WEIGHT;
                        end else begin
                            current_state <= STATE_START_CORE;
                        end
                    end else begin
                        image_load_address <=
                            image_load_address + 14'd1;
                    end
                end
                STATE_LOAD_CONV1_WEIGHT: begin
                    busy_flag <= 1'b1;
                    conv1_weight_memory_write_enable <= 1'b1;
                    if (conv1_weight_load_address == 9'd431) begin
                        conv1_weight_load_address <= 9'd0;
                        current_state <= STATE_LOAD_CONV1_BIAS;
                    end else begin
                        conv1_weight_load_address <=
                            conv1_weight_load_address + 9'd1;
                    end
                end
                STATE_LOAD_CONV1_BIAS: begin
                    busy_flag <= 1'b1;
                    conv1_bias_memory_write_enable <= 1'b1;
                    if (conv1_bias_load_address == 4'd15) begin
                        conv1_bias_load_address <= 4'd0;
                        current_state <= STATE_LOAD_CONV2_WEIGHT;
                    end else begin
                        conv1_bias_load_address <=
                            conv1_bias_load_address + 4'd1;
                    end
                end
                STATE_LOAD_CONV2_WEIGHT: begin
                    busy_flag <= 1'b1;
                    conv2_weight_memory_write_enable <= 1'b1;
                    if (conv2_weight_load_address == 13'd4607) begin
                        conv2_weight_load_address <= 13'd0;
                        current_state <= STATE_LOAD_CONV2_BIAS;
                    end else begin
                        conv2_weight_load_address <=
                            conv2_weight_load_address + 13'd1;
                    end
                end
                STATE_LOAD_CONV2_BIAS: begin
                    busy_flag <= 1'b1;
                    conv2_bias_memory_write_enable <= 1'b1;
                    if (conv2_bias_load_address == 5'd31) begin
                        conv2_bias_load_address <= 5'd0;
                        current_state <= STATE_START_CORE;
                    end else begin
                        conv2_bias_load_address <=
                            conv2_bias_load_address + 5'd1;
                    end
                end
                STATE_START_CORE: begin
                    busy_flag     <= 1'b1;
                    core_start    <= 1'b1;
                    current_state <= STATE_WAIT_CORE_DONE;
                end
                STATE_WAIT_CORE_DONE: begin
                    busy_flag <= 1'b1;
                    if (core_done) begin
                        if (current_frame_index == 2'd3) begin
                            current_state <= STATE_WAIT_CAPTURE_DONE;
                        end else begin
                            current_frame_index <=
                                current_frame_index + 2'd1;
                            image_load_address <= 14'd0;
                            current_state <= STATE_LOAD_IMAGE;
                        end
                    end
                end
                STATE_WAIT_CAPTURE_DONE: begin
                    busy_flag <= 1'b1;
                    if (temporal_capture_complete) begin
                        temporal_feature_read_address <= 15'd0;
                        current_state <= STATE_RESULT_HOLD;
                    end
                end
                STATE_RESULT_HOLD: begin
                    busy_flag <= 1'b0;
                    done_flag <= 1'b1;
                    temporal_feature_read_address <=
                        temporal_feature_read_address + 15'd1;
                    if (
                        temporal_capture_complete &&
                        temporal_captured_frame_count == 3'd4
                    ) begin
                        pass_flag <= 1'b1;
                        fail_flag <= 1'b0;
                    end else begin
                        pass_flag <= 1'b0;
                        fail_flag <= 1'b1;
                    end
                    if (start_button_rising_edge) begin
                        current_state <= STATE_IDLE;
                    end
                end
                default: begin
                    current_state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule
