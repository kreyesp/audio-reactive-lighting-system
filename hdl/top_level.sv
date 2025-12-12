`default_nettype none // prevents system from inferring an undeclared logic (good practice)

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

        output logic [3:0] ss0_an,//anode control for upper four digits of seven-seg display
        output logic [3:0] ss1_an,//anode control for lower four digits of seven-seg display
        output logic [6:0] ss0_c, //cathode controls for the segments of upper four digits
        output logic [6:0] ss1_c, //cathode controls for the segments of lower four digits
        output logic led_wire     //serial data for LEDs pmodb[1] in default xdc
    );


    // ============ PARAMETERS ==========


    parameter ADDR_WIDTH = $clog2(BRAM_DEPTH);
        //AUDIO DATA LOGIC
    parameter BRAM_WIDTH = 24;
    parameter BRAM_DEPTH = 1024;


    // ============ GLOBAL ASSIGMENTS ==================


    logic sys_rst;
    logic [6:0] ss_cat;
    logic [7:0] ss_an;

    assign sys_rst = btn[0];
    assign led = sw;
    assign rgb1= 0;
    assign rgb0 = 0;

    seven_segment_controller mssc(
        .clk(clk_98mhz),
        .rst(sys_rst),
        .val(choose_pic),
        .cat(ss_cat),
        .an(ss_an)
    );

    assign ss0_c = ss_cat;
    assign ss1_c = ss_cat;
    assign ss0_an = ss_an[7:4];
    assign ss1_an = ss_an[3:0];


   // ============= CLOCK GENERATION / DOMAINS ============


    logic clk_5x;
    logic clk_98mhz;
    logic clk_100mhz_buffer;
    logic clk_pixel;
    logic locked;

    // System Clock
    design_1_clk_wiz_0_0_clk_wiz create_98_clk (
        .clk_98(clk_98mhz),
        .clk_100(clk_100mhz_buffer),
        .reset(0),
        .locked(locked),
        .clk_in1(clk_100mhz)
    );

    // HDMI Clocks
    hdmi_clk_wiz_720p mhdmicw (
        .reset(0),
        .locked(locked),
        .clk_ref(clk_100mhz_buffer),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x)
    );


    // =========== I2S AUDIO INPUT =============


    // Receiving
    logic i2s_receive_master_clk;
    logic i2s_receive_ws;
    logic i2s_receive_sck; //100.34722
    logic signed [23:0] i2s_data_received;
    logic i2s_data_received_valid;
    logic signed i2s_receive_data_in;

    // MCLK Generation
    logic [3:0] count_clk_for_i2s;
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
    assign pmoda_mclk_1 = i2s_receive_master_clk;

    // Receiver
    assign i2s_receive_ws=pmoda1[5];
    assign i2s_receive_sck=pmoda1[6];
    assign i2s_receive_data_in=pmoda1[7];

    i2s_receiver #(
        .DATA_WIDTH(24)
    ) i2s_receive (
        .clk(clk_98mhz),
        .sck(i2s_receive_sck),
        .rst(sys_rst),
        .ws(i2s_receive_ws),
        .data_in(i2s_receive_data_in),
        .data_out(i2s_data_received),
        .data_valid(i2s_data_received_valid)
    );


    // =============== AUDIO BUFFER / FRAME ============


    logic signed [BRAM_WIDTH-1:0] dinb_left;
    logic signed [BRAM_WIDTH-1:0] dinb_right;
    logic signed [24:0] mono_data;
    logic both_data_valid;

    // Create Mono Data
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

    // Frame buffering samples
    logic frame_buf_ready;
    logic frame_buf_ready_d;
    logic frame_buf_valid;
    logic [23:0] frame_buf_data;

    logic load_read_en_d;
    logic load_read_en;
    logic frame_buf_read_req;

    logic start_fft_single;

    frame_buffer #(
        .POINTS(512)
    ) fb (
        .clk(clk_98mhz),
        .rst(sys_rst),
        .input_valid(both_data_valid),
        .input_data(mono_data[24:1]),
        .read_request(frame_buf_read_req),
        .data_out_valid(frame_buf_valid),
        .audio_data_out(frame_buf_data),
        .frame_ready(frame_buf_ready)
    );

    // Generate read request
    always_ff @(posedge clk_98mhz) begin
        if (sys_rst)
            load_read_en_d <= 0;
        else
            load_read_en_d <= load_read_en;
    end

    assign frame_buf_read_req =
        load_read_en & ~load_read_en_d;

    // Generate frame request
    always_ff @(posedge clk_98mhz) begin
        if (sys_rst)
            frame_buf_ready_d <= 0;
        else
            frame_buf_ready_d <= frame_buf_ready;
    end

    assign start_fft_single =
        frame_buf_ready & ~frame_buf_ready_d & ~fft_busy;


    // ========== FFT AND SMOOTHING ==================


    logic fft_busy;
    logic fft_done;

    logic [31:0] fft_out_low;
    logic [31:0] fft_out_mid;
    logic [31:0] fft_out_high;

    fft_core #(
        .POINTS(512),
        .DATA_WIDTH(24),
        .DATA_FRAC_BITS(8),
        .TWIDDLE_WIDTH(5),
        .TWIDDLE_FRAC_BITS(3),
        .DEBUG_LOAD(0)
    ) our_fft (
        .clk(clk_98mhz),
        .rst(sys_rst),
        .start_fft(start_fft_single),
        .fft_busy(fft_busy),
        .fft_done(fft_done),
        .input_data_re(frame_buf_data),
        .load_read_en(load_read_en),
        .input_data_valid(frame_buf_valid),
        .input_data_im(24'b0),
        // Debug signals to read output
        .read_addr(read_addr),
        .read_data_re(read_data_re),
        .read_data_im(),
        // Data Output
        .low_magnitude(fft_out_low),
        .mid_magnitude(fft_out_mid),
        .high_magnitude(fft_out_high)
    );

    // Debug FFT Signals
    logic [8:0] read_addr;
    logic signed [23:0] read_data_re;

    // Smoother Logic
    logic [31:0] low_smooth;
    logic [31:0] mid_smooth;
    logic [31:0] high_smooth;

    magnitude_smoother fft_low_smoother(
        .clk(clk_98mhz),
        .rst(sys_rst),
        .mag_in(fft_out_low),
        .mag_in_valid(fft_done),
        .mag_out(low_smooth)
    );

    magnitude_smoother fft_mid_smoother(
        .clk(clk_98mhz),
        .rst(sys_rst),
        .mag_in(fft_out_mid),
        .mag_in_valid(fft_done),
        .mag_out(mid_smooth)
    );

    magnitude_smoother fft_high_smoother(
        .clk(clk_98mhz),
        .rst(sys_rst),
        .mag_in(fft_out_high),
        .mag_in_valid(fft_done),
        .mag_out(high_smooth)
    );

    // T






    // only using port a for reads: we only use dout
    logic signed [BRAM_WIDTH-1:0]     douta_left;
    logic [ADDR_WIDTH-1:0]            addra_left;

    // only using port b for writes: we only use din
    logic [ADDR_WIDTH-1:0]            addrb_left;

    // only using port a for reads: we only use dout
    logic signed [BRAM_WIDTH-1:0]     douta_right;
    logic [ADDR_WIDTH-1:0]            addra_right;

    // only using port b for writes: we only use din
    logic [ADDR_WIDTH-1:0]            addrb_right;

    logic signed [23:0] data_received_left;

    logic left_data_valid;
    logic right_data_valid;



    //collects left and right channel data received, used for transmitting out to speakers
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


    // Memory addressing logic for both BRAMs
    evt_counter #(.MAX_COUNT(BRAM_DEPTH))evt_a_left(
        .clk(clk_98mhz),
        .rst(sys_rst),
        .evt(both_data_valid),
        .count(addra_left)
    );

    evt_counter #(.MAX_COUNT(BRAM_DEPTH))evt_b_left(
        .clk(clk_98mhz),
        .rst(sys_rst),
        .evt(both_data_valid),
        .count(addrb_left)
    );

    evt_counter #(.MAX_COUNT(BRAM_DEPTH))evt_a_right(
        .clk(clk_98mhz),
        .rst(sys_rst),
        .evt(both_data_valid),
        .count(addra_right)
    );

    evt_counter #(.MAX_COUNT(BRAM_DEPTH))evt_b_right(
        .clk(clk_98mhz),
        .rst(sys_rst),
        .evt(both_data_valid),
        .count(addrb_right)
    );







    logic ws_t, sck_t, dout_t, busy_transmitting;

    assign pmoda[1] = ws_t;
    assign pmoda[2] = sck_t;
    assign pmoda[3] = dout_t;




    //Transmit the audio data to speakers
    i2s_transmit
     #(.DATA_WIDTH(24)
     ) transmitting
                      (.clk(clk_98mhz),
                      .rst(sys_rst),
                      .din({douta_left,douta_right}),
                      .din_valid(1),
                      .ws(ws_t),
                      .sck(sck_t),
                      .dout(dout_t),
                      .busy(busy_transmitting)
                      );


















    //////      LED OUTPUT SECTION
    //LED BOARD IS 32x32, THIS MEANS WE WILL NEED A READ ONLY BRAM OF SIZE 32x32xNUM_FACES
    parameter TOTAL_LEDS = 1024;

    logic led_busy;
    logic led_data_out;
    logic lit_pixel; //signals that led data sent for one light
    logic [$clog2(TOTAL_LEDS)-1:0] led_lit; //count which led currently at
    logic lit_all_led; //signals all leds have been sent, held high until reset
    logic led_busy_buffer;



    //Signals that all LEDs have been lit
    always_ff @(posedge clk_98mhz)begin
        if(reset_led)begin
            lit_all_led<=0;
        end
        else begin
            if(led_lit==TOTAL_LEDS-1)begin
                lit_all_led<=1;
            end
        end
    end

    //Counts how many LEDs have been lit
    evt_counter #(.MAX_COUNT(TOTAL_LEDS))evt_count_how_many_lights_lit(
        .clk(clk_98mhz),
        .rst(reset_led),
        .evt(lit_pixel),
        .count(led_lit)
    );








    parameter NUM_FACES = 8;
    logic [$clog2(NUM_FACES)-1:0] choose_pic;

    //LOGIC FOR AUTOMATICALLY SWITCHING FACES UPON SWITCH CHANGE
    logic change_pic;
    logic [$clog2(NUM_FACES)-1:0] last_chosen_pic;
    logic reset_led;

    always_ff @(posedge clk_98mhz)begin
        last_chosen_pic<=choose_pic;
        if(last_chosen_pic!=choose_pic)begin
            change_pic<=1;
        end
        else begin
            change_pic=0;
        end
    end

    assign reset_led = change_pic|sys_rst; //Signals LED board to be ready to receive new data

    //Chooses what face to output onto the LED board
    logic [2:0] face_choice_controlled;

    face_selector img_face_selector (
        .clk(clk_98mhz),
        .rst(sys_rst),
        .low_data(low_smooth >> 14),
        .mid_data(mid_smooth >> 15),
        .high_data(high_smooth >> 15),
        .low_threshold(low_threshold),
        .mid_threshold(middle_threshold),
        .high_threshold(high_threshold),
        .update_face(lit_all_led),
        .face_state(choose_pic)
    );

    //Chooses image RGB data from BRAM and converts it to GRB
    logic [23:0] led_grb_data;

    led_choice
     #(.TOTAL_LEDS(1024), .NUM_FACES(8)
     ) fetch_GRB_data
    (   .clk(clk_98mhz), //system clock (100 MHz)
        .rst(reset_led), //reset in signal
        .led_busy(led_busy),
        .led_busy_buffer(led_busy_buffer),
        .face_choice(choose_pic),
        .grb_data(led_grb_data)
      );




    //Communicates GRB data to the led board
    led_control
     #(.TOTAL_LEDS(TOTAL_LEDS))
     led_controller
    (.clk(clk_98mhz), //system clock (100 MHz)
    .rst(reset_led), //reset in signal

    .data_in(led_grb_data), //data to send
    .data_in_valid(1),
    .all_led_lit(lit_all_led), //controls whether or not to send led data
    .data_out(led_data_out),
    .pixel_lit(lit_pixel),
    .busy(led_busy)
      );


    always_ff @(posedge clk_98mhz)begin
        led_busy_buffer<=led_busy;
    end

    assign led_wire =  led_data_out;     //change name of pmodb[1] in default xdc





























    ///////////GENERATING VISUAL DATA THAT WILL BE USED FOR HDMI DISPLAY
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

    //logic for choosing which bram block to read from
    //Upon a new frame, switch
    always_ff @(posedge clk_98mhz) begin
        offset_write<=(frame_zero_cdc[1])?0:WAVE_LENGTH;
        frame_zero_cdc <= {frame_zero_cdc[0],frame_count[0]};
    end


    always_ff @(posedge clk_pixel) begin
        offset_read<=(frame_count[0])?WAVE_LENGTH:0;
    end





    assign write_mono_address_current = {1'b0,write_mono_address_1} + offset_write;
    //read h_count spot in bram
    assign read_mono_address_current = ((h_count>=WAVE_START)&&(h_count<WAVE_LENGTH+WAVE_START))?(h_count-WAVE_START) + offset_read:0;



    evt_counter #(.MAX_COUNT(WAVE_LENGTH))evt_write_mono_data(
    .clk(clk_98mhz),
    .rst(sys_rst),
    .evt(both_data_valid),
    .count(write_mono_address_1)
    );

    logic [7:0] w_r, w_g, w_b;

    //pipeline h_count,v_count
    logic [10:0]  h_count_buffer [1:0];
    logic [9:0]  v_count_buffer [1:0];


    always_ff @(posedge clk_pixel)begin
        h_count_buffer[0]<=h_count;
        h_count_buffer[1]<=h_count_buffer[0];

        v_count_buffer[0]<=v_count;
        v_count_buffer[1]<=v_count_buffer[0];
    end









//     //DISPLAYING LOW, MIDDLE, HIGH FREQUENCY BARS
    logic [31:0] low_threshold,middle_threshold,high_threshold;
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
        .low(low_mid_high_hdmi[95:64] >> 14),
        .middle(low_mid_high_hdmi[63:32] >> 15),
        .high(low_mid_high_hdmi[31:0] >> 15),
        .low_threshold(low_threshold_pixel),
        .middle_threshold(middle_threshold_pixel),
        .high_threshold(high_threshold_pixel),
        .h_count(h_count),
        .v_count(v_count),
        .pixel_red(b_r),
        .pixel_green(b_g),
        .pixel_blue(b_b)
        );



    threshold_control
    #(
     .BAR_REGION_HEIGHT(359), .MOVE_SPEED(4)
    ) control_threshold(
        .clk(clk_98mhz),
        .rst(sys_rst),
        .up(btn[3]),
        .down(btn[2]),
        .bar_selection(sw[15:13]),
        .low_threshold(low_threshold),
        .middle_threshold(middle_threshold),
        .high_threshold(high_threshold)
    );

    parameter NUM_FFT_VALS_STORED=20;

    logic [95:0] low_mid_high;
    logic [95:0] low_mid_high_hdmi;
    logic [$clog2(NUM_FFT_VALS_STORED)-1:0] bar_write_addr;
    logic [$clog2(NUM_FFT_VALS_STORED)-1:0] bar_read_addr;
    logic [$clog2(NUM_FFT_VALS_STORED)-1:0] bar_write_addr_offset;
    logic [$clog2(NUM_FFT_VALS_STORED)-1:0] bar_read_addr_offset;

    logic [$clog2(NUM_FFT_VALS_STORED)-1:0] bram_bar_write_addr;
    logic [$clog2(NUM_FFT_VALS_STORED)-1:0] bram_bar_read_addr;


    assign low_mid_high = {low_smooth, mid_smooth, high_smooth};

    //from wave generation, use cdc for frame to control which bram section reading and writing from
    always_ff @(posedge clk_98mhz) begin
        bar_write_addr_offset<=(frame_zero_cdc[1])?0:NUM_FFT_VALS_STORED/2;
        end

    always_ff @(posedge clk_pixel) begin
        bar_read_addr_offset<=(frame_count[0])?NUM_FFT_VALS_STORED/2:0;
    end

    assign bram_bar_write_addr = {bar_write_addr} + bar_write_addr_offset;
    assign bram_bar_read_addr = {bar_read_addr}+bar_read_addr_offset;




    // Make BRAM to hold NUM_FFT_VALS_STORED samples of 96 bit data
    xilinx_true_dual_port_read_first_2_clock_ram
    #(  .RAM_WIDTH(96),
        .RAM_DEPTH(NUM_FFT_VALS_STORED)
    ) display_bar_fft_buffer(
        // PORT A:
        .addra(bram_bar_read_addr),
        .dina(0), // we only use port A for reads!
        .clka(clk_pixel),
        .wea(1'b0), // read only
        .ena(1'b1),
        .rsta(sys_rst),
        .regcea(1'b1),
        .douta(low_mid_high_hdmi),
        // PORT B:
        .addrb(bram_bar_write_addr),
        .dinb(low_mid_high),
        .clkb(clk_98mhz),
        .web(fft_done), // write always
        .enb(1'b1),
        .rstb(sys_rst),
        .regceb(1'b1),
        .doutb() // we only use port B for writes!
        );


    evt_counter #(.MAX_COUNT(NUM_FFT_VALS_STORED/2)) write_fft_addr(
        .clk(clk_98mhz),
        .rst(sys_rst),
        .evt(fft_done), //write fft values every time finished calculation
        .count(bar_write_addr)
    );

    evt_counter #(.MAX_COUNT(NUM_FFT_VALS_STORED/2)) read_fft_addr(
        .clk(clk_pixel),
        .rst(sys_rst),
        .evt(new_frame), //change which fft samples looking at after new frame
        .count(bar_read_addr)
    );









    //COMMAND FIFO FOR DOMAIN CROSSING FROM 98.304MHz to 74.25MHZ FOR THE THRESHOLD TO BE DRAWN
    //clock domain cross (from clk_98mhz to clk_pixel)
    logic empty;
    logic cdc_valid;
    logic [31:0] low_threshold_pixel, middle_threshold_pixel, high_threshold_pixel;


    xpm_fifo_async #(
       .CASCADE_HEIGHT(0),            // DECIMAL
       .CDC_SYNC_STAGES(2),           // DECIMAL
       .DOUT_RESET_VALUE("0"),        // String
       .ECC_MODE("no_ecc"),           // String
       .EN_SIM_ASSERT_ERR("warning"), // String
       .FIFO_MEMORY_TYPE("auto"),     // String
       .FIFO_READ_LATENCY(1),         // DECIMAL
       .FIFO_WRITE_DEPTH(64),       // DECIMAL
       .FULL_RESET_VALUE(0),          // DECIMAL
       .PROG_EMPTY_THRESH(10),        // DECIMAL
       .PROG_FULL_THRESH(10),         // DECIMAL
       .RD_DATA_COUNT_WIDTH(1),       // DECIMAL
       .READ_DATA_WIDTH(96),          // DECIMAL
       .READ_MODE("std"),             // String
       .RELATED_CLOCKS(0),            // DECIMAL
       .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
       .USE_ADV_FEATURES("0707"),     // String
       .WAKEUP_TIME(0),               // DECIMAL
       .WRITE_DATA_WIDTH(96),         // DECIMAL
       .WR_DATA_COUNT_WIDTH(1)        // DECIMAL
    )
    cdc_fifo (
        .wr_clk(clk_98mhz),
        .full(),
        .din({low_threshold, middle_threshold, high_threshold}),
        .wr_en(1),

        .rd_clk(clk_pixel),
        .empty(empty),
        .dout({low_threshold_pixel, middle_threshold_pixel, high_threshold_pixel}),
        .rd_en(1) //always read
    );


    assign cdc_valid = ~empty; //watch when empty. Ready immediately if something there






    ///HDMI GENERATION ONTO MONITOR
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


    display_wave #(.LENGTH_OF_WAVE(WAVE_LENGTH), .WAVE_START(WAVE_START), .WAVE_CENTER(180))
    displaying_wave(
        .pixel_clk(clk_pixel),
        .rst(sys_rst),
        .wave_data(wave_data),
        .h_count(h_count_buffer[1]),
        .v_count(v_count_buffer[1]),
        .pixel_red(w_r),
        .pixel_green(w_g),
        .pixel_blue(w_b)
        );


    assign red = (w_r | b_r);
    assign green = (w_g | b_g);
    assign blue = (w_b | b_b);


    logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
    logic tmds_signal [2:0]; //output of each TMDS serializer!

    //three tmds_encoders (blue, green, red)
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
