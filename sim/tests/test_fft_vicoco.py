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
from vicoco.vivado_runner import get_runner
from pathlib import Path
from fxpmath import Fxp
import matplotlib.pyplot as plt
import numpy as np

test_file = os.path.basename(__file__).replace(".py","")

POINTS = 512
DATA_WIDTH = 24
DATA_FRAC_BITS = 8

def generate_fxp_sine_wave_samples(frequency_hz, duration_s, sampling_rate_hz=44100, amplitude=1):
    DATA_WIDTH = 24       # Total bits
    DATA_FRAC_BITS = 8    # Fractional bits

    POINTS = int(sampling_rate_hz * duration_s)
    
    t = np.linspace(0., duration_s, POINTS, endpoint=False)
    val_floats = np.sin(2. * np.pi * frequency_hz * t) * amplitude

    samples_fxp = [Fxp(val, True, DATA_WIDTH, DATA_FRAC_BITS) for val in val_floats]
        
    return samples_fxp

samples = generate_fxp_sine_wave_samples(360, 1, 48000, 4)



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

    low_mag = int(dut.low_magnitude.value) / (2**DATA_FRAC_BITS)
    mid_mag = int(dut.mid_magnitude.value) / (2**DATA_FRAC_BITS)
    high_mag = int(dut.high_magnitude.value) / (2**DATA_FRAC_BITS)

    out = []

    for addr in range(POINTS):
        dut.read_addr.value = addr
        await ClockCycles(dut.clk, 5)
        if (dut.read_data_re.value == "xxxxxxxxxxxxxxxxxxxxxxxx"):
            dut._log.info(f"Addr: {addr}, out_re: {dut.read_data_re.value}, out_im: {dut.read_data_im.value}")
        out.append(complex(fixed_to_float(dut.read_data_re.value), fixed_to_float(dut.read_data_im.value)))
    input_signal = np.array([float(s) for s in samples], dtype=float)
    expected_fft = np.fft.fft(input_signal, 512)
    dut._log.info(f"{out}")
    dut._log.info(f"===================================")
    dut._log.info(f"Expected 1: {expected_fft[1]} Expected 137: {expected_fft[137]}")

    dut._log.info(f"Bin 0: {out[0]}")
    dut._log.info(f"Bin 1: {out[1]}")
    dut._log.info(f"Bin 17: {out[17]}")
    dut._log.info(f"Bin 63: {out[63]}")
    dut._log.info(f"Bin 511: {out[511]}")
    dut._log.info(f"Bin 510: {out[510]}")
    dut._log.info(f"Expected Bin 1: {expected_fft[1]}")
    dut._log.info(f"Expected Bin 511: {expected_fft[511]}")


    magnitudes_rec = np.abs(out)
    magnitudes_exp = np.abs(expected_fft)

    expected_low = np.sum(magnitudes_exp[1:6])
    expected_mid = np.sum(magnitudes_exp[6:41])
    expected_high = np.sum(magnitudes_exp[41:101])

    dut._log.info(f"Expected LOW: {expected_low}, MID: {expected_mid}, HIGH: {expected_high}")
    dut._log.info(f"Received LOW: {low_mag}, MID: {mid_mag}, HIGH: {high_mag}")

    plt.figure(figsize=(12, 5))

    plt.subplot(1, 2, 1)
    plt.plot(magnitudes_rec)
    plt.title('Received FFT Magnitude')
    plt.xlabel('Bin')
    plt.ylabel('Magnitude')

    plt.subplot(1, 2, 2)
    plt.plot(magnitudes_exp)
    plt.title('Expected FFT Magnitude')
    plt.xlabel('Bin')
    plt.ylabel('Magnitude')

    plt.tight_layout()
    plt.savefig('fft_output.png')
    plt.show()


def i2s_receiver_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "vivado")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "fft_core.sv",
    proj_path / "hdl" / "fft_core.sv",
    proj_path / "hdl" / "xilinx_single_port_ram_read_first.v",
    proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v"]
    build_test_args = ["-Wall"]
    parameters = {} #!!!change these to do different versions
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "fft_core"
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
