`default_nettype none
module threshold_control#(
    parameter BAR_REGION_HEIGHT    = 359, parameter MOVE_SPEED = 4
)
    (
        input wire clk,
        input wire rst,
        input wire up,
        input wire down,
        input wire [2:0] bar_selection,
        output logic [31:0] low_threshold,
        output logic [31:0] middle_threshold,
        output logic [31:0] high_threshold
    );
    logic [21:0] counter; //count 1/32 of a second


    always_ff @(posedge clk)begin
        if(rst)begin
            low_threshold<=0;
            middle_threshold<=0;
            high_threshold<=0;
            counter<=0;
        end
        else begin
            if(counter==3062499)begin
                case(bar_selection)
                3'b001:begin
                    if(up&&(high_threshold+MOVE_SPEED<BAR_REGION_HEIGHT))begin
                        high_threshold<=high_threshold+MOVE_SPEED;
                    end
                    if(down && (high_threshold>0+MOVE_SPEED))begin
                        high_threshold<=high_threshold-MOVE_SPEED;
                    end
                end
                3'b010:begin
                    if(up&&(middle_threshold+MOVE_SPEED<BAR_REGION_HEIGHT))begin
                        middle_threshold<=middle_threshold+MOVE_SPEED;
                    end
                    if(down&& (middle_threshold>0+MOVE_SPEED))begin
                        middle_threshold<=middle_threshold-MOVE_SPEED;
                    end
                end
                3'b100:begin
                    if(up&&(low_threshold+MOVE_SPEED<BAR_REGION_HEIGHT))begin
                        low_threshold<=low_threshold+MOVE_SPEED;
                    end
                    if(down&& (low_threshold>0+MOVE_SPEED))begin
                        low_threshold<=low_threshold-MOVE_SPEED;
                    end
                end


                endcase
                counter<=0;
            end
            else begin
                counter<=counter+1;
            end
        end
    end






endmodule
`default_nettype wire
