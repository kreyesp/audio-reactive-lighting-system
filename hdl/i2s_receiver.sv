`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module i2s_receiver
     #(parameter DATA_WIDTH = 24
      )
    (   input wire   clk, //system clock (100 MHz)
        input wire   sck,
        input wire   rst, //reset in signal
        input wire   ws,
        input wire signed  data_in, //data to send

        output logic signed [DATA_WIDTH-1:0] data_out,
        output logic data_valid
        // output logic is_right
      );

        logic last_ws;
        logic last_sck;
        // logic sent_data;
        logic signed [DATA_WIDTH-1:0] left_data_in_buffer;
        logic  [$clog2(DATA_WIDTH):0] left_bits_received;

        logic signed [DATA_WIDTH-1:0] right_data_in_buffer;
        logic [$clog2(DATA_WIDTH):0] right_bits_received;


        typedef enum {
        RECEIVE_L=0,
        RECEIVE_R =1,
        SKIP_FIRST_R = 2,
        SKIP_FIRST_L = 3
        } i2s_state;

        i2s_state state;



      always_ff @(posedge clk)begin
        if(rst)begin
            data_valid<=0;
            left_data_in_buffer<=0;
            left_bits_received<=0;
            right_data_in_buffer<=0;
            right_bits_received<=0;
            data_valid<=0;
            last_sck <= 0;
            last_ws <=0;
            data_out<=0;
            state<=RECEIVE_L;
        end

        else begin
            last_sck <= sck;
            last_ws <= ws;

            case(state)
                RECEIVE_L:begin
                    data_valid<=0;
                    //switching to skip MSB bit
                    if(ws!=last_ws && ws)begin
                        state<=SKIP_FIRST_R;
                    end

                    //falling edge of sck
                    if(!sck && last_sck)begin
                        //receive in the left buffer
                        if(left_bits_received<DATA_WIDTH)begin
                            left_data_in_buffer<={left_data_in_buffer[DATA_WIDTH-2:0], data_in};
                            left_bits_received<= left_bits_received+1;
                        end
                    end
                end

                RECEIVE_R:begin
                    data_valid<=0;
                    //switching to skip MSB bit
                    if(ws!=last_ws && !ws)begin
                        state<=SKIP_FIRST_L;
                    end
                    //falling edge of sck
                    if((!sck && last_sck))begin
                        //receive in the left buffer
                        if(right_bits_received<DATA_WIDTH)begin
                            right_data_in_buffer<={right_data_in_buffer[DATA_WIDTH-2:0], data_in};
                            right_bits_received<= right_bits_received+1;
                        end
                    end

                end

                SKIP_FIRST_R:begin
                    //falling edge of sck output valid data for a cycle
                    if((!sck && last_sck))begin
                        data_out<=left_data_in_buffer;

                        //send single pulse data_valid
                        data_valid<=1;

                        //switch to receive right channel data
                        state<=RECEIVE_R;
                    end

                    right_bits_received<=0;
                    right_data_in_buffer<=0;
                end

                SKIP_FIRST_L:begin
                    //falling edge of sck output valid data for a cycle
                    if((!sck && last_sck))begin
                        data_out<=right_data_in_buffer;

                        //send single pulse data_valid
                        data_valid<=1;

                        //switch to receive right channel data
                        state<=RECEIVE_L;
                    end

                    left_bits_received<=0;
                    left_data_in_buffer<=0;
                end
            endcase


        end
        end



endmodule
`default_nettype wire
