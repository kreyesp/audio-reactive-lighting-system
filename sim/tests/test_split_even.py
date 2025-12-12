import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, with_timeout
import random
from pathlib import Path
import math
import struct

proj_path = Path(__file__).resolve().parents[1].parent
SOURCES = [
    proj_path / "hdl" / "split_even.sv", # @ KEVIN 
]
TOPLEVEL = "split_even" # @ KEVIN
PARAMS = {} # @ KEVIN
BUILD_ARGS = ["-Wall"]
TIMESCALE = ("1ns", "1ps")
SIM_ARGS = []

@cocotb.test()
async def basic_test(dut):
    test_array = [1, 2, 3, 4]

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    dut.rst.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 1)

    dut.data.value = test_array

    await ClockCycles(dut.clk, 1)

    evens = dut.evens.value
    odds = dut.odds.value

    assert evens == [2, 4], "Does not return correct evens"
    assert odds == [1, 3], "Does not return correct odds"




