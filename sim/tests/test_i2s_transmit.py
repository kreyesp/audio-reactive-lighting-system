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

#tests receiving on rising edges, not falling

@cocotb.test()
async def test_sending_info_works(dut):
    """Test to see if can transmit 0x6D on left and 0xB5 on right, also make sure no data can be input when invalid data is put in or busy"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.sck.value = 0
    dut.ws.value = 0
    dut.rst.value = 1
    await ClockCycles(dut.clk, 3) #wait three clock cycles
    dut.rst.value = 0
    await ClockCycles(dut.clk, 3) #wait three clock cycles
    #input valid data
    dut.din_valid.value = 1
    dut.din.value = 0xAD6D6EAD6D6E

    #check to see can't input invalid data
    await ClockCycles(dut.clk, 1)
    dut.din_valid.value = 0
    dut.din.value = 0xABCD

    #check to see can't input data when busy
    await ClockCycles(dut.clk, 32)
    dut.din_valid.value = 1
    dut.din.value = 0xFFFF
    await ClockCycles(dut.clk, 32)
    dut.din_valid.value = 0


    for i in range(1800):
        await ClockCycles(dut.clk, 3)


# @cocotb.test()
# async def test_b(dut):
#     """Test to see if can transmit 0x6D on left and 0xB5 on right then sending in 0x5BD2 right after"""
#     dut._log.info("Starting...")
#     cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
#     dut.sck.value = 0
#     dut.ws.value = 0
#     dut.rst.value = 1
#     await ClockCycles(dut.clk, 3) #wait three clock cycles
#     dut.rst.value = 0
#     await ClockCycles(dut.clk, 3) #wait three clock cycles

#     dut.din_valid.value = 1
#     dut.din.value = 0x6DB5
#     await ClockCycles(dut.clk, 32)
#     dut.din_valid.value = 0
#     await ClockCycles(dut.clk, 32)
#     dut.din_valid.value = 1
#     dut.din.value = 0x5BD2



#     for i in range(180):
#         await ClockCycles(dut.clk, 3)

#     dut.din_valid.value = 0

#     for i in range(180):
#         await ClockCycles(dut.clk, 3)




def i2s_transmit_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "i2s_transmit.sv"]
    build_test_args = ["-Wall"]
    parameters = {'DATA_WIDTH': 24} #!!!change these to do different versions
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "i2s_transmit"
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
    i2s_transmit_runner()
