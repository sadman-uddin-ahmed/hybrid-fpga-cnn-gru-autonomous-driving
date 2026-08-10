`timescale 1ns / 1ps

module conv2_relu_pool_model (
    input  wire clk,
    input  wire rst,
    input  wire start,
    output reg  done
);
    // Conv2 dimensions(
    // Input  : 16 x 32 x 32, Weight : 32 x 16 x 3 x 3, Output : 32 x 16 x 16 after Conv + ReLU + MaxPool)
    localparam IN_C   = 16;
    localparam IN_H   = 32;
    localparam IN_W   = 32;
    localparam OUT_C  = 32;
    localparam K      = 3;
    localparam CONV_H = 32;
    localparam CONV_W = 32;
    localparam POOL_H = 16;
    localparam POOL_W = 16;
    localparam IN_SIZE     = 16 * 32 * 32;       // 16384
    localparam W_SIZE      = 32 * 16 * 3 * 3;    // 4608
    localparam B_SIZE      = 32;
    localparam OUT_SIZE    = 32 * 16 * 16;       // 8192
    // scale_acc_to_out = 0.0014126397121580797
    // Q30 multiplier = round(scale * 2^30) = 1516810
    localparam integer SCALE_MULT  = 1516810;
    localparam integer SCALE_SHIFT = 30;
    // Memories loaded by testbench
    reg signed [7:0]  in_mem   [0:IN_SIZE-1];
    reg signed [7:0]  w_mem    [0:W_SIZE-1];
    reg signed [31:0] b_mem    [0:B_SIZE-1];
    reg signed [7:0]  out_mem  [0:OUT_SIZE-1];
    // Internal full-resolution quantized Conv2 output before pooling
    reg signed [7:0] conv_relu_q [0:OUT_C*CONV_H*CONV_W-1];
    integer oc, ic, r, c, kr, kc;
    integer rr, cc;
    integer in_idx, w_idx, conv_idx, out_idx;
    integer pr, pc;
    integer acc;
    integer scaled;
    integer max_val;
    reg signed [63:0] product;
    // Initial value to avoid red/unknown waveform at time 0
    initial begin
        done = 1'b0;
    end
    // Index functions
    // CHW flattened C-order
    function integer IN_INDEX;
        input integer ch;
        input integer row;
        input integer col;
        begin
            IN_INDEX = (ch * IN_H * IN_W) + (row * IN_W) + col;
        end
    endfunction
    function integer W_INDEX;
        input integer out_ch;
        input integer in_ch;
        input integer krow;
        input integer kcol;
        begin
            W_INDEX = (((out_ch * IN_C + in_ch) * K + krow) * K + kcol);
        end
    endfunction
    function integer CONV_INDEX;
        input integer ch;
        input integer row;
        input integer col;
        begin
            CONV_INDEX = (ch * CONV_H * CONV_W) + (row * CONV_W) + col;
        end
    endfunction
    function integer OUT_INDEX;
        input integer ch;
        input integer row;
        input integer col;
        begin
            OUT_INDEX = (ch * POOL_H * POOL_W) + (row * POOL_W) + col;
        end
    endfunction
    // Main bit-true Conv2 -> ReLU -> Quantize -> MaxPool model
    always @(posedge clk) begin
        if (rst) begin
            done <= 1'b0;
        end else begin
            if (start) begin
                done <= 1'b0;
                // 1. Conv2 + Bias + ReLU + Quantization
                for (oc = 0; oc < OUT_C; oc = oc + 1) begin
                    for (r = 0; r < CONV_H; r = r + 1) begin
                        for (c = 0; c < CONV_W; c = c + 1) begin
                            acc = b_mem[oc];
                            for (ic = 0; ic < IN_C; ic = ic + 1) begin
                                for (kr = 0; kr < K; kr = kr + 1) begin
                                    for (kc = 0; kc < K; kc = kc + 1) begin
                                        rr = r + kr - 1;
                                        cc = c + kc - 1;
                                        // zero padding
                                        if ((rr >= 0) && (rr < IN_H) &&
                                            (cc >= 0) && (cc < IN_W)) begin
                                            in_idx = IN_INDEX(ic, rr, cc);
                                            w_idx  = W_INDEX(oc, ic, kr, kc);
                                            acc = acc + (in_mem[in_idx] * w_mem[w_idx]);
                                        end
                                    end
                                end
                            end
                            // ReLU before output quantization
                            if (acc < 0) begin
                                acc = 0;
                            end
                            // Fixed-point scale:
                            // scaled = round(acc * SCALE_MULT / 2^SCALE_SHIFT)
                            product = acc;
                            product = product * SCALE_MULT;
                            scaled  = (product + (64'sd1 << (SCALE_SHIFT-1))) >>> SCALE_SHIFT;
                            // Saturate to signed int8 range
                            if (scaled > 127) begin
                                scaled = 127;
                            end else if (scaled < -128) begin
                                scaled = -128;
                            end
                            conv_idx = CONV_INDEX(oc, r, c);
                            conv_relu_q[conv_idx] = scaled[7:0];
                        end
                    end
                end
                // 2. MaxPool 2x2, stride 2
                for (oc = 0; oc < OUT_C; oc = oc + 1) begin
                    for (pr = 0; pr < POOL_H; pr = pr + 1) begin
                        for (pc = 0; pc < POOL_W; pc = pc + 1) begin
                            max_val = conv_relu_q[CONV_INDEX(oc, pr*2,     pc*2)];
                            if (conv_relu_q[CONV_INDEX(oc, pr*2,     pc*2 + 1)] > max_val)
                                max_val = conv_relu_q[CONV_INDEX(oc, pr*2,     pc*2 + 1)];
                            if (conv_relu_q[CONV_INDEX(oc, pr*2 + 1, pc*2)] > max_val)
                                max_val = conv_relu_q[CONV_INDEX(oc, pr*2 + 1, pc*2)];
                            if (conv_relu_q[CONV_INDEX(oc, pr*2 + 1, pc*2 + 1)] > max_val)
                                max_val = conv_relu_q[CONV_INDEX(oc, pr*2 + 1, pc*2 + 1)];
                            out_idx = OUT_INDEX(oc, pr, pc);
                            out_mem[out_idx] = max_val[7:0];
                        end
                    end
                end
                done <= 1'b1;
            end
        end
    end
endmodule