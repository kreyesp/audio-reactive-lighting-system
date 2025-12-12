`timescale 1ns / 1ps
`default_nettype none

module split_even
    #(
        parameter SIZE = 4
    )
    (
        input wire clk,
        input wire rst,
        input wire [32:0] data [SIZE-1:0],
        output logic [32:0] evens [half_size-1:0],
        output logic [32:0] odds [half_size-1:0]
    );
    localparam half_size = SIZE / 2;

    always_comb begin
        for (int i = 0; i < SIZE; i = i + 1) begin
            if (i[0]) begin
                odds[i >> 1] = data[i];
            end else begin
                evens[i >> 1] = data[i];
            end
        end
    end


endmodule
