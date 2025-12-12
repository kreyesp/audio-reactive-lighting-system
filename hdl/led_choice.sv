`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../data/X`"
`endif  /* ! SYNTHESIS */

module led_choice
     #(parameter TOTAL_LEDS = 1024, parameter NUM_FACES = 1
      )
    (   input wire   clk, //system clock (100 MHz)
        input wire   rst, //reset in signal
        input wire led_busy,
        input wire led_busy_buffer,
        input wire [$clog2(NUM_FACES)-1:0]face_choice,
        output logic [23:0] grb_data
      );

    localparam WIDTH =32;
    localparam HEIGHT =32;


    //LED IMAGE BRAM FECTHING
    logic [$clog2(NUM_FACES*TOTAL_LEDS)-1:0] led_pixel_addr;
    logic [$clog2(NUM_FACES*TOTAL_LEDS)-1:0] led_image_addr_offset;
    logic [$clog2(NUM_FACES*TOTAL_LEDS)-1:0] led_image_addr;



    evt_counter #(.MAX_COUNT(TOTAL_LEDS))evt_test_layout_led(
        .clk(clk),
        .rst(rst),
        // .evt((led_busy&!led_busy_buffer)&&!all_led_lit), //increment everytime you start sending GRB value
        .evt((led_busy&!led_busy_buffer)),
        .count(led_pixel_addr)
    );

    always_comb begin
        case(face_choice)
            0:begin
                led_image_addr_offset = 0;
            end

            1:begin
                led_image_addr_offset = 1024;
            end
            2:begin
                led_image_addr_offset = 2048;
            end
            3:begin
                led_image_addr_offset = 3072;
            end
            4:begin
                led_image_addr_offset = 4096;
            end

            5:begin
                led_image_addr_offset = 5120;
            end
            6:begin
                led_image_addr_offset = 6144;
            end
            7:begin
                led_image_addr_offset = 7168;
            end
            default:begin
                led_image_addr_offset = 0;
            end
        endcase
    end

    assign led_image_addr = led_pixel_addr + led_image_addr_offset;


    logic [7:0] palette_addr;
    logic [23:0] rgb_data;

     //  Xilinx Single Port Read First RAM
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(8),                       // Specify RAM data width
    .RAM_DEPTH(WIDTH*HEIGHT*NUM_FACES),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
    .INIT_FILE(`FPATH(image.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) img_mem (
    .addra(led_image_addr),     // Address bus, width determined from RAM_DEPTH
    .dina(0),       // RAM input data, width determined from RAM_WIDTH
    .clka(clk),       // Clock
    .wea(0),         // Write enable
    .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst),       // Output reset (does not affect memory contents)
    .regcea(1),   // Output register enable
    .douta(palette_addr)      // RAM output data, width determined from RAM_WIDTH
  );


      xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(24),                       // Specify RAM data width
    .RAM_DEPTH(256),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY"
    .INIT_FILE(`FPATH(palette.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) palette_mem (
    .addra(palette_addr),     // Address bus, width determined from RAM_DEPTH
    .dina(0),       // RAM input data, width determined from RAM_WIDTH
    .clka(clk),       // Clock
    .wea(0),         // Write enable
    .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst),       // Output reset (does not affect memory contents)
    .regcea(1),   // Output register enable
    .douta(rgb_data)      // RAM output data, width determined from RAM_WIDTH
  );

    assign grb_data = {rgb_data[15:8], rgb_data[23:16], rgb_data[7:0]};





endmodule
`default_nettype wire
