import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, with_timeout
import random
from pathlib import Path
import math
import struct

proj_path = Path(__file__).resolve().parents[1].parent
SOURCES = [
    proj_path / "hdl" / "butterfly.sv",
    proj_path / "hdl" / "fft_core.sv",
    proj_path / "hdl" / "xilinx_single_port_ram_read_first.v",
    proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v"
]

TOPLEVEL = "fft_core"
PARAMS = {"DEBUG_LOAD": 1}
BUILD_ARGS = ["-Wall"]
TIMESCALE = ("1ns", "1ps")
SIM_ARGS = []

POINTS = 512
STAGES = 9
DATA_WIDTH = 24
DATA_FRAC_BITS = 16

# Checks if load is correct

def reverse_bits(n, length):
    binary = bin(n)
    reverse = binary[-1:1:-1]
    reverse = reverse + (length - len(reverse))*'0'
    return int(reverse, 2)

@cocotb.test()
async def basic_test(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 1)

    dut.start_fft.value = 1
    await RisingEdge(dut.clk)
    dut.start_fft.value = 0

    while dut.load_read_en.value == 0:
        await RisingEdge(dut.clk)


    for i in range(POINTS):
        sample_val = reverse_bits(i, STAGES)
        dut.input_data_re.value = sample_val
        dut.input_data_im.value = sample_val
        dut.input_data_valid.value = 1
        await RisingEdge(dut.clk)

    dut.input_data_valid.value = 0
    
    await ClockCycles(dut.clk, 5)

    errors = 0
    for addr in range(POINTS-200):
        dut.read_addr.value = addr
        await ClockCycles(dut.clk, 3)

        read_re = dut.read_data_re.value
        
        expected = addr
        if read_re != expected:
            cocotb.log.error(f"Addr {addr}: got {read_re}, expected {expected}")
            errors += 1
    
    assert errors == 0, f"{errors} Errors"