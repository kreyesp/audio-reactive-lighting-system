import cocotb
import os
import random
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
test_file = os.path.basename(__file__).replace(".py","")

# utility function to reverse bits:
def reverse_bits(n,size):
    reversed_n = 0
    for i in range(size):
        reversed_n = (reversed_n << 1) | (n & 1)
        n >>= 1
    return reversed_n

async def high_sck(dut, half_cycle = 3):
    dut.sck.value = 1
    await ClockCycles(dut.clk, half_cycle) #wait three clock cycles


async def low_sck(dut, half_cycle = 3):
    dut.sck.value = 0
    await ClockCycles(dut.clk, half_cycle) #wait three clock cycles



@cocotb.test()
async def test_left_channel_works(dut):
    """Test to see if left channel receives 0x6B"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.sck.value = 0
    dut.ws.value = 0
    dut.rst.value = 1
    await ClockCycles(dut.clk, 3) #wait three clock cycles
    dut.rst.value = 0
    await ClockCycles(dut.clk, 3) #wait three clock cycles


    dut.sck.value = 1
    dut.ws.value = 0
    input_data = 0x6B
    bits_input = 0


    #starting on 0 sck
    for i in range(18):
        await high_sck(dut)
        if(bits_input==6):
            dut.ws.value = 1
        dut.data_in.value = (input_data>>7)&1
        input_data = input_data<<1
        bits_input+=1
        await low_sck(dut)


@cocotb.test()
async def test_right_channel_works(dut):
    """Test to see if right channel receives 0x7A"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.sck.value = 0
    dut.ws.value = 1
    dut.rst.value = 1
    await ClockCycles(dut.clk, 3) #wait three clock cycles
    dut.rst.value = 0
    await ClockCycles(dut.clk, 3) #wait three clock cycles

    dut.sck.value = 0
    dut.ws.value = 1
    input_data = 0x7A
    bits_input = 0

    #starting on 0 sck
    for i in range(18):
        await high_sck(dut)
        # await low_sck(dut)
        if(bits_input==6):
            dut.ws.value = 0
        dut.data_in.value = (input_data>>7)&1
        input_data = input_data<<1
        bits_input+=1
        # await high_sck(dut)
        await low_sck(dut)




@cocotb.test()
async def test_sending_both_channels_works(dut):
    """Test to see if left channel receives 0x6B in left then 0x7A in right"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.sck.value = 0
    dut.ws.value = 0
    dut.rst.value = 1
    await ClockCycles(dut.clk, 3) #wait three clock cycles
    dut.rst.value = 0
    await ClockCycles(dut.clk, 3) #wait three clock cycles

    dut.sck.value = 0
    dut.ws.value = 0
    input_data = 0x6B
    bits_input = 0

    #starting on 0 sck
    for i in range(8):
        await high_sck(dut)
        # await low_sck(dut)
        if(bits_input==6):
            dut.ws.value = 1
        dut.data_in.value = (input_data>>7)&1
        input_data = input_data<<1
        bits_input+=1
        # await high_sck(dut)
        await low_sck(dut)




    input_data = 0x7A
    bits_input = 0
    #starting on 0 sck
    for i in range(8):
        await high_sck(dut)
        # await low_sck(dut)
        if(bits_input==6):
            dut.ws.value = 0
        dut.data_in.value = (input_data>>7)&1
        input_data = input_data<<1
        bits_input+=1
        # await high_sck(dut)
        await low_sck(dut)



@cocotb.test()
async def test_sending_left_and_right_twice(dut):
    """Test to see if left channel receives 0x6B in left then 0x7A in right then 0x08 in left and 0x14 in right"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.sck.value = 0
    dut.ws.value = 0
    dut.rst.value = 1
    await ClockCycles(dut.clk, 3) #wait three clock cycles
    dut.rst.value = 0
    await ClockCycles(dut.clk, 3) #wait three clock cycles

    dut.sck.value = 0
    dut.ws.value = 0
    input_data = 0x6B
    bits_input = 0

    #starting on 0 sck
    for i in range(8):
        await high_sck(dut)
        # await low_sck(dut)
        if(bits_input==6):
            dut.ws.value = 1
        dut.data_in.value = (input_data>>7)&1
        input_data = input_data<<1
        bits_input+=1
        # await high_sck(dut)
        await low_sck(dut)




    input_data = 0x7A
    bits_input = 0
    #starting on 0 sck
    for i in range(8):
        await high_sck(dut)
        # await low_sck(dut)
        if(bits_input==6):
            dut.ws.value = 0
        dut.data_in.value = (input_data>>7)&1
        input_data = input_data<<1
        bits_input+=1
        # await high_sck(dut)
        await low_sck(dut)


    input_data = 0x08
    bits_input = 0
    #starting on 0 sck
    for i in range(8):
        await high_sck(dut)
        # await low_sck(dut)
        if(bits_input==6):
            dut.ws.value = 1
        dut.data_in.value = (input_data>>7)&1
        input_data = input_data<<1
        bits_input+=1
        # await high_sck(dut)
        await low_sck(dut)


    input_data = 0x14
    bits_input = 0
    #starting on 0 sck
    for i in range(8):
        await high_sck(dut)
        # await low_sck(dut)
        if(bits_input==6):
            dut.ws.value = 0
        dut.data_in.value = (input_data>>7)&1
        input_data = input_data<<1
        bits_input+=1
        # await high_sck(dut)
        await low_sck(dut)



def i2s_receiver_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "i2s_receiver.sv"]
    build_test_args = ["-Wall"]
    parameters = {'DATA_WIDTH': 8} #!!!change these to do different versions
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "i2s_receiver"
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
    i2s_receiver_runner()
