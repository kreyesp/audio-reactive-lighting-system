`default_nettype none
module butterfly
    #(
        parameter DATA_WIDTH = 24,
        parameter DATA_FRAC_BITS = 16,

        parameter TWIDDLE_WIDTH = 5,
        parameter TWIDDLE_FRAC_BITS = 3
    )
    (
        // system inputs
        input wire clk,
        input wire rst,
        input wire data_in_valid,

        // inputs 1 and 2
        input wire signed [DATA_WIDTH-1:0] input_1_re, input_1_im,
        input wire signed [DATA_WIDTH-1:0] input_2_re, input_2_im,

        // twiddle factor
        input wire signed [TWIDDLE_WIDTH-1:0] twiddle_re, twiddle_im,

        // outputs
        output logic signed [DATA_WIDTH-1:0] output_1_re, output_1_im,
        output logic signed [DATA_WIDTH-1:0] output_2_re, output_2_im,
        output logic data_out_valid
    );
    localparam DATA_INT_BITS = DATA_WIDTH - DATA_FRAC_BITS;
    localparam TWIDDLE_INT_BITS = TWIDDLE_WIDTH - TWIDDLE_FRAC_BITS;

    localparam signed [DATA_WIDTH-1:0] MAX_VALUE = (2**(DATA_WIDTH-1)) - 1;
    localparam signed [DATA_WIDTH-1:0] MIN_VALUE = -(2**(DATA_WIDTH-1));

    localparam PRODUCT_WIDTH = DATA_WIDTH + TWIDDLE_WIDTH;

    (* use_dsp = "yes" *) logic signed [PRODUCT_WIDTH-1:0] multiplication_re, multiplication_im;
    logic signed [DATA_WIDTH-1:0] input_1_re_pipe, input_1_im_pipe;
    logic multiply_out_valid;
    logic signed [DATA_WIDTH+2:0] scaled_output_re, scaled_output_im;
    logic signed [DATA_WIDTH+2:0] final_output_1_re, final_output_1_im, final_output_2_re, final_output_2_im;
    logic add_out_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            multiplication_re <= 0;
            multiplication_im <= 0;
            input_1_re_pipe <= 0;
            input_1_im_pipe <= 0;
            multiply_out_valid <= 0;
        end else begin
            if (data_in_valid) begin
                multiplication_re <= ((input_2_re * twiddle_re) - (input_2_im * twiddle_im)) >>> TWIDDLE_FRAC_BITS;
                multiplication_im <= ((input_2_re * twiddle_im) + (input_2_im * twiddle_re)) >>> TWIDDLE_FRAC_BITS;
                input_1_re_pipe <= input_1_re;
                input_1_im_pipe <= input_1_im;
                multiply_out_valid <= 1;
            end else begin
                multiply_out_valid <= 0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
                final_output_1_re <= 0;
                final_output_1_im <= 0;
                final_output_2_re <= 0;
                final_output_2_im <= 0;
                add_out_valid <= 0;
        end else begin
            if (multiply_out_valid) begin
                final_output_1_re <= $signed(input_1_re_pipe) + multiplication_re;
                final_output_1_im <= $signed(input_1_im_pipe) + multiplication_im;

                final_output_2_re <= $signed(input_1_re_pipe) - multiplication_re;
                final_output_2_im <= $signed(input_1_im_pipe) - multiplication_im;

                add_out_valid <= 1;
            end else begin
                add_out_valid <= 0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            output_1_re <= 0;
            output_1_im <= 0;
            output_2_re <= 0;
            output_2_im <= 0;
            data_out_valid <= 0;
        end else begin
            if (add_out_valid) begin
                output_1_re <= (final_output_1_re > MAX_VALUE) ? MAX_VALUE : (((final_output_1_re < MIN_VALUE) ? MIN_VALUE : final_output_1_re[DATA_WIDTH-1:0]));
                output_1_im <= (final_output_1_im > MAX_VALUE) ? MAX_VALUE : (((final_output_1_im < MIN_VALUE) ? MIN_VALUE : final_output_1_im[DATA_WIDTH-1:0]));
                output_2_re <= (final_output_2_re > MAX_VALUE) ? MAX_VALUE : (((final_output_2_re < MIN_VALUE) ? MIN_VALUE : final_output_2_re[DATA_WIDTH-1:0]));
                output_2_im <= (final_output_2_im > MAX_VALUE) ? MAX_VALUE : (((final_output_2_im < MIN_VALUE) ? MIN_VALUE : final_output_2_im[DATA_WIDTH-1:0]));
                data_out_valid <= 1;
            end else begin
                data_out_valid <= 0;
            end
        end
    end
endmodule

`default_nettype wire