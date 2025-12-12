module tm_choice (
        input wire [7:0] d, //data byte in
        output logic [8:0] q_m //transition minimized output
    );
    logic [3:0] amount_of_ones;
    logic option;

    always_comb begin
        //get the amount of 1's
        amount_of_ones = d[0]+d[1]+d[2]+d[3]+d[4]+d[5]+d[6]+d[7];
        //cases
        if(amount_of_ones>4)begin
            option = 1'b1;
        end
        else if (amount_of_ones==4 &&!d[0])begin
            option = 1'b1;
        end
        else begin
            option = 1'b0;
        end


        case(option)
            1'b0: begin
                q_m[0] = d[0];
                q_m[1] = d[1]^q_m[0];
                q_m[2] = d[2]^q_m[1];
                q_m[3] = d[3]^q_m[2];
                q_m[4] = d[4]^q_m[3];
                q_m[5] = d[5]^q_m[4];
                q_m[6] = d[6]^q_m[5];
                q_m[7] = d[7]^q_m[6];
                q_m[8] = 1'b1;
            end

            1'b1: begin
                q_m[0] = d[0];
                q_m[1] = ~(d[1]^q_m[0]);
                q_m[2] = ~(d[2]^q_m[1]);
                q_m[3] = ~(d[3]^q_m[2]);
                q_m[4] = ~(d[4]^q_m[3]);
                q_m[5] = ~(d[5]^q_m[4]);
                q_m[6] = ~(d[6]^q_m[5]);
                q_m[7] = ~(d[7]^q_m[6]);
                q_m[8] = 1'b0;
            end
        endcase

    end

endmodule
