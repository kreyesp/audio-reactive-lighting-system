`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module i2s_transmit
     #(parameter DATA_WIDTH=24
    //  parameter SLOT_BITS=24, //how many bits it should send per channel
     )
                      (input wire clk,
                      input wire rst,
                      input wire signed [DATA_WIDTH*2-1:0] din,
                      input wire din_valid,
                      output logic ws,
                      output logic sck,
                      output logic signed dout,
                      output logic busy
                      );

        localparam HALF_PERIOD = 16;
        localparam PERIOD = 32;
        localparam HALF_DATA_WIDTH = DATA_WIDTH/2;


        typedef enum {
            IDLE = 0,
            START=1,
            TRANSMIT_L=2,
            TRANSMIT_R =3
        } i2s_state;

        i2s_state state;

        logic signed [DATA_WIDTH-1:0] right_data;
        logic signed [DATA_WIDTH-1:0] left_data;

        logic signed [DATA_WIDTH-1:0] right_data_buffer;
        logic signed [DATA_WIDTH-1:0] left_data_buffer;

        logic [(DATA_WIDTH)-1:0] left_bits_sent;
        logic [(DATA_WIDTH)-1:0] right_bits_sent;

        logic [$clog2(PERIOD)-1:0] count_cycles;

        logic begin_transmit_left, begin_transmit_right;

        logic [4:0] sck_cycles_passed;

        assign right_data = (!busy && din_valid)?din[(DATA_WIDTH)-1:0]:0;
        assign left_data =  (!busy && din_valid)?din[(DATA_WIDTH*2)-1:(DATA_WIDTH)]:0;

        always_ff @(posedge clk)begin
            if(rst)begin
                sck<=0;
                count_cycles<=0;
                busy<=0;
                right_data_buffer<=0;
                left_data_buffer<=0;
                left_bits_sent<=0;
                right_bits_sent<=0;
                begin_transmit_left<=1;
                begin_transmit_right<=0;
                sck_cycles_passed<=0;
                state<=IDLE;

            end
            else begin


                case(state)
                //wait for valid data to come in
                IDLE:begin
                    right_data_buffer<=right_data;
                    left_data_buffer<= left_data;
                    dout <=0;

                    if(din_valid && !busy)begin
                        begin_transmit_left<=1;
                        state<=START;
                        busy<=1;
                        count_cycles<=1;
                        sck<=0;

                        //starting to transmit left
                        ws<=0;

                    end
                end

                //WS change, skip sending for one SCK cycle
                START:begin
                    //Control what sck wave is
                    if(count_cycles==PERIOD-1)begin
                        sck_cycles_passed<=1;
                        sck<=0;
                        count_cycles<=0;

                        //send a bit since end of buffer cycle, 1 bit sent
                        if(begin_transmit_left)begin
                            left_bits_sent<=1;
                            begin_transmit_left<=0;

                            dout<=left_data_buffer[DATA_WIDTH-1];
                            left_data_buffer<=left_data_buffer<<<1;
                            state<=TRANSMIT_L;
                        end
                        else if(begin_transmit_right)begin
                            right_bits_sent<=1;
                            begin_transmit_right<=0;

                            dout<=right_data_buffer[DATA_WIDTH-1];
                            right_data_buffer<=right_data_buffer<<<1;
                            state<=TRANSMIT_R;
                        end

                    end

                    else if(count_cycles==HALF_PERIOD-1)begin
                        sck<=1;
                        count_cycles<=count_cycles+1;

                    end
                    else begin
                        count_cycles<=count_cycles+1;
                    end


                end
                //sending all bits of left channel
                TRANSMIT_L:begin
                    //Control what sck wave is
                    if(count_cycles==PERIOD-1)begin
                        //one full cycle passed
                        sck_cycles_passed<=sck_cycles_passed+1;

                        sck<=0;
                        count_cycles<=0;


                        //send bits up until sent 24 bits
                        if(left_bits_sent<DATA_WIDTH)begin

                            left_bits_sent<=left_bits_sent+1;
                            dout<=left_data_buffer[DATA_WIDTH-1];
                            left_data_buffer<=left_data_buffer<<<1;

                        end
                        else begin
                            dout<=0;
                        end

                        if(sck_cycles_passed=='d31)begin
                            ws<=1;
                            state<=START;
                            sck_cycles_passed<=0;
                            begin_transmit_right<=1;
                            right_bits_sent<=0;
                        end

                    end
                    else if(count_cycles==HALF_PERIOD-1)begin
                        sck<=1;
                        count_cycles<=count_cycles+1;
                    end

                    else begin
                        count_cycles<=count_cycles+1;
                    end



                end

                //sending all the bits of right channel
                TRANSMIT_R:begin
                    //Control what sck wave is
                    if(count_cycles==PERIOD-1)begin
                        sck_cycles_passed<=sck_cycles_passed+1;
                        sck<=0;
                        count_cycles<=0;


                        //send bits up until sent 24 bits
                        if(right_bits_sent<DATA_WIDTH)begin

                            right_bits_sent<=right_bits_sent+1;
                            dout<=right_data_buffer[DATA_WIDTH-1];
                            right_data_buffer<=right_data_buffer<<<1;

                        end
                        else begin
                            dout<=0;
                        end

                        if(sck_cycles_passed=='d31)begin
                            ws<=0;
                            state<=IDLE;
                            sck_cycles_passed<=0;
                            busy<=0;
                            begin_transmit_left<=1;
                            left_bits_sent<=0;
                        end

                    end

                    else if(count_cycles==HALF_PERIOD-1)begin
                        sck<=1;
                        count_cycles<=count_cycles+1;
                    end
                    else begin
                        count_cycles<=count_cycles+1;
                    end

                end
                endcase
            end
        end


endmodule
`default_nettype wire
