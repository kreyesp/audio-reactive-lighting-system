`timescale 1ns / 1ps
`default_nettype none
`define FPATH(X) `"../data/X`"

module fft_core
    #(
        parameter POINTS = 512,
        parameter DATA_WIDTH = 24,
        parameter DATA_FRAC_BITS = 16,
        parameter TWIDDLE_WIDTH = 5,
        parameter TWIDDLE_FRAC_BITS = 3,
        parameter DEBUG_LOAD = 0
    )
    (
        // system inputs
        input wire clk,
        input wire rst,

        // fft state
        input wire start_fft,
        output logic fft_busy,
        output logic fft_done,

        // sample inputs / left side
        input wire signed [DATA_WIDTH-1:0] input_data_re, input_data_im,
        input wire input_data_valid,
        output logic load_read_en,

        // fft output / right side
        input wire [STAGES-1:0] read_addr,
        output logic signed [DATA_WIDTH-1:0] read_data_re, read_data_im,

        output logic [31:0] low_magnitude, mid_magnitude, high_magnitude
    );
    // a parallelized FFT has log_2(points) number of stages
    localparam STAGES = $clog2(POINTS);
    localparam BUTTERFLIES_PER_STAGE = POINTS / 2;
    localparam TOTAL_DATA_WIDTH = DATA_WIDTH * 2;
    localparam TOTAL_TWIDDLE_WIDTH = TWIDDLE_WIDTH * 2;
    localparam NUM_TWIDDLES = POINTS / 2;
    localparam FINAL_WRITE_TO_B = (STAGES % 2 == 1);
    localparam BRAM_LATENCY = 2;
    localparam BUTTERFLY_LATENCY = 3;
    localparam TOTAL_LATENCY = BRAM_LATENCY + BUTTERFLY_LATENCY;
    localparam TWIDDLE_ADDR_SIZE = $clog2(BUTTERFLIES_PER_STAGE);

    // For the extraction, since it will be easier to just tap during the reading then read as I had it before
    localparam LOW_START = 0;
    localparam LOW_END = 5;
    localparam MID_START = 6;
    localparam MID_END = 40;
    localparam HIGH_START = 41;
    localparam HIGH_END = 100;

    // Need to switch this to it's own module, just used for simplicity here
    function automatic [STAGES-1:0] bit_reverse(input [STAGES-1:0] in);
        for (int i = 0; i < STAGES; i++) begin
            bit_reverse[i] = in[STAGES-1-i];
        end
    endfunction

    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        RUN_STAGE,
        FINISH_STAGE,
        DONE
    } fft_state;

    fft_state current_state;
    fft_state next_state;
    logic [$clog2(STAGES)-1:0] current_stage;
    logic [STAGES-1:0] sample_load_counter;
    logic [STAGES-1:0] butterfly_counter;
    logic [$clog2(TOTAL_LATENCY):0] flush_counter;
    logic active_read_bram_a;

    logic [31:0] low_acc, mid_acc, high_acc;
    logic [DATA_WIDTH+1:0] magnitude_approx_1;
    logic [DATA_WIDTH+1:0] magnitude_approx_2;

    logic add_to_low_1, add_to_mid_1, add_to_high_1;
    logic add_to_low_2, add_to_mid_2, add_to_high_2;

    assign add_to_low_1 = (addr1_pipe[TOTAL_LATENCY-1] >= LOW_START && addr1_pipe[TOTAL_LATENCY-1] <= LOW_END);
    assign add_to_mid_1 = (addr1_pipe[TOTAL_LATENCY-1] >= MID_START && addr1_pipe[TOTAL_LATENCY-1] <= MID_END);
    assign add_to_high_1 = (addr1_pipe[TOTAL_LATENCY-1] >= HIGH_START && addr1_pipe[TOTAL_LATENCY-1] <= HIGH_END);

    assign add_to_low_2 = (addr2_pipe[TOTAL_LATENCY-1] >= LOW_START && addr2_pipe[TOTAL_LATENCY-1] <= LOW_END);
    assign add_to_mid_2 = (addr2_pipe[TOTAL_LATENCY-1] >= MID_START && addr2_pipe[TOTAL_LATENCY-1] <= MID_END);
    assign add_to_high_2 = (addr2_pipe[TOTAL_LATENCY-1] >= HIGH_START && addr2_pipe[TOTAL_LATENCY-1] <= HIGH_END);

    // FFT is busy whenever we're not idle
    assign fft_busy = (current_state != IDLE);

    // NEXT STATE SELECTOR
    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (start_fft) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                if (sample_load_counter == POINTS-1) begin
                    next_state = DEBUG_LOAD ? IDLE : RUN_STAGE;
                end
            end

            RUN_STAGE: begin
                if (butterfly_counter == BUTTERFLIES_PER_STAGE-1) begin
                    next_state = FINISH_STAGE;
                end
            end
            
            FINISH_STAGE: begin
                if (flush_counter == TOTAL_LATENCY) begin
                    if (current_stage == STAGES - 1) begin
                        next_state = DONE;
                    end else begin
                        next_state = RUN_STAGE;
                    end
                end
            end

            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // STATE LOGIC
    always_ff @(posedge clk) begin
        if (rst) begin
            current_state <= IDLE;
            current_stage <= 0;
            sample_load_counter <= 0;
            active_read_bram_a <= 1;
            butterfly_counter <= 0;
            fft_done <= 0;
            load_read_en <= 0;
            flush_counter <= 0;
            low_acc <= 0;
            mid_acc <= 0;
            high_acc <= 0;
            low_magnitude <= 0;
            mid_magnitude <= 0;
            high_magnitude <= 0;
        end else begin
            load_read_en <= 0;
            current_state <= next_state;
            fft_done <= 0;

            case (current_state)
                IDLE: begin
                    sample_load_counter <= 0;
                    butterfly_counter <= 0;
                    current_stage <= 0;
                    flush_counter <= 0;
                    active_read_bram_a <= 1;
                    low_acc <= 0;
                    mid_acc <= 0;
                    high_acc <= 0;

                    if (start_fft) begin
                        load_read_en <= 1;
                    end
                end

                LOAD: begin
                    load_read_en <= 1'b1;

                    if (input_data_valid) begin
                        sample_load_counter <= sample_load_counter + 1;
                    end
                end

                RUN_STAGE: begin
                    flush_counter <= 0;

                    if (butterfly_counter < BUTTERFLIES_PER_STAGE - 1) begin
                        butterfly_counter <= butterfly_counter + 1;
                    end

                    if (current_stage == STAGES - 1 && butterfly_out_valid) begin
                        low_acc <= low_acc + (add_to_low_1 ? $unsigned(magnitude_approx_1) : 0) + (add_to_low_2 ? $unsigned(magnitude_approx_2) : 0);
                        mid_acc <= mid_acc + (add_to_mid_1 ? $unsigned(magnitude_approx_1) : 0) + (add_to_mid_2 ? $unsigned(magnitude_approx_2) : 0);
                        high_acc <= high_acc + (add_to_high_1 ? $unsigned(magnitude_approx_1) : 0) + (add_to_high_2 ? $unsigned(magnitude_approx_2) : 0);
                    end
                end

                FINISH_STAGE: begin
                    flush_counter <= flush_counter + 1;

                    if (flush_counter == TOTAL_LATENCY && current_stage < STAGES - 1) begin
                        current_stage <= current_stage + 1;
                        active_read_bram_a <= ~active_read_bram_a;
                        butterfly_counter <= 0;
                    end

                    if (current_stage == STAGES - 1 && butterfly_out_valid) begin
                        low_acc <= low_acc + (add_to_low_1 ? $unsigned(magnitude_approx_1) : 0) + (add_to_low_2 ? $unsigned(magnitude_approx_2) : 0);
                        mid_acc <= mid_acc + (add_to_mid_1 ? $unsigned(magnitude_approx_1) : 0) + (add_to_mid_2 ? $unsigned(magnitude_approx_2) : 0);
                        high_acc <= high_acc + (add_to_high_1 ? $unsigned(magnitude_approx_1) : 0) + (add_to_high_2 ? $unsigned(magnitude_approx_2) : 0);
                    end
                end

                DONE: begin
                    fft_done <= 1;
                    low_magnitude <= low_acc;
                    mid_magnitude <= mid_acc;
                    high_magnitude <= high_acc;
                end
            endcase
        end
    end

    // Addresses for twiddle and brams
    logic [STAGES-1:0] group;
    logic [STAGES-1:0] pos_in_group;
    logic [STAGES-1:0] group_start;
    logic [STAGES-1:0] addr1, addr2;
    logic [STAGES-1:0] twiddle_addr;

    always_comb begin
        group = butterfly_counter >> current_stage;
        pos_in_group = butterfly_counter & ((1 << current_stage) - 1);
        group_start = group << (current_stage + 1);

        addr1 = group_start | pos_in_group;
        addr2 = addr1 | (1 << current_stage);

        twiddle_addr = pos_in_group << (STAGES - 1 - current_stage);
    end

    // pipeline the addresses for writeback
    logic [STAGES-1:0] addr1_pipe [TOTAL_LATENCY-1:0];
    logic [STAGES-1:0] addr2_pipe [TOTAL_LATENCY-1:0];
    logic valid_pipe [TOTAL_LATENCY-1:0];
    logic active_write_bram_b_pipe [TOTAL_LATENCY-1:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i=0; i<TOTAL_LATENCY; i++) begin
                addr1_pipe[i] <= 0;
                addr2_pipe[i] <= 0;
                valid_pipe[i] <= 0;
                active_write_bram_b_pipe[i] <= 0;
            end
        end 
        else begin
            addr1_pipe[0] <= addr1;
            addr2_pipe[0] <= addr2;
            valid_pipe[0] <= (current_state == RUN_STAGE);
            active_write_bram_b_pipe[0] <= active_read_bram_a;

            for (int i = 1; i < TOTAL_LATENCY; i++) begin
                addr1_pipe[i] <= addr1_pipe[i-1];
                addr2_pipe[i] <= addr2_pipe[i-1];
                valid_pipe[i] <= valid_pipe[i-1];
                active_write_bram_b_pipe[i] <= active_write_bram_b_pipe[i-1];
            end
        end
    end

    // TWIDDLE ROM
    logic [TOTAL_TWIDDLE_WIDTH-1:0] twiddle_rom_out_packed;

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(TOTAL_TWIDDLE_WIDTH),
        .RAM_DEPTH(NUM_TWIDDLES),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE(`FPATH(twiddle_rom.mem))
    ) twiddle_rom (
        .addra(twiddle_addr),
        .dina(0),
        .clka(clk),
        .wea(0),
        .ena(1),
        .rsta(rst),
        .regcea(1),
        .douta(twiddle_rom_out_packed)
    );

    logic butterfly_in_valid;
    assign butterfly_in_valid = valid_pipe[BRAM_LATENCY-1];

    // BRAM signals
    logic [STAGES-1:0] bram_a_addr_1, bram_a_addr_2;
    logic [STAGES-1:0] bram_b_addr_1, bram_b_addr_2;
    logic [TOTAL_DATA_WIDTH-1:0] bram_a_rd_1, bram_a_rd_2;
    logic [TOTAL_DATA_WIDTH-1:0] bram_b_rd_1, bram_b_rd_2;
    logic [TOTAL_DATA_WIDTH-1:0] bram_a_wd_1, bram_a_wd_2;
    logic [TOTAL_DATA_WIDTH-1:0] bram_b_wd_1, bram_b_wd_2;
    logic bram_a_we_1, bram_a_we_2;
    logic bram_b_we_1, bram_b_we_2;

    // BRAM Address Selector
    always_comb begin
        bram_a_addr_1 = 0;
        bram_a_addr_2 = 0;
        bram_b_addr_1 = 0;
        bram_b_addr_2 = 0;

        case (current_state)
            LOAD: begin
                bram_a_addr_1 = bit_reverse(sample_load_counter);
            end

            RUN_STAGE: begin
                if (active_read_bram_a) begin
                    bram_a_addr_1 = addr1;
                    bram_a_addr_2 = addr2;

                    bram_b_addr_1 = addr1_pipe[TOTAL_LATENCY-1];
                    bram_b_addr_2 = addr2_pipe[TOTAL_LATENCY-1];
                end else begin
                    bram_b_addr_1 = addr1;
                    bram_b_addr_2 = addr2;

                    bram_a_addr_1 = addr1_pipe[TOTAL_LATENCY-1];
                    bram_a_addr_2 = addr2_pipe[TOTAL_LATENCY-1];
                end
            end

            FINISH_STAGE: begin
                if (active_write_bram_b_pipe[TOTAL_LATENCY-1]) begin
                    bram_b_addr_1 = addr1_pipe[TOTAL_LATENCY-1];
                    bram_b_addr_2 = addr2_pipe[TOTAL_LATENCY-1];
                end else begin
                    bram_a_addr_1 = addr1_pipe[TOTAL_LATENCY-1];
                    bram_a_addr_2 = addr2_pipe[TOTAL_LATENCY-1];
                end
            end

            IDLE, DONE: begin
                if (!FINAL_WRITE_TO_B || DEBUG_LOAD) begin
                    bram_a_addr_1 = read_addr;
                end else begin
                    bram_b_addr_1 = read_addr;
                end
            end
        endcase
    end

    // BRAM A
    xilinx_true_dual_port_read_first_2_clock_ram
    #(
        .RAM_WIDTH(TOTAL_DATA_WIDTH),
        .RAM_DEPTH(POINTS)
    ) bram_a(
        .addra(bram_a_addr_1),
        .dina(bram_a_wd_1),
        .clka(clk),
        .wea(bram_a_we_1),
        .ena(1'b1),
        .rsta(rst),
        .regcea(1'b1),
        .douta(bram_a_rd_1),
        .addrb(bram_a_addr_2),
        .dinb(bram_a_wd_2),
        .clkb(clk),
        .web(bram_a_we_2),
        .enb(1'b1),
        .rstb(rst),
        .regceb(1'b1),
        .doutb(bram_a_rd_2)
    );

    // BRAM B
    xilinx_true_dual_port_read_first_2_clock_ram
    #(
        .RAM_WIDTH(TOTAL_DATA_WIDTH),
        .RAM_DEPTH(POINTS)
    ) bram_b(
        .addra(bram_b_addr_1),
        .dina(bram_b_wd_1),
        .clka(clk),
        .wea(bram_b_we_1),
        .ena(1'b1),
        .rsta(rst),
        .regcea(1'b1),
        .douta(bram_b_rd_1),
        .addrb(bram_b_addr_2),
        .dinb(bram_b_wd_2),
        .clkb(clk),
        .web(bram_b_we_2),
        .enb(1'b1),
        .rstb(rst),
        .regceb(1'b1),
        .doutb(bram_b_rd_2)
    );

    // Butterfly module inputs
    logic signed [DATA_WIDTH-1:0] input_1_re, input_1_im;
    logic signed [DATA_WIDTH-1:0] input_2_re, input_2_im;
    logic signed [TWIDDLE_WIDTH-1:0] twiddle_re, twiddle_im;

    // Butterfly module outputs
    logic butterfly_out_valid;
    logic signed [DATA_WIDTH-1:0] output_1_re, output_1_im;
    logic signed [DATA_WIDTH-1:0] output_2_re, output_2_im;

    // Sets inputs based on which bram is actively being read (use delayed signal!)
    always_comb begin
        twiddle_re = twiddle_rom_out_packed[TOTAL_TWIDDLE_WIDTH-1:TWIDDLE_WIDTH];
        twiddle_im = twiddle_rom_out_packed[TWIDDLE_WIDTH-1:0];

        if (active_write_bram_b_pipe[BRAM_LATENCY-1]) begin
            input_1_re = bram_a_rd_1[TOTAL_DATA_WIDTH-1:DATA_WIDTH];
            input_1_im = bram_a_rd_1[DATA_WIDTH-1:0];

            input_2_re = bram_a_rd_2[TOTAL_DATA_WIDTH-1:DATA_WIDTH];
            input_2_im = bram_a_rd_2[DATA_WIDTH-1:0];
        end else begin
            input_1_re = bram_b_rd_1[TOTAL_DATA_WIDTH-1:DATA_WIDTH];
            input_1_im = bram_b_rd_1[DATA_WIDTH-1:0];

            input_2_re = bram_b_rd_2[TOTAL_DATA_WIDTH-1:DATA_WIDTH];
            input_2_im = bram_b_rd_2[DATA_WIDTH-1:0];
        end
    end

    butterfly #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_FRAC_BITS(DATA_FRAC_BITS),
        .TWIDDLE_WIDTH(TWIDDLE_WIDTH),
        .TWIDDLE_FRAC_BITS(TWIDDLE_FRAC_BITS)
    ) butterfly_inst (
        .clk(clk),
        .rst(rst),
        .data_in_valid(butterfly_in_valid),
        .input_1_re(input_1_re),
        .input_1_im(input_1_im),
        .input_2_re(input_2_re),
        .input_2_im(input_2_im),
        .data_out_valid(butterfly_out_valid),
        .output_1_re(output_1_re),
        .output_1_im(output_1_im),
        .output_2_re(output_2_re),
        .output_2_im(output_2_im),
        .twiddle_re(twiddle_re),
        .twiddle_im(twiddle_im)
    );

    // sets writeback based on which is the read and write
    always_comb begin
        bram_a_we_1 = 0;
        bram_a_we_2 = 0;
        bram_b_we_1 = 0;
        bram_b_we_2 = 0;

        bram_a_wd_1 = 0;
        bram_a_wd_2 = 0;
        bram_b_wd_1 = 0;
        bram_b_wd_2 = 0;

        if (current_state == LOAD && input_data_valid && load_read_en) begin
            bram_a_we_1 = 1;
            bram_a_wd_1 = {input_data_re, input_data_im};
        end
        else if ((current_state == RUN_STAGE || current_state == FINISH_STAGE) && valid_pipe[TOTAL_LATENCY-1]) begin
            if (active_write_bram_b_pipe[TOTAL_LATENCY-1]) begin
                bram_b_we_1 = 1;
                bram_b_we_2 = 1;

                bram_b_wd_1 = {output_1_re, output_1_im};
                bram_b_wd_2 = {output_2_re, output_2_im};
            end else begin
                bram_a_we_1 = 1;
                bram_a_we_2 = 1;

                bram_a_wd_1 = {output_1_re, output_1_im};
                bram_a_wd_2 = {output_2_re, output_2_im};
            end
        end
    end

    logic [DATA_WIDTH-1:0] abs_re_1, abs_im_1, abs_re_2, abs_im_2;

    always_comb begin
        abs_re_1 = (output_1_re[DATA_WIDTH-1]) ? (~output_1_re + 1) : output_1_re;
        abs_im_1 = (output_1_im[DATA_WIDTH-1]) ? (~output_1_im + 1) : output_1_im;
        abs_re_2 = (output_2_re[DATA_WIDTH-1]) ? (~output_2_re + 1) : output_2_re;
        abs_im_2 = (output_2_im[DATA_WIDTH-1]) ? (~output_2_im + 1) : output_2_im;
        
        magnitude_approx_1 = {1'b0, abs_re_1} + {1'b0, abs_im_1};
        magnitude_approx_2 = {1'b0, abs_re_2} + {1'b0, abs_im_2};
    end

    always_comb begin
        if (!FINAL_WRITE_TO_B || DEBUG_LOAD) begin
            read_data_re = bram_a_rd_1[TOTAL_DATA_WIDTH-1:DATA_WIDTH];
            read_data_im = bram_a_rd_1[DATA_WIDTH-1:0];
        end else begin
            read_data_re = bram_b_rd_1[TOTAL_DATA_WIDTH-1:DATA_WIDTH];
            read_data_im = bram_b_rd_1[DATA_WIDTH-1:0];
        end
    end
endmodule