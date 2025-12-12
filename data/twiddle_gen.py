import numpy as np

POINTS = 512
TWIDDLE_WIDTH = 5
TWIDDLE_FRAC_BITS = 3

def float_to_fixed(num, width, frac_bits):
    fixed = int(round(num * (2**frac_bits)))
    return fixed & ((1 << width) - 1)

def gen_twiddle_rom(N=POINTS, width=TWIDDLE_WIDTH, frac_bits=TWIDDLE_FRAC_BITS, outfile="twiddle_rom.mem"):
    entries = []

    for k in range(N//2):
        angle = -2 * np.pi * k / N
        w = np.exp(1j * angle)

        re = float_to_fixed(w.real, width, frac_bits)
        im = float_to_fixed(w.imag, width, frac_bits)

        packed = (re << width) | im
        hex_str = f"{packed:0{(2*width+3)//4}x}"
        entries.append(hex_str)

    with open(outfile, "w") as f:
        for e in entries:
            f.write(e + "\n")

    print(f"Generated {outfile} with {len(entries)} entries.")

# Example
gen_twiddle_rom()
