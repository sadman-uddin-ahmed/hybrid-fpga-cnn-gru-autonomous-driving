`timescale 1ns / 1ps

module cnn_feature_extractor_synth_top (
    input  wire clk,
    input  wire rst,
    input  wire start,
    output wire done
);
    cnn_feature_extractor_top cnn_core (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done)
    );
endmodule