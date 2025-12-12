`default_nettype none // prevents system from inferring an undeclared logic (good practice)

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../data/X`"
`endif  /* ! SYNTHESIS */

module top_level(
        input wire clk_100mhz, //crystal reference clock
        input wire [15:0] sw, //all 16 input slide switches
        input wire [3:0] btn, //all four momentary button switches
        input wire [5:7] pmoda1,
        output wire  pmoda_mclk_0,
        output wire  pmoda_mclk_1,
        output wire [3:1] pmoda,
        output logic [15:0] led, //16 green output LEDs (located right above switches)
        output logic [2:0] rgb0, //rgb led
        output logic [2:0] rgb1, //rgb led
        output logic [2:0] hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
        output logic [2:0] hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
        output logic hdmi_clk_p, hdmi_clk_n, //differential hdmi clock


        //debug ports:
        output logic debug_mclk_t,        //change name of pmodb[0] in default xdc
        output logic debug_ws_t,        //change name of pmodb[1] in default xdc
        output logic debug_sck_t,        //change name of pmodb[2] in default xdc
        output logic debug_dout_t,          //change name of pmodb[3] in default xdc

        output logic debug_mclk_r,    //change name of pmodb[4] in default xdc
        output logic debug_ws_r,     //change name of pmodb[5] in default xdc
        output logic debug_sck_r,    //change name of pmodb[6] in default xdc
        output logic debug_din_r     //change name of pmodb[7] in default xdc
    );





    assign led = sw; //to verify the switch values
    //shut up those rgb LEDs (active high):
    assign rgb1= 0;
    assign rgb0 = 0;

    //have btn[0] control system reset
    logic sys_rst;
    assign sys_rst = btn[0]; //reset is btn[0]
    logic game_rst;
    assign game_rst = btn[1]; //reset is btn[1]

    logic clk_pixel, clk_5x, clk_98mhz, clk_100mhz_buffer; //clock lines
    logic locked; //locked signal (we'll leave unused but still hook it up)


    //AUDIO DATA LOGIC
    parameter BRAM_WIDTH = 24;
    parameter BRAM_DEPTH = 1024;

//     module design_1_clk_wiz_0_0_clk_wiz

//  (// Clock in ports
//   // Clock out ports
//   output        clk_98,
//   output        clk_100,
//   // Status and control signals
//   input         reset,
//   output        locked,
//   input         clk_in1
//  );

    //generate the 98 MHz clock
    design_1_clk_wiz_0_0_clk_wiz create_98_clk
        (// Clock in ports
        // Clock out ports
        .clk_98(clk_98mhz),
        .clk_100(clk_100mhz_buffer),
        // Status and control signals
        .reset(0),
        .locked(locked),
        .clk_in1(clk_100mhz)
        );

    logic [3:0] count_clk_for_i2s;

    //after 9 clk cycles, we need to send in the opposite master clock signal
    logic i2s_receive_master_clk;

    //set up the MCLK to drive the ADC and DAC
    always_ff @(posedge clk_98mhz)begin
        if(sys_rst)begin
            count_clk_for_i2s<=0;
            i2s_receive_master_clk<=0;
        end
        else begin
            //set to 0
            if(count_clk_for_i2s=='d3)begin
                count_clk_for_i2s<=0;
                i2s_receive_master_clk<=~i2s_receive_master_clk;
            end
            else begin
                count_clk_for_i2s<=count_clk_for_i2s+1;
            end
        end
    end

    assign pmoda_mclk_0 = i2s_receive_master_clk;

    logic i2s_receive_ws, i2s_receive_sck; //100.34722
    logic signed i2s_receive_data_in;
    logic signed [23:0] i2s_data_received;
    logic i2s_data_received_valid;

    // throw into double buffer after some point
    assign i2s_receive_ws=pmoda1[5];
    assign i2s_receive_sck=pmoda1[6];
    assign i2s_receive_data_in=pmoda1[7];

    assign debug_mclk_r = i2s_receive_master_clk;
    assign debug_ws_r =pmoda1[5];
    assign debug_sck_r = pmoda1[6];
    assign debug_din_r = pmoda1[7];

    //maybe add in flip flops to synchronize
    i2s_receiver#(.DATA_WIDTH(24)) i2s_receive
    (   .clk(clk_98mhz), //system clock (100 MHz)
        .sck(i2s_receive_sck),
        .rst(sys_rst), //reset in signal
        .ws(i2s_receive_ws),
        .data_in(i2s_receive_data_in), //data to send
        .data_out(i2s_data_received),
        .data_valid(i2s_data_received_valid)
      );



    parameter ADDR_WIDTH = $clog2(BRAM_DEPTH);

    // only using port a for reads: we only use dout
    logic signed [BRAM_WIDTH-1:0]     douta_left;
    logic [ADDR_WIDTH-1:0]            addra_left;

    // only using port b for writes: we only use din
    logic signed [BRAM_WIDTH-1:0]     dinb_left;
    logic [ADDR_WIDTH-1:0]            addrb_left;

     // only using port a for reads: we only use dout
    logic signed [BRAM_WIDTH-1:0]     douta_right;
    logic [ADDR_WIDTH-1:0]            addra_right;

    // only using port b for writes: we only use din
    logic signed [BRAM_WIDTH-1:0]     dinb_right;
    logic [ADDR_WIDTH-1:0]            addrb_right;


    logic signed [23:0] data_received_left;
    logic signed [24:0] mono_data;
    logic left_data_valid;
    logic right_data_valid;
    logic both_data_valid;


    // check to see when we received both valid left and right channels
    always_ff @(posedge clk_98mhz) begin
        if(i2s_receive_ws && i2s_data_received_valid)begin
            dinb_left <= i2s_data_received;
        end
        else if(!i2s_receive_ws && i2s_data_received_valid ) begin
            dinb_right <= i2s_data_received;
            //event to move both pointers in bram
            both_data_valid<=1;
            //mono data creation
            mono_data<=(i2s_data_received+dinb_left)>>>1;
        end
        else begin
            both_data_valid<=0;
        end
    end

    xilinx_true_dual_port_read_first_2_clock_ram
    #(  .RAM_WIDTH(BRAM_WIDTH),
        .RAM_DEPTH(BRAM_DEPTH)
    ) audio_bram_left(
        // PORT A:
        .addra(addra_left),
        .dina(0), // we only use port A for reads!
        .clka(clk_98mhz),
        .wea(1'b0), // read only
        .ena(1'b1),
        .rsta(sys_rst),
        .regcea(1'b1),
        .douta(douta_left),
        // PORT B:
        .addrb(addrb_left),
        .dinb(dinb_left),
        .clkb(clk_98mhz),
        .web(1'b1), // write always
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );

    xilinx_true_dual_port_read_first_2_clock_ram
    #(  .RAM_WIDTH(BRAM_WIDTH),
        .RAM_DEPTH(BRAM_DEPTH)
    ) audio_bram_right(
        // PORT A:
        .addra(addra_right),
        .dina(0), // we only use port A for reads!
        .clka(clk_98mhz),
        .wea(1'b0), // read only
        .ena(1'b1),
        .rsta(sys_rst),
        .regcea(1'b1),
        .douta(douta_right),
        // PORT B:
        .addrb(addrb_right),
        .dinb(dinb_right),
        .clkb(clk_98mhz),
        .web(1'b1), // write always
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );


    // Memory addressing for both BRAMs
    evt_counter #(.MAX_COUNT(BRAM_DEPTH))evt_a_left(
        .clk(clk_98mhz),
        .rst(sys_rst),
        // .evt(!i2s_receive_ws && i2s_data_received_valid), //write in data every 44.1kHz*2
        .evt(both_data_valid),
        .count(addra_left)
    );

    evt_counter #(.MAX_COUNT(BRAM_DEPTH))evt_b_left(
        .clk(clk_98mhz),
        .rst(sys_rst),
        // .evt(!i2s_receive_ws && i2s_data_received_valid), //read out valid data
        .evt(both_data_valid),
        .count(addrb_left)
    );

    evt_counter #(.MAX_COUNT(BRAM_DEPTH))evt_a_right(
        .clk(clk_98mhz),
        .rst(sys_rst),
        // .evt(i2s_receive_ws && i2s_data_received_valid), //write in data every 44.1kHz*2
        .evt(both_data_valid),
        .count(addra_right)
    );

    evt_counter #(.MAX_COUNT(BRAM_DEPTH))evt_b_right(
        .clk(clk_98mhz),
        .rst(sys_rst),
        // .evt(i2s_receive_ws && i2s_data_received_valid), //read out valid data
        .evt(both_data_valid),
        .count(addrb_right)
    );




    assign pmoda_mclk_1 = i2s_receive_master_clk;


    logic ws_t, sck_t, dout_t, busy_transmitting;

    assign pmoda[1] = ws_t;
    assign pmoda[2] = sck_t;
    assign pmoda[3] = dout_t;




    // //TESTING IF I2S TRANSMITTING WORKS
    //
    // logic [$clog2(40000)-1:0] test_audio_addr;
    // logic signed [23:0] test_audio;
    // //count 512
    // //  Xilinx Single Port Read First RAM
    // xilinx_single_port_ram_read_first #(
    //     .RAM_WIDTH(24),                       // Specify RAM data width
    //     .RAM_DEPTH(40000),                     // Specify RAM depth (number of entries)
    //     .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
    //     .INIT_FILE(`FPATH(output_200hz_sine.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    // ) test_audio_mem (
    //     .addra(test_audio_addr),     // Address bus, width determined from RAM_DEPTH
    //     .dina(0),       // RAM input data, width determined from RAM_WIDTH
    //     .clka(clk_98mhz),       // Clock
    //     .wea(0),         // Write enable
    //     .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    //     .rsta(sys_rst),       // Output reset (does not affect memory contents)
    //     .regcea(1),   // Output register enable
    //     .douta(test_audio)      // RAM output data, width determined from RAM_WIDTH
    // );

    // evt_counter #(.MAX_COUNT(40000))evt_c(
    //     .clk(clk_98mhz),
    //     .rst(sys_rst),
    //     .evt(test_clk == 0), //read out valid data
    //     .count(test_audio_addr)
    // );

    // logic [15:0] test_clk;
    //  evt_counter #(.MAX_COUNT(2048))evt_d(
    //     .clk(clk_98mhz),
    //     .rst(sys_rst),
    //     .evt(1), //read out valid data
    //     .count(test_clk)
    // );



    i2s_transmit
     #(.DATA_WIDTH(24)
     ) transmitting
                      (.clk(clk_98mhz),
                      .rst(sys_rst),
                      .din({douta_left,douta_right}),
                        // .din({i2s_data_received, i2s_data_received}),
                      .din_valid(1),
                      .ws(ws_t),
                      .sck(sck_t),
                      .dout(dout_t),
                      .busy(busy_transmitting)
                      );


    // assign debug_mclk_t = pmoda_mclk_1;
    // assign debug_ws_t   = ws_t;
    assign debug_sck_t  = sck_t;
    assign debug_dout_t = dout_t;
















    //////      LED OUTPUT SECTION
    //LED BOARD IS 8x32, THIS MEANS WE WILL NEED A READ ONLY BRAM OF SIZE
    parameter TOTAL_LEDS = 1024;

    logic led_busy;
    logic led_data_out;
    logic [23:0] switch_test_grb_vals;
    logic lit_pixel; //signals that led data sent for one light
    logic [$clog2(TOTAL_LEDS)-1:0] led_lit; //count which led currently at
    logic lit_all_led; //signals all leds have been sent, held high until reset
    logic led_busy_buffer;

    always_ff @(posedge clk_98mhz)begin
        led_busy_buffer<=led_busy;
    end




    always_comb begin
        if(led_lit == 1)begin
            switch_test_grb_vals=24'h0F0F0F;
        end

        else begin

            if(sw[0])begin
                //GREEN
                switch_test_grb_vals=24'h0F0000;
            end
            else if(sw[1])begin
                //RED
                switch_test_grb_vals=24'h000F00;
            end
            else if(sw[2])begin
                //BLUE
                switch_test_grb_vals=24'h00000F;
            end

            else begin
                //PURPLE
                switch_test_grb_vals=24'h000F0F;
            end

        end

    end

    // assign lit_all_led = (led_lit==254)?1:0;

    always_ff @(posedge clk_98mhz)begin
        if(sys_rst)begin
            lit_all_led<=0;
        end
        else begin
            if(led_lit==TOTAL_LEDS-1)begin
                lit_all_led<=1;
            end
        end
    end

    evt_counter #(.MAX_COUNT(TOTAL_LEDS))evt_count_how_many_lights_lit(
        .clk(clk_98mhz),
        .rst(sys_rst),
        .evt(lit_pixel),
        .count(led_lit)
    );





    // //TESTING RGB CIRCUIT LAYOUT
    // logic [$clog2(TOTAL_LEDS)-1:0] test_led_layout_data_addr;
    // logic [23:0] test_led_layout_data;

    // //count 512
    // //  Xilinx Single Port Read First RAM
    // xilinx_single_port_ram_read_first #(
    //     .RAM_WIDTH(24),                       // Specify RAM data width
    //     .RAM_DEPTH(TOTAL_LEDS),                     // Specify RAM depth (number of entries)
    //     .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
    //     // .INIT_FILE(`FPATH(512_GRB_VALUES.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    //     .INIT_FILE(`FPATH(LED_image.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    // ) test_led_layout_mem (
    //     .addra(test_led_layout_data_addr),     // Address bus, width determined from RAM_DEPTH
    //     .dina(0),       // RAM input data, width determined from RAM_WIDTH
    //     .clka(clk_98mhz),       // Clock
    //     .wea(0),         // Write enable
    //     .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    //     .rsta(sys_rst),       // Output reset (does not affect memory contents)
    //     .regcea(1),   // Output register enable
    //     .douta(test_led_layout_data)      // RAM output data, width determined from RAM_WIDTH
    // );

    // evt_counter #(.MAX_COUNT(TOTAL_LEDS))evt_test_layout_led(
    //     .clk(clk_98mhz),
    //     .rst(sys_rst),
    //     // .evt((led_busy&!led_busy_buffer)&&!all_led_lit), //increment everytime you start sending GRB value
    //     .evt((led_busy&!led_busy_buffer)),
    //     .count(test_led_layout_data_addr)
    // );
    parameter NUM_FACES = 3;

    logic [$clog2(NUM_FACES)-1:0] choose_pic;
    assign choose_pic = {sw[5],sw[4]};


    logic [23:0] led_grb_data;

    led_choice
     #(.TOTAL_LEDS(1024), .NUM_FACES(NUM_FACES)
      )
    (   .clk(clk_98mhz), //system clock (100 MHz)
        .rst(sys_rst), //reset in signal
        .led_busy(led_busy),
        .led_busy_buffer(led_busy_buffer),
        .face_choice(choose_pic),
        .grb_data(led_grb_data)
      );





    //make colors be GRB 24 bit

    led_control
     #(.TOTAL_LEDS(TOTAL_LEDS))
     led_controller
    (.clk(clk_98mhz), //system clock (100 MHz)
    .rst(sys_rst), //reset in signal
    // .data_in(switch_test_grb_vals), //data to send
    .data_in(led_grb_data), //data to send
    .data_in_valid(sw[3]),
    .all_led_lit(lit_all_led), //controls whether or not to send led data
    .data_out(led_data_out),
    .pixel_lit(lit_pixel),
    .busy(led_busy)
      );

    assign debug_ws_t =  led_data_out;     //change name of pmodb[1] in default xdc
    assign debug_mclk_t =  led_data_out;       //change name of pmodb[0] in default xdc








































    logic [10:0] h_count; //h_count of system!
    logic [9:0] v_count; //v_count of system!
    logic h_sync; //horizontal sync signal
    logic v_sync; //vertical sync signal
    logic active_draw; //ative draw! 1 when in drawing region.0 in blanking/sync
    logic new_frame; //one cycle active indicator of new frame of info!
    logic [5:0] frame_count; //0 to 59 then rollover frame counter







    //////////Displaying a wave data
    parameter WAVE_LENGTH = 800;
    parameter WAVE_BITS = 8;
    parameter WAVE_START = 11'd240;


    logic [$clog2(WAVE_LENGTH)-1:0] write_mono_address_1;
    logic [$clog2(2*WAVE_LENGTH)-1:0] write_mono_address_current;
    logic [$clog2(WAVE_LENGTH)-1:0] read_mono_address_1;
    logic [$clog2(2*WAVE_LENGTH)-1:0] read_mono_address_current;


    logic [$clog2(800)-1:0] offset_write;
    logic [$clog2(800)-1:0] offset_read;

    logic [23:0] wave_data;


    // Make BRAM to hold WAVE_LENGTH samples of 8 bit data
    xilinx_true_dual_port_read_first_2_clock_ram
    #(  .RAM_WIDTH(24),
        .RAM_DEPTH(2*WAVE_LENGTH)
    ) display_wave_audio_buffer(
        // PORT A:
        .addra(read_mono_address_current),
        .dina(0), // we only use port A for reads!
        .clka(clk_pixel),
        .wea(1'b0), // read only
        .ena(1'b1),
        .rsta(sys_rst),
        .regcea(1'b1),
        .douta(wave_data),
        // PORT B:
        .addrb(write_mono_address_current),
        .dinb(mono_data),
        .clkb(clk_98mhz),
        .web(1'b1), // write always
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );

        logic [1:0] frame_zero_cdc;
        // //logic for choosing which bram block to read from
        // always_ff @(posedge clk_98mhz) begin
        //     if(sys_rst)begin
        //         offset_write<=0;
        //         // offset_read<=WAVE_LENGTH;
        //     end
        //     else begin
        //         //on a new frame switch which block you are reading/writing from
        //         if(newframe_cdc[1])begin
        //             offset_write<=(offset_write==WAVE_LENGTH)?0:WAVE_LENGTH;
        //             // offset_read<=(offset_write==WAVE_LENGTH)?WAVE_LENGTH:0;
        //         end
        //         else begin
        //             offset_write<=offset_write;
        //             // offset_read<=offset_read;
        //         end
        //     end
        //     newframe_cdc <= {newframe_cdc[0],new_frame};
        // end

        //logic for choosing which bram block to read from

        always_ff @(posedge clk_98mhz) begin
            offset_write<=(frame_zero_cdc[1])?0:WAVE_LENGTH;
            frame_zero_cdc <= {frame_zero_cdc[0],frame_count[0]};
        end


        always_ff @(posedge clk_pixel) begin
            offset_read<=(frame_count[0])?WAVE_LENGTH:0;
        end





        assign write_mono_address_current = write_mono_address_1 + offset_write;
        // assign read_mono_address_current = read_mono_address_1 + offset_read;
        //read h_count spot in bram
        assign read_mono_address_current = ((h_count>=WAVE_START)&&(h_count<WAVE_LENGTH+WAVE_START))?(h_count-WAVE_START) + offset_read:0;



        evt_counter #(.MAX_COUNT(WAVE_LENGTH))evt_write_mono_data(
        .clk(clk_98mhz),
        .rst(sys_rst),
        // .evt(!i2s_receive_ws && i2s_data_received_valid), //read out valid data
        .evt(both_data_valid),
        .count(write_mono_address_1)
    );

    //     evt_counter #(.MAX_COUNT(WAVE_LENGTH))evt_read_mono_data(
    //     .clk(clk_98mhz),
    //     .rst(sys_rst),
    //     // .evt(!i2s_receive_ws && i2s_data_received_valid), //read out valid data
    //     .evt(both_data_valid),
    //     .count(read_mono_address_1)
    // );

    logic [7:0] w_r, w_g, w_b;

    logic [10:0]  h_count_buffer [1:0];
    logic [9:0]  v_count_buffer [1:0];


    always_ff @(posedge clk_pixel)begin
        h_count_buffer[0]<=h_count;
        h_count_buffer[1]<=h_count_buffer[0];

        v_count_buffer[0]<=v_count;
        v_count_buffer[1]<=v_count_buffer[0];
    end









    //DISPLAYING LOW, MIDDLE, HIGH FREQUENCY BARS
    logic [7:0] b_r, b_g, b_b;


    display_bars
#(
    .BAR_REGION_TOP(340),
    .BAR_WIDTH(60),
    .BAR_SPACING(200),
    .BAR_START_X(360)
)   display_frequencies(
        .pixel_clk(clk_pixel),
        .rst(sys_rst),
        .low('hFFFF),
        .middle('h000F),
        .high('h0FF0),
        .h_count(h_count),
        .v_count(v_count),
        .pixel_red(b_r),
        .pixel_green(b_g),
        .pixel_blue(b_b)
        );































   //clock manager...creates 74.25 Hz and 5 times 74.25 MHz for pixel and TMDS
    hdmi_clk_wiz_720p mhdmicw (
        .reset(0),
        .locked(locked),
        .clk_ref(clk_100mhz_buffer),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x));


    //written by you previously! (make sure you include in your hdl)
    //default instantiation so making signals for 720p
    video_sig_gen mvg(
        .pixel_clk(clk_pixel),
        .rst(sys_rst),
        .h_count(h_count),
        .v_count(v_count),
        .v_sync(v_sync),
        .h_sync(h_sync),
        .active_draw(active_draw),
        .new_frame(new_frame),
        .frame_count(frame_count));

    logic [7:0] red, green, blue; //red green and blue pixel values for output
    logic [7:0] tp_r, tp_g, tp_b; //color values as generated by test_pattern module
    logic [7:0] pg_r, pg_g, pg_b;//color values as generated by pong game(part 2)
    // logic [7:0]

    //comment out in checkoff 1 once you know you have your video pipeline working:
    //these three colors should be the 2025 6.205 color on full screen .
    // assign tp_r = 8'hD4;
    // assign tp_g = 8'h6A;
    // assign tp_b = 8'h4C;

    //uncomment the test pattern generator for the latter portion of part 1
    //and use it to drive tp_r,g, and b once you know that your video
    //pipeline is working (by seeing a terracotta color)
    test_pattern_generator mtpg(
       .pattern_select(sw[1:0]),
       .h_count(h_count),
       .v_count(v_count),
       .pixel_red(tp_r),
       .pixel_green(tp_g),
       .pixel_blue(tp_b));

    //uncomment for last part of lab!:

    // pong my_pong (
    //     .pixel_clk(clk_pixel),
    //     .rst(game_rst),
    //     .control(btn[3:2]),
    //     .puck_speed(sw[15:12]),
    //     .paddle_speed(sw[11:8]),
    //     .new_frame(new_frame),
    //     .h_count(h_count),
    //     .v_count(v_count),
    //     .pixel_red(pg_r),
    //     .pixel_green(pg_g),
    //     .pixel_blue(pg_b));

    logic signed [23:0] test_line;
    assign test_line = $signed({8'sb00010001, 16'sh0000});

    display_wave #(.LENGTH_OF_WAVE(WAVE_LENGTH), .WAVE_START(WAVE_START), .WAVE_CENTER(180))
    displaying_wave(
        .pixel_clk(clk_pixel),
        .rst(sys_rst),
        .audio_data_l(wave_data),
        .audio_data_r(test_line),
        .h_count(h_count_buffer[1]),
        .v_count(v_count_buffer[1]),
        .pixel_red(w_r),
        .pixel_green(w_g),
        .pixel_blue(w_b)
        );


    // always_comb begin
    //     if (~sw[2])begin //if switch 3 switched use shapes signal from part 2, else defaults
    //         red = tp_r;
    //         green = tp_g;
    //         blue = tp_b;
    //     end else begin
    //         red = pg_r;
    //         green = pg_g;
    //         blue = pg_b;
    //     end
    // end
    // always_comb begin
    //     if (~sw[2])begin //if switch 3 switched use shapes signal from part 2, else defaults
    //         red = tp_r;
    //         green = tp_g;
    //         blue = tp_b;
    //     end else begin
    //         red = (w_r | b_r);
    //         green = (w_g | b_g);
    //         blue = (w_b | b_b);
    //     end
    // end
    assign red = (w_r | b_r);
    assign green = (w_g | b_g);
    assign blue = (w_b | b_b);
    // assign red = w_r;
    // assign green = w_g;
    // assign blue = w_b;

    logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
    logic tmds_signal [2:0]; //output of each TMDS serializer!

    //three tmds_encoders (blue, green, red)
    //MISSING two more tmds encoders (one for green and one for blue)
    //note green should have no control signal like red
    //the blue channel DOES carry the two sync signals:
    //  * control[0] = horizontal sync signal
    //  * control[1] = vertical sync signal
    tmds_encoder tmds_red(
        .clk(clk_pixel),
        .rst(sys_rst),
        .video_data(red),
        .control(2'b0),
        .video_enable(active_draw),
        .tmds(tmds_10b[2]));

    tmds_encoder tmds_green(
        .clk(clk_pixel),
        .rst(sys_rst),
        .video_data(green),
        .control(2'b0),
        .video_enable(active_draw),
        .tmds(tmds_10b[1]));

    tmds_encoder tmds_blue(
        .clk(clk_pixel),
        .rst(sys_rst),
        .video_data(blue),
        .control({v_sync, h_sync}),
        .video_enable(active_draw),
        .tmds(tmds_10b[0]));

    //three tmds_serializers (blue, green, red):
    //MISSING: two more serializers for the green and blue tmds signals.
    tmds_serializer red_ser(
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst(sys_rst),
        .tmds_in(tmds_10b[2]),
        .tmds_out(tmds_signal[2]));

    tmds_serializer green_ser(
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst(sys_rst),
        .tmds_in(tmds_10b[1]),
        .tmds_out(tmds_signal[1]));

    tmds_serializer blue_ser(
        .clk_pixel(clk_pixel),
        .clk_5x(clk_5x),
        .rst(sys_rst),
        .tmds_in(tmds_10b[0]),
        .tmds_out(tmds_signal[0]));

    //output buffers generating differential signals:
    //three for the r,g,b signals and one that is at the pixel clock rate
    //the HDMI receivers use recover logic coupled with the control signals asserted
    //during blanking and sync periods to synchronize their faster bit clocks off
    //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
    //the slower 74.25 MHz clock)
    OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));

endmodule // top_level
`default_nettype wire
