`timescale 1ns / 1ps
`default_nettype none

module frame_buffer
#(
    parameter POINTS = 512
)
(
    input wire rst,
    input wire clk,

    input wire input_valid,
    input wire signed [23:0] input_data,

    input wire read_request,
    output logic data_out_valid,
    output logic signed [23:0] audio_data_out,
    output logic frame_ready
);

    localparam ADDR_WIDTH = $clog2(POINTS);
    localparam TOTAL_DEPTH = POINTS * 2;
    localparam BRAM_LATENCY = 2;

    logic write_bank;
    logic read_bank;
    logic full_bank;

    logic [ADDR_WIDTH-1:0] write_addr;
    logic [ADDR_WIDTH-1:0] read_addr;

    logic bank_full;
    logic reading;

    logic signed [23:0] bram_read_data;
    logic data_out_valid_pipe[BRAM_LATENCY-1:0];

    xilinx_true_dual_port_read_first_1_clock_ram #(
        .RAM_WIDTH(24),
        .RAM_DEPTH(TOTAL_DEPTH)
    ) audio_bram (
        .addra({write_bank, write_addr}),
        .dina(input_data),
        .clka(clk),
        .wea(input_valid),
        .ena(1'b1),
        .rsta(rst),
        .regcea(1'b1),
        .douta(),

        .addrb({read_bank, read_addr}),
        .dinb(24'b0),
        .web(1'b0),
        .enb(1'b1),
        .rstb(rst),
        .regceb(1'b1),
        .doutb(bram_read_data)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            write_bank <= 0;
            read_bank <= 0;
            full_bank <= 0;

            write_addr <= 0;
            read_addr <= 0;

            bank_full <= 0;
            reading <= 0;
            frame_ready <= 0;

            for (int i = 0; i < BRAM_LATENCY; i++) begin
                data_out_valid_pipe[i] <= 0;
            end
        end
        else begin
            if (input_valid) begin
                write_addr <= write_addr + 1;

                if (write_addr == POINTS-1) begin
                    write_addr <= 0;
                    bank_full <= 1;
                    full_bank <= write_bank;
                    write_bank <= ~write_bank;
                end
            end

            // frame_ready: full frame available AND not reading
            frame_ready <= bank_full && !reading;

            if (!reading && bank_full && read_request) begin
                reading <= 1;
                bank_full <= 0;
                read_bank <= full_bank;
                read_addr <= 0;
                data_out_valid_pipe[0] <= 1;
            end
            else if (reading) begin
                data_out_valid_pipe[0] <= 1;

                if (read_addr == POINTS-1) begin
                    reading <= 0;
                    read_addr <= 0;
                end
                else begin
                    read_addr <= read_addr + 1;
                end
            end
            else begin
                data_out_valid_pipe[0] <= 0;
            end
            for (int i = 1; i < BRAM_LATENCY; i++) begin
                data_out_valid_pipe[i] <= data_out_valid_pipe[i-1];
            end

            audio_data_out <= bram_read_data;
            data_out_valid <= data_out_valid_pipe[BRAM_LATENCY-1];
        end
    end
endmodule

`default_nettype wire
