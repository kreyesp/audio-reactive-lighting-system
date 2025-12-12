`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module led_control
     #(parameter TOTAL_LEDS = 24
      )
    (   input wire   clk, //system clock (100 MHz)
        input wire   rst, //reset in signal
        input wire [23:0]  data_in, //data to send
        input wire data_in_valid,
        input wire all_led_lit,
        output logic data_out,
        output logic pixel_lit,
        output logic busy
      );

      //to send "0" want to hold high for 49 cycles, and low for 74
      //to send "1" want to hold high for 86 cycles, and low for 37
      localparam ZERO_CYCLES_LOW = 74;
      localparam ZERO_CYCLES_HIGH = 49;

      localparam ONE_CYCLES_LOW = 37;
      localparam ONE_CYCLES_HIGH = 86;

      localparam WAIT_CYCLES = 5000;

    typedef enum {
            RECEIVE_SAMPLE = 0, //input 24 bits you want to send
            TRANSMIT_ZERO=1,
            TRANSMIT_ONE = 2,
            WAIT=3
    } led_state;

    led_state state;

    //GRB values we want to send (send MSB first)
    logic [23:0] data_in_buffer;
    logic [$clog2(WAIT_CYCLES)-1:0] cycles;
    logic [$clog2(24)-1:0] bits_sent;



    always_ff @(posedge clk)begin
        if(rst)begin
            busy<=0;
            data_in_buffer<=data_in; //use to be zero, but wasn't working as expected
            data_out<=0;
            bits_sent <=0;
            state<= WAIT;
            cycles<=0;
            pixel_lit<=0;
        end
        else begin
            case(state)
            RECEIVE_SAMPLE:begin
                if(data_in_valid)begin
                    data_in_buffer<= data_in<<1;
                    state<=(data_in[23]==1)?TRANSMIT_ONE:TRANSMIT_ZERO;
                    busy<=1;
                    cycles<= cycles+1;
                end
                data_out<=1;
                pixel_lit<=0;
            end

            TRANSMIT_ZERO:begin
                //if sent all the necessary bits, receive new info
                if(bits_sent=='d24 && !all_led_lit)begin
                    state<=RECEIVE_SAMPLE;
                    bits_sent <=0 ;
                    pixel_lit<=0;
                    busy<= 0;
                end
                //if sent all the led signals, go to the reset signal
                else if (bits_sent=='d24 && all_led_lit)begin
                    //reset signal
                    state<=WAIT;
                    bits_sent <=0;
                    pixel_lit<=0;

                end
                //continue sending bits
                else begin


                    // pixel_lit<=0;
                    //hold high
                    if(cycles<ZERO_CYCLES_HIGH)begin
                        cycles<=cycles+1;
                        data_out<=1;
                    end
                    //hold low
                    else if(cycles<ZERO_CYCLES_HIGH+ZERO_CYCLES_LOW-1)begin
                        cycles<=cycles+1;
                        data_out<=0;
                    end
                    //sending last cycle
                    else if (cycles==ZERO_CYCLES_HIGH+ZERO_CYCLES_LOW-1)begin
                        cycles<=0;
                        data_out<=0;
                        bits_sent<=bits_sent+1;

                        state<= (data_in_buffer[23]==1)?TRANSMIT_ONE:TRANSMIT_ZERO;
                        data_in_buffer<= data_in_buffer<<1;
                        //sent all the pixels
                        if(bits_sent=='d23)begin
                            pixel_lit<=1;
                        end
                        else begin
                            pixel_lit<=0;
                        end
                    end

                end

            end

            TRANSMIT_ONE:begin
                //if sent all the necessary bits, receive new info
                if(bits_sent=='d24 && !all_led_lit)begin
                    state<=RECEIVE_SAMPLE;
                    bits_sent <=0 ;
                    pixel_lit<=0;
                    busy<= 0;
                end

                //if sent all the led signals, go to the reset signal
                else if (bits_sent=='d24 && all_led_lit)begin
                    //reset signal
                    state<=WAIT;
                    bits_sent <=0;
                    pixel_lit<=0;
                end
                //continue sending bits
                    else begin
                    // pixel_lit<=0;

                    if(cycles<ONE_CYCLES_HIGH)begin
                        cycles<=cycles+1;
                        data_out<=1;
                    end
                    else if(cycles<ONE_CYCLES_HIGH+ONE_CYCLES_LOW-1)begin
                        cycles<=cycles+1;
                        data_out<=0;
                    end
                    //sending last cycle
                    else if (cycles==ONE_CYCLES_HIGH+ONE_CYCLES_LOW-1)begin
                        cycles<=0;
                        data_out<=0;
                        bits_sent<=bits_sent+1;

                        state<= (data_in_buffer[23]==1)?TRANSMIT_ONE:TRANSMIT_ZERO;
                        data_in_buffer<= data_in_buffer<<1;

                        //sent all the pixels
                        if(bits_sent=='d23)begin
                            pixel_lit<=1;
                        end
                        else begin
                            pixel_lit<=0;
                        end
                    end
                end
            end

            WAIT:begin
                if(all_led_lit)begin
                    state<=WAIT;
                end
                else begin
                    //RESET CODE
                    pixel_lit<=0;
                    if(cycles==WAIT_CYCLES-1)begin
                        busy<= 0;
                        cycles<=0;
                        state<=RECEIVE_SAMPLE;
                    end
                    else begin
                        cycles<=cycles+1;
                    end
                end


            end

            endcase

        end
    end




endmodule
`default_nettype wire
