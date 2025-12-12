import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import numpy as np
from pathlib import Path
from fxpmath import Fxp
import matplotlib.pyplot as plt

proj_path = Path(__file__).resolve().parents[1].parent
SOURCES = [
    proj_path / "hdl" / "frame_buffer.sv",
    proj_path / "hdl" / "xilinx_true_dual_port_read_first_1_clock_ram.v"
]

TOPLEVEL = "frame_buffer"
PARAMS = {}
BUILD_ARGS = ["-Wall"]
TIMESCALE = ("1ns", "1ps")
SIM_ARGS = []

@cocotb.test()
async def test_frame_buffer(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    dut.rst.value = 1
    dut.input_valid.value = 0
    dut.input_data.value = 0
    dut.read_request.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 5)

    for i in range(512):
        dut.input_valid.value = 1
        dut.input_data.value = i
        await RisingEdge(dut.clk)

    dut.input_valid.value = 0

    # Wait for frame_ready
    while dut.frame_ready.value == 0:
        await RisingEdge(dut.clk)

    received_1 = []

    for _ in range(512):
        dut.read_request.value = 1
        await RisingEdge(dut.clk)

        if dut.data_out_valid.value == 1:
            received_1.append(int(dut.audio_data_out.value))

    dut.read_request.value = 0

    # Drain pipeline
    for _ in range(5):
        await RisingEdge(dut.clk)
        if dut.data_out_valid.value == 1:
            received_1.append(int(dut.audio_data_out.value))


    assert len(received_1) == 512, f"Expected 512 outputs, got {len(received_1)}"
    assert received_1[:10] == list(range(0, 10)), "First samples incorrect"
    assert received_1[-10:] == list(range(502, 512)), "Last samples incorrect"

    for i in range(1000, 1000 + 512):
        dut.input_valid.value = 1
        dut.input_data.value = i
        await RisingEdge(dut.clk)

    dut.input_valid.value = 0

    # Wait for next frame_ready
    while dut.frame_ready.value == 0:
        await RisingEdge(dut.clk)

    received_2 = []

    for _ in range(512):
        dut.read_request.value = 1
        await RisingEdge(dut.clk)

        if dut.data_out_valid.value == 1:
            received_2.append(int(dut.audio_data_out.value))

    dut.read_request.value = 0

    # Drain latency
    for _ in range(5):
        await RisingEdge(dut.clk)
        if dut.data_out_valid.value == 1:
            received_2.append(int(dut.audio_data_out.value))

    assert len(received_2) == 512, f"Expected 512 outputs in frame 2, got {len(received_2)}"
    assert received_2[:10] == list(range(1000, 1010)), "Second frame first samples wrong"
    assert received_2[-10:] == list(range(1000 + 502, 1000 + 512)), "Second frame last samples wrong"

    print("FIRST FRAME OK:")
    print(received_1[:10], "...", received_1[-10:])
    print("SECOND FRAME OK:")
    print(received_2[:10], "...", received_2[-10:])
