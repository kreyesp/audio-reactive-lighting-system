import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, with_timeout
import random
from pathlib import Path
import math
import struct

proj_path = Path(__file__).resolve().parents[1].parent
SOURCES = [
    proj_path / "hdl" / "butterfly.sv", # @ KEVIN 
]
TOPLEVEL = "butterfly" # @ KEVIN
PARAMS = {} # @ KEVIN
BUILD_ARGS = ["-Wall"]
TIMESCALE = ("1ns", "1ps")
SIM_ARGS = []

DATA_WIDTH = 24
DATA_FRAC_BITS = 16
TWIDDLE_WIDTH = 12
TWIDDLE_FRAC_BITS = 10

NUM_TESTS = 100000

class ButterflyTest():
    def __init__(self, a, b, w, expected1, expected2, out1, out2):
        self.a = a
        self.b = b
        self.w = w
        self.expected1 = expected1
        self.expected2 = expected2
        self.out1 = out1
        self.out2 = out2

    def __str__(self):
        return f"Input values A: {self.a}, B: {self.b} W: {self.w} \n Expected: {self.expected1}, {self.expected2}. \n Received {self.out1}, {self.out2}"

def get_random_complex(width, frac_bits):
    int_bits = width - frac_bits

    max_val = (2**(int_bits - 1)) - 1
    min_val = -(2**(int_bits - 1))

    a = random.uniform(min_val, max_val)
    b = random.uniform(min_val, max_val)

    return complex(a, b)

def butterfly(complex_a, complex_b, twiddle):
    top = complex_a + (twiddle * complex_b)
    bottom = complex_a - (twiddle * complex_b)

    return top, bottom

def get_random_twiddle(N=512):
    k = random.randint(0, N-1)
    theta = 2 * math.pi * k / (N)
    return complex(math.cos(theta), -math.sin(theta))

def float_to_fixed(num, width, frac_bits):
    fixed = int(round(num * (2**frac_bits)))
    return fixed & ((1 << width) - 1)

def fixed_to_float(num, width, frac_bits):
    if (num & (1 << (width - 1))):
        num -= (1 << width)
    return num / (2**frac_bits)

def check_tolerance(actual, expected, tolerance, small_delta):
    error = abs(actual - expected)
    denom = max(abs(expected), 1e-6)
    return (error/denom < tolerance) or (abs(actual - expected) < small_delta)

def clamp_value(num, max, min):
    if num > max:
        return max
    elif num < min:
        return min
    else:
        return num

def clamp_complex(c, width, frac_bits):
    int_bits = width - frac_bits

    max_val = 2**(int_bits - 1) - 2**(-16)
    min_val = -(2**(int_bits - 1))

    complex_re = clamp_value(c.real, max_val, min_val)
    complex_im = clamp_value(c.imag, max_val, min_val)

    return complex(complex_re, complex_im)


@cocotb.test()
async def basic_test(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    dut.rst.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 1)

    failed_tests = []
    passed_tests = 0

    for i in range(NUM_TESTS):
        A = get_random_complex(DATA_WIDTH, DATA_FRAC_BITS)
        B = get_random_complex(DATA_WIDTH, DATA_FRAC_BITS)
        W = get_random_twiddle()

        dut.input_1_re.value = float_to_fixed(A.real, DATA_WIDTH, DATA_FRAC_BITS)
        dut.input_1_im.value = float_to_fixed(A.imag, DATA_WIDTH, DATA_FRAC_BITS)
        dut.input_2_re.value = float_to_fixed(B.real, DATA_WIDTH, DATA_FRAC_BITS)
        dut.input_2_im.value = float_to_fixed(B.imag, DATA_WIDTH, DATA_FRAC_BITS)
        dut.twiddle_re.value = float_to_fixed(W.real, TWIDDLE_WIDTH, TWIDDLE_FRAC_BITS)
        dut.twiddle_im.value = float_to_fixed(W.imag, TWIDDLE_WIDTH, TWIDDLE_FRAC_BITS)
        dut.data_in_valid.value = 1

        await RisingEdge(dut.clk)

        dut.data_in_valid.value = 0
        await RisingEdge(dut.clk)

        expected1, expected2 = butterfly(A, B, W)

        expected1 = clamp_complex(expected1, DATA_WIDTH, DATA_FRAC_BITS)
        expected2 = clamp_complex(expected2, DATA_WIDTH, DATA_FRAC_BITS)

        out1 = complex(
            fixed_to_float(int(dut.output_1_re.value), DATA_WIDTH, DATA_FRAC_BITS),
            fixed_to_float(int(dut.output_1_im.value), DATA_WIDTH, DATA_FRAC_BITS)
        )
        out2 = complex(
            fixed_to_float(int(dut.output_2_re.value), DATA_WIDTH, DATA_FRAC_BITS),
            fixed_to_float(int(dut.output_2_im.value), DATA_WIDTH, DATA_FRAC_BITS)
        )

        out1_valid = check_tolerance(out1, expected1, .05, .2)
        out2_valid = check_tolerance(out2, expected2, .05, .2)

        if (out1_valid and out2_valid):
            passed_tests += 1
        else:
            dut._log.info("")
            dut._log.info(f"{"-"*50}")
            dut._log.info(f"Test #{i}")
            dut._log.info(f"Inputs:")
            dut._log.info(f"  A = {A}")
            dut._log.info(f"  B = {B}")
            dut._log.info(f"  W = {W}")
            dut._log.info("")
            dut._log.info(f"Expected: {expected1}, {expected2}")
            dut._log.info(f"Got:      {out1}, {out2}")
            dut._log.info("")
            failed_tests.append(ButterflyTest(
                a=A,
                b=B,
                w=W,
                expected1=expected1,
                expected2=expected2,
                out1=out1,
                out2=out2
            ).__str__())
            # assert False, "STOPPED HERE TO CHECK FST"
    
    dut._log.info(f"Passed {passed_tests}/{NUM_TESTS} tests")

    assert passed_tests == NUM_TESTS, "Did not pass every test"