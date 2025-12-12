`default_nettype none
module evt_counter
    #(
        parameter MAX_COUNT = 512
    )
    (
        input wire clk,
        input wire rst,
        input wire evt,
        output logic [$clog2(MAX_COUNT)+1:0] count
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            count <= 0;
        end
        else if (evt) begin
            count <= count + 1;
        end
    end
endmodule
`default_nettype wire
