import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, with_timeout
import random
from pathlib import Path
import math
import struct

proj_path = Path(__file__).resolve().parents[1].parent
SOURCES = [
    proj_path / "hdl" / "line_buffer.sv", # @ KEVIN 
]
TOPLEVEL = "line_buffer" # @ KEVIN
PARAMS = {"HRES":5, "VRES":5} # @ KEVIN
BUILD_ARGS = ["-Wall"]
TIMESCALE = ("1ns", "1ps")
SIM_ARGS = []



@cocotb.test()
async def basic_test(dut):
    pass