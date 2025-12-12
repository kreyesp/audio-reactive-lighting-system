import cocotb
import os
import random
import sys
import math
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
from PIL import Image
import numpy as np
test_file = os.path.basename(__file__).replace(".py","")

# utility function to reverse bits:
def reverse_bits(n,size):
    reversed_n = 0
    for i in range(size):
        reversed_n = (reversed_n << 1) | (n & 1)
        n >>= 1
    return reversed_n

grb_words = [
    0x00FF00,  # (255, 0, 0)   red
    0xFF0000,  # (0, 255, 0)   green
    0x0000FF,  # (0, 0, 255)   blue
    0xFFFF00,  # (255, 255, 0) yellow
    0xFF00FF,  # (0, 255, 255) cyan
    0x00FFFF,  # (255, 0, 255) magenta
    0xFFFFFF,  # (255, 255, 255) white
    0x000000,  # (0, 0, 0)     black

    0x008000,  # (128, 0, 0)   dark red
    0x800000,  # (0, 128, 0)   dark green
    0x000080,  # (0, 0, 128)   dark blue
    0x808000,  # (128, 128, 0)
    0x800080,  # (0, 128, 128)
    0x008080,  # (128, 0, 128)

    0x404040,  # (64, 64, 64)  dark gray
    0xC0C0C0,  # (192, 192, 192) light gray

    0x80FF00,  # (255, 128, 0) orange-ish
    0x408000,  # (128, 64, 0)  brown-ish
    0x004040,  # (64, 0, 64)
    0x400040,  # (0, 64, 64)
    0x404000,  # (64, 64, 0)
    0x400000,  # (0, 64, 0)
    0x004000,  # (64, 0, 0)
    0x000040,  # (0, 0, 64)
]

def grb_to_rgb(word):
    g = (word >> 16) & 0xFF
    r = (word >> 8)  & 0xFF
    b =  word        & 0xFF
    return (r, g, b)


@cocotb.test()
async def test_sending_to_24_LED(dut):
    """Compare with preset rgb values"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.rst.value = 1
    await ClockCycles(dut.clk, 3) #wait three clock cycles
    dut.rst.value = 0
    await ClockCycles(dut.clk, 1) #wait three clock cycles



    words_received = []



    for word in grb_words:

        while dut.busy.value == 1:
            await ClockCycles(dut.clk, 1)

        print(f'current word being transmitted: {word}')
        bit_sent = 0
        dut.data_in.value = word
        dut.data_in_valid.value   = 1
        await ClockCycles(dut.clk, 1)
        dut.data_in_valid.value   = 0

        while dut.busy.value == 0:
            await ClockCycles(dut.clk, 1)

        # print(dut.busy.value)
        word_received = ""


        while (dut.busy.value == 1):
            await ClockCycles(dut.clk, 1)

            if(dut.cycles.value==51 and dut.state.value !=3):
                if(dut.data_out.value == 0):
                    bit_sent=0
                else:
                    bit_sent = 1

                word_received += f"{bit_sent}"

        assert len(word_received) == 24, f"Expected 24 bits, got {len(word_received)}"

        print(f'current word being received: {(word_received)}')


        words_received.append(word_received)

    for i in range(len(words_received)):
        words_received[i] = int(words_received[i], 2)


    colors = [grb_to_rgb(word) for word in words_received]
    width, height = len(colors), 1


    img = Image.new("RGB", (width, height))
    img.putdata(colors)
    img.save("words_received_strip.png")
    print(colors)






def led_control_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "led_control.sv"]
    build_test_args = ["-Wall"]
    parameters = {'TOTAL_LEDS': 24} #!!!change these to do different versions
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "led_control"
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module=test_file,
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    led_control_runner()
