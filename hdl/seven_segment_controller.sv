`default_nettype none
module seven_segment_controller #(parameter COUNT_PERIOD = 100000)
    (   input wire           clk,
        input wire           rst,
        input wire [31:0]    val,
        output logic[6:0]    cat,
        output logic[7:0]    an
    );
    logic [7:0]   segment_state;
    logic [31:0]  segment_counter;
    logic [3:0]   sel_values;
    logic [6:0]   led_out;
 
    //TODO: wire up sel_values (-> x) with your input, val
    //Note that x is a 4 bit input, and val is 32 bits wide
    //Adjust accordingly, based on what you know re. which digits
    //are displayed when...

    always_comb begin
        case (segment_state)
            8'b0000_0001: sel_values = val[3:0];
            8'b0000_0010: sel_values = val[7:4];
            8'b0000_0100: sel_values = val[11:8];
            8'b0000_1000: sel_values = val[15:12];
            8'b0001_0000: sel_values = val[19:16];
            8'b0010_0000: sel_values = val[23:20];
            8'b0100_0000: sel_values = val[27:24];
            8'b1000_0000: sel_values = val[31:28];
        endcase
    end

 
    bto7s mbto7s (.x(sel_values), .s(led_out));
    assign cat = ~led_out; //<--note this inversion is needed
    assign an = ~segment_state; //note this inversion is needed
 
    always_ff @(posedge clk)begin
        if (rst)begin
            segment_state <= 8'b0000_0001;
            segment_counter <= 32'b0;
        end else begin
            if (segment_counter == COUNT_PERIOD) begin
                segment_counter <= 32'd0;
                segment_state <= {segment_state[6:0],segment_state[7]};
            end else begin
                segment_counter <= segment_counter +1;
            end
        end
    end
endmodule // seven_segment_controller
 
module bto7s(
        input wire [3:0] x,
        output logic [6:0] s
    );
    logic [15:0] num;

    assign num[0] = ~x[3] && ~x[2] && ~x[1] && ~x[0];
    assign num[1] = ~x[3] && ~x[2] && ~x[1] && x[0];
    assign num[2] = x == 4'd2;
    assign num[3] = x == 4'd3;
    assign num[4] = x == 4'd4;
    assign num[5] = x == 4'd5;
    assign num[6] = x == 4'd6;
    assign num[7] = x == 4'd7;
    assign num[8] = x == 4'd8;
    assign num[9] = x == 4'd9;
    assign num[10] = x == 4'd10;    
    assign num[11] = x == 4'd11;
    assign num[12] = x == 4'd12;
    assign num[13] = x == 4'd13;
    assign num[14] = x == 4'd14;
    assign num[15] = x == 4'd15;

    assign s[0] = num[0] || num[2] || num[3] || num[5] || num[6] || num[7] || num[8] || num[9] || num[10] || num[12] || num[14] || num[15];
    assign s[1] = num[0] || num[1] || num[2] || num[3] || num[4] || num[7] || num[8] || num[9] || num[10] || num[13];
    assign s[2] = num[0] || num[1] || num[3] || num[4] || num[5] || num[6] || num[7] || num[8] || num[9] || num[10] || num[11] || num[13];
    assign s[3] = num[0] || num[2] || num[3] || num[5] || num[6] || num[8] || num[9] || num[11] || num[12] || num[13] || num[14];
    assign s[4] = num[0] || num[2] || num[6] || num[8] || num[10] || num[11] || num[12] || num[13] || num[14] || num[15];
    assign s[5] = num[0] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[12] || num[14] || num[15];
    assign s[6] = num[2] || num[3] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[13] || num[14] || num[15];
endmodule

`default_nettype wire