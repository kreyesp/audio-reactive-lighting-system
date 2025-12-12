`default_nettype none

module magnitude_smoother #(
        parameter WIDTH = 32,
        parameter NUM_SAMPLES = 8,    // better if power of two
        parameter ATTACK = 2,
        parameter DECAY = 5
    )(
        input  wire clk,
        input  wire rst,

        input  wire [WIDTH-1:0] mag_in,
        input  wire mag_in_valid,
        
        output logic [WIDTH-1:0] mag_out,
        output logic mag_out_valid
    );
    localparam SHIFT_AMOUNT_DIVISOR = $clog2(NUM_SAMPLES);
    localparam SUM_WIDTH = WIDTH + SHIFT_AMOUNT_DIVISOR;

    logic [WIDTH-1:0] mag_pipe [NUM_SAMPLES-1:0];

    logic [SUM_WIDTH-1:0] moving_sum;

    always_ff @(posedge clk) begin
        if (rst) begin
            moving_sum <= 0;
            mag_out_valid <= 0;
            mag_out <= 0;
            for (int i = 0; i < NUM_SAMPLES; i = i + 1) begin
                mag_pipe[i] <= 0;
            end
        end else begin
            if (mag_in_valid) begin
                moving_sum <= (moving_sum - mag_pipe[NUM_SAMPLES-1]) + mag_in;

                for (int i = NUM_SAMPLES-1; i > 0; i = i - 1) begin
                    mag_pipe[i] <= mag_pipe[i-1];
                end
                mag_pipe[0] <= mag_in;

                mag_out <= moving_sum >> SHIFT_AMOUNT_DIVISOR;
                mag_out_valid <= 1;
            end
        end
    end

endmodule

`default_nettype wire
