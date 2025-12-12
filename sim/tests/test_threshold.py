import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, with_timeout
import random
from pathlib import Path
import math
import struct

proj_path = Path(__file__).resolve().parents[1].parent
SOURCES = [
    proj_path / "hdl" / "threshold_module.sv", # @ KEVIN 
]
TOPLEVEL = "threshold" # @ KEVIN
PARAMS = {} # @ KEVIN
BUILD_ARGS = ["-Wall"]
TIMESCALE = ("1ns", "1ps")
SIM_ARGS = []

NUM_TESTS = 10000

@cocotb.test()
async def basic_test(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.rst.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0

    dut.low_threshold.value = 1073741823
    dut.mid_threshold.value = 1073741823
    dut.high_threshold.value = 1073741823

    await RisingEdge(dut.clk)

    for i in range(NUM_TESTS):
        dut.lows.value = int(random.uniform(0, 4294967296))
        dut.mids.value = int(random.uniform(0, 4294967296))
        dut.highs.value = int(random.uniform(0, 4294967296))

        await RisingEdge(dut.clk)

        output_low = dut.low_valid.value
        output_mid = dut.mid_valid.value
        output_high = dut.high_valid.value
        face = dut.face_state.value

        dut._log.info(f"{output_low}, {output_mid}, {output_high}")
        dut._log.info(f"Face State: {face}")