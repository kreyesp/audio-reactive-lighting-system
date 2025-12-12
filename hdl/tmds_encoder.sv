`timescale 1ns / 1ps
`default_nettype none

module tmds_encoder(
        input wire clk,
        input wire rst,
        input wire [7:0] video_data,  // video data (red, green or blue)
        input wire [1:0] control,   //for blue set to {vs,hs}, else will be 0
        input wire video_enable,    //choose between control (0) or video (1)
        output logic [9:0] tmds
    );
    logic [8:0] q_m;
    logic [4:0] tally;

    tm_choice mtm(
        .d(video_data),
        .q_m(q_m)
    );

  //your code here.
  logic [4:0] amount_of_ones;
  logic [4:0] amount_of_zeros;
  assign amount_of_ones =q_m[0]+q_m[1]+q_m[2]+q_m[3]+q_m[4]+q_m[5]+q_m[6]+q_m[7];
  assign amount_of_zeros = 8-amount_of_ones;

  always_ff @(posedge clk)begin
    if(rst)begin
        tally<=0;
        tmds <=0;
    end
    else begin
        if(video_enable)begin
            //TRUE first block

            if(tally==0 || (amount_of_ones==amount_of_zeros))begin
                tmds[9] <= !q_m[8];
                tmds[8] <= q_m[8];
                tmds[7:0] <= (q_m[8])? q_m[7:0]:~q_m[7:0];

                if(q_m[8]==0)begin
                    tally <= tally+(amount_of_zeros-amount_of_ones);
                end
                else begin
                    tally <= tally+(amount_of_ones-amount_of_zeros);
                end
            end
            //false first block
            else begin
                //block after first false
                if((tally[4]==0 &&(amount_of_ones>(amount_of_zeros)))
                 ||(tally[4]==1 && ((amount_of_zeros)>amount_of_ones)))begin
                    tmds[9] <= 1;
                    tmds[8] <= q_m[8];
                    tmds[7:0] <= ~q_m[7:0];
                    tally <= tally +(2*q_m[8])+(amount_of_zeros-amount_of_ones);
                 end
                else begin
                    tmds[9] <= 0;
                    tmds[8] <= q_m[8];
                    tmds[7:0] <= q_m[7:0];
                    tally <= (q_m[8])?tally +(amount_of_ones-amount_of_zeros):tally -2 +(amount_of_ones-amount_of_zeros);
                end
            end

        end

        else begin
            tally<=0;
            case(control)
                2'b00: tmds <= 10'b1101010100;
                2'b01: tmds <= 10'b0010101011;
                2'b10: tmds <= 10'b0101010100;
                2'b11: tmds <= 10'b1010101011;
            endcase
        end

    end

  end

endmodule

`default_nettype wire
