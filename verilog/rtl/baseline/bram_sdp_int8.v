`timescale 1ns / 1ps

module bram_sdp_int8 #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 8
)(
    input  wire                         clk,
    input  wire                         write_enable,
    input  wire [ADDR_WIDTH-1:0]        write_address,
    input  wire signed [DATA_WIDTH-1:0] write_data,
    input  wire                         read_enable,
    input  wire [ADDR_WIDTH-1:0]        read_address,
    output reg  signed [DATA_WIDTH-1:0] read_data
);
    localparam MEMORY_DEPTH = (1 << ADDR_WIDTH);
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] memory_array [0:MEMORY_DEPTH-1];
    integer memory_initialize_index;
    initial begin
        read_data = {DATA_WIDTH{1'b0}};
        for (
            memory_initialize_index = 0;
            memory_initialize_index < MEMORY_DEPTH;
            memory_initialize_index = memory_initialize_index + 1
        ) begin
            memory_array[memory_initialize_index] = {DATA_WIDTH{1'b0}};
        end
    end
    always @(posedge clk) begin
        if (write_enable) begin
            memory_array[write_address] <= write_data;
        end
        if (read_enable) begin
            read_data <= memory_array[read_address];
        end
    end
endmodule