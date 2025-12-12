import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
import numpy as np
from pathlib import Path
from fxpmath import Fxp
import matplotlib.pyplot as plt


proj_path = Path(__file__).resolve().parents[1].parent
SOURCES = [
    proj_path / "hdl" / "butterfly.sv",
    proj_path / "hdl" / "fft_core.sv",
    proj_path / "hdl" / "xilinx_single_port_ram_read_first.v",
    proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v"
]

TOPLEVEL = "fft_core"
PARAMS = {}
BUILD_ARGS = ["-Wall"]
TIMESCALE = ("1ns", "1ps")
SIM_ARGS = []

POINTS = 512
DATA_WIDTH = 24
DATA_FRAC_BITS = 16


# VERY USEFUL FOR SEEING THE LIKE POSITION ERRORS, i == 1 SHOWS 128, 256, etc error
# samples = []
# for i in range(POINTS):
#     if i == 0:
#         val = 1
#     else:
#         val = 0.0
#     val_fxp = Fxp(val, True, DATA_WIDTH, DATA_FRAC_BITS)
#     samples.append(val_fxp)

# samples = []

# for i in range(POINTS):
#     val = np.sin(2 * np.pi * i / POINTS)

#     val_fxp = Fxp(val, True, DATA_WIDTH, DATA_FRAC_BITS)

#     samples.append(val_fxp)

# RANDOM samples

samples = []
for i in range(POINTS):
    val = np.random.uniform(-0.5, 0.5)
    val_fxp = Fxp(val, True, DATA_WIDTH, DATA_FRAC_BITS)
    samples.append(val_fxp)

def fixed_to_float(val, width=24, frac_bits=16):
    if (not val.is_resolvable):
        return 0
    # Mask to width bits first
    val = int(val) & ((1 << width) - 1)
    # Then sign extend
    if (val & (1 << (width - 1))):
        val -= (1 << width)
    return val / (2**frac_bits)

@cocotb.test()
async def basic_test(dut):
    dut.input_data_im.value = 0
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.rst.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 1)
    dut.start_fft.value = 1
    await ClockCycles(dut.clk, 1)
    dut.start_fft.value = 0
    await RisingEdge(dut.load_read_en)
    await ClockCycles(dut.clk, 1)
    current_sample = 0
    while current_sample < POINTS:
        await RisingEdge(dut.clk)
        if dut.load_read_en.value == 1:
            dut.input_data_re.value = int(samples[current_sample].val.item())
            dut.input_data_valid.value = 1
            current_sample += 1
        else:
            dut.input_data_valid.value = 0
    await RisingEdge(dut.clk)
    dut.input_data_valid.value = 0
    # await ClockCycles(dut.clk, 100)
    await RisingEdge(dut.fft_done)
    await ClockCycles(dut.clk, 5)
    out = []

    for addr in range(POINTS):
        dut.read_addr.value = addr
        await ClockCycles(dut.clk, 3)
        if (dut.read_data_re.value == "xxxxxxxxxxxxxxxxxxxxxxxx"):
            dut._log.info(f"Addr: {addr}, out_re: {dut.read_data_re.value}, out_im: {dut.read_data_im.value}")
        out.append(complex(fixed_to_float(dut.read_data_re.value), fixed_to_float(dut.read_data_im.value)))
    input_signal = np.array([float(s) for s in samples], dtype=float)
    expected_fft = np.fft.fft(input_signal, 512)


    magnitudes_rec = np.abs(out)
    magnitudes_exp = np.abs(expected_fft)

    rec_bin_1 = np.sum(magnitudes_rec[0:170])
    rec_bin_2 = np.sum(magnitudes_rec[170:340])
    rec_bin_3 = np.sum(magnitudes_rec[340:512])

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))

    ax1.plot(magnitudes_rec)
    ax1.set_title('Received FFT Magnitude')
    ax1.set_xlabel('Bin')
    ax1.set_ylabel('Magnitude')

    bins = ['Low\n(0-169)', 'Mid\n(170-339)', 'High\n(340-511)']
    values = [rec_bin_1, rec_bin_2, rec_bin_3]
    ax2.bar(bins, values)
    ax2.set_title('Summed Frequency Bands')
    ax2.set_ylabel('Sum of Magnitudes')

    plt.tight_layout()
    plt.show()
    # plt.subplot(1, 2, 1)
    # plt.plot(magnitudes_rec)
    # plt.title('Received FFT Magnitude')
    # plt.xlabel('Bin')
    # plt.ylabel('Magnitude')

    # plt.subplot(1, 2, 2)
    # plt.plot(magnitudes_exp)
    # plt.title('Expected FFT Magnitude')
    # plt.xlabel('Bin')
    # plt.ylabel('Magnitude')

    # plt.tight_layout()
    # plt.savefig('fft_output.png')
    # plt.show()
    
