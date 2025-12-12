module counter(     input wire clk,
                    input wire rst,
                    input wire [31:0] period,
                    output logic [31:0] count
              );

    //your code here

    always_ff @(posedge clk)begin
      if(count>=(period-1) || rst==1) begin
        count <= 0;
      end
      else begin
        count <= count + 1;
      end
    end
endmodule
