`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
module display_wave
#(parameter LENGTH_OF_WAVE = 800, parameter WAVE_START = 240, parameter signed WAVE_CENTER = 180)(
        input wire pixel_clk,
        input wire rst,
        input wire signed [23:0] wave_data,
        input wire [10:0] h_count,
        input wire [9:0] v_count,
        output logic [7:0] pixel_red,
        output logic [7:0] pixel_green,
        output logic [7:0] pixel_blue
        );

        //want to have wave be half of the screen width
        localparam HALF_SCREEN_WIDTH = 640;
        localparam signed Y_CENTER = WAVE_CENTER;
        localparam SCREEN_WIDTH = 1280;
        localparam SCREEN_HEIGHT = 720;

        //store last 3 audio data samples for averaging.
        logic signed [7:0] audio_data_buffer [2:0];
        logic signed [9:0] summed_audio_data;
        logic signed [7:0] avg_audio_data;


        //grab top 8 bits of both data samples (-128,127 y direction)
        logic signed [7:0] wave_data_top;
        logic signed [10:0] y_offset;

        assign wave_data_top = wave_data[23:16];


        //THIS IS THE DENOISED VERSION
        assign summed_audio_data = audio_data_buffer[0] +audio_data_buffer[1]+audio_data_buffer[2]+wave_data_top;
        assign avg_audio_data = summed_audio_data>>>2;
        assign y_offset = Y_CENTER - (avg_audio_data<<<1);


        always_ff @(posedge pixel_clk)begin
            if(rst)begin

                pixel_red<=0;
                pixel_green<=0;
                pixel_blue<=0;
                audio_data_buffer[0] <=1'sb0;
                audio_data_buffer[1] <=1'sb0;
                audio_data_buffer[2] <=1'sb0;

            end
            else begin
                audio_data_buffer[0] <=wave_data_top;
                audio_data_buffer[1] <=audio_data_buffer[0];
                audio_data_buffer[2] <=audio_data_buffer[1];

                //if you are in desired h_count region
                if((h_count < LENGTH_OF_WAVE+WAVE_START)&&(h_count>WAVE_START) && (v_count<SCREEN_HEIGHT))begin
                    //only show left wave at first
                    if($signed({1'b0,v_count}) == y_offset)begin
                        pixel_red<='d255;
                    end
                    else begin
                        pixel_red<=0;
                    end


                end
                else begin

                    pixel_red<=0;
                    pixel_green<=0;
                    pixel_blue<=0;
                end




            end



        end










endmodule
`default_nettype wire
