`timescale 1ns / 1ps

module temporal_feature_buffer (
    input  wire              clk,
    input  wire              rst,
    input  wire              capture_reset,
    input  wire [12:0]       feature_write_address,
    input  wire signed [7:0] feature_write_data,
    input  wire              feature_write_enable,
    input  wire [14:0]       feature_read_address,
    output reg  signed [7:0] feature_read_data,
    output reg  [2:0]        captured_frame_count,
    output reg               capture_complete
);
    localparam integer FEATURE_VALUES_PER_FRAME = 8192;
    localparam integer TOTAL_FRAME_COUNT        = 4;
    localparam integer TOTAL_BUFFER_VALUES      = 32768;
    (* ram_style = "block" *)
    reg signed [7:0] temporal_feature_memory [0:TOTAL_BUFFER_VALUES-1];
    reg [1:0] current_frame_index;
    always @(posedge clk) begin
        if (rst) begin
            current_frame_index  <= 2'd0;
            captured_frame_count <= 3'd0;
            capture_complete     <= 1'b0;
            feature_read_data    <= 8'sd0;
        end else begin
            feature_read_data <= temporal_feature_memory[
                feature_read_address
            ];
            if (capture_reset) begin
                current_frame_index  <= 2'd0;
                captured_frame_count <= 3'd0;
                capture_complete     <= 1'b0;
            end else if (
                feature_write_enable &&
                !capture_complete
            ) begin
                temporal_feature_memory[
                    {current_frame_index, feature_write_address}
                ] <= feature_write_data;
                if (
                    feature_write_address ==
                    FEATURE_VALUES_PER_FRAME - 1
                ) begin
                    if (
                        current_frame_index ==
                        TOTAL_FRAME_COUNT - 1
                    ) begin
                        captured_frame_count <= TOTAL_FRAME_COUNT;
                        capture_complete     <= 1'b1;
                    end else begin
                        current_frame_index  <= current_frame_index + 2'd1;
                        captured_frame_count <=
                            captured_frame_count + 3'd1;
                    end
                end
            end
        end
    end
endmodule