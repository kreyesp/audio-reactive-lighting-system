`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
module display_bars
#(
    parameter BAR_REGION_TOP    = 360,
    parameter BAR_WIDTH         = 40,
    parameter BAR_SPACING       = 40,
    parameter BAR_START_X       = 240
)(
        input wire pixel_clk,
        input wire rst,
        input wire  [31:0] low,
        input wire  [31:0] middle,
        input wire  [31:0] high,


        input wire  [31:0] low_threshold,
        input wire  [31:0] middle_threshold,
        input wire  [31:0] high_threshold,


        input wire [10:0] h_count,
        input wire [9:0] v_count,
        output logic [7:0] pixel_red,
        output logic [7:0] pixel_green,
        output logic [7:0] pixel_blue
        );


        localparam BAR_BOTTOM = 719;
        localparam BAR_MAX_HEIGHT = BAR_BOTTOM-BAR_REGION_TOP;

        localparam LOW_START_X = BAR_START_X;
        localparam LOW_END_X = BAR_START_X+BAR_WIDTH;

        localparam MIDDLE_START_X = LOW_END_X+BAR_SPACING;
        localparam MIDDLE_END_X = MIDDLE_START_X+BAR_WIDTH;

        localparam HIGH_START_X = MIDDLE_END_X+BAR_SPACING;
        localparam HIGH_END_X = HIGH_START_X+BAR_WIDTH;


        logic [31:0]low_top;
        logic [31:0]middle_top;
        logic [31:0]high_top;

        logic [31:0]low_top_threshold;
        logic [31:0]middle_top_threshold;
        logic [31:0]high_top_threshold;

        assign low_top = (low>BAR_MAX_HEIGHT)?BAR_MAX_HEIGHT:low;
        assign middle_top = (middle>BAR_MAX_HEIGHT)?BAR_MAX_HEIGHT:middle;
        assign high_top = (high>BAR_MAX_HEIGHT)?BAR_MAX_HEIGHT:high;

        assign low_top_threshold = (low_threshold>BAR_MAX_HEIGHT)?BAR_MAX_HEIGHT:low_threshold;
        assign middle_top_threshold = (middle_threshold>BAR_MAX_HEIGHT)?BAR_MAX_HEIGHT:middle_threshold;
        assign high_top_threshold = (high_threshold>BAR_MAX_HEIGHT)?BAR_MAX_HEIGHT:high_threshold;

        // assign low_top = low;
        // assign middle_top = middle ;
        // assign high_top = high ;

        always_ff @(posedge pixel_clk)begin
                if(rst)begin
                        pixel_red<=0;
                        pixel_green<=0;
                        pixel_blue<=0;
                end

                else begin
                        //low bar
                        if((({1'b0, h_count})>=LOW_START_X) && (({1'b0, h_count})<LOW_END_X))begin
                                if(({1'b0, v_count})==(BAR_BOTTOM-low_threshold)||({1'b0, v_count-1})==(BAR_BOTTOM-low_threshold)||({1'b0, v_count+1})==(BAR_BOTTOM-low_threshold))begin
                                        pixel_green<=255;
                                end
                                else if(({1'b0, v_count})>=(BAR_BOTTOM-low_top))begin
                                        pixel_red<=255;
                                        pixel_green<=255;
                                        pixel_blue<=255;
                                end
                        end


                        //middle bar
                        else if((({1'b0, h_count})>=MIDDLE_START_X) && (({1'b0, h_count})<MIDDLE_END_X))begin
                                if(({1'b0, v_count})==(BAR_BOTTOM-middle_threshold)||({1'b0, v_count-1})==(BAR_BOTTOM-middle_threshold)||({1'b0, v_count+1})==(BAR_BOTTOM-middle_threshold))begin
                                        pixel_green<=255;
                                end
                                else if({1'b0, v_count}>=(BAR_BOTTOM-middle_top))begin
                                        pixel_red<=255;
                                        pixel_green<=255;
                                        pixel_blue<=255;
                                end
                        end


                        //high bar
                        else if((({1'b0, h_count})>=HIGH_START_X) && (({1'b0, h_count})<HIGH_END_X))begin
                                if(({1'b0, v_count})==(BAR_BOTTOM-high_threshold)||({1'b0, v_count-1})==(BAR_BOTTOM-high_threshold)||({1'b0, v_count+1})==(BAR_BOTTOM-high_threshold))begin
                                        pixel_green<=255;
                                end

                                else if(({1'b0, v_count})>=(BAR_BOTTOM-high_top))begin
                                        pixel_red<=255;
                                        pixel_green<=255;
                                        pixel_blue<=255;
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
