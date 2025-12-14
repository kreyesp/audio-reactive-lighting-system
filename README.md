# CAROL — Configurable Audio Reactive Output LEDs (FPGA)

Real-time **audio → visual** system on FPGA: takes a **48 kHz stereo** audio stream over I2S, passes audio through to DAC, and simultaneously drives:
- **WS2812B LED panel “face” animations**
- **HDMI waveform + frequency bars** with user-adjustable thresholds

> **Authorship note (FFT):** the FFT core in this repo was authored by my project partner.  
> I was responsible for **system architecture + integration**, **clocking**, **I2S RX/TX**, **LED + HDMI pipelines**, and some **verification/bring-up**.

<p align="center">
<img width="300" height="300" alt="image" src="https://github.com/user-attachments/assets/200544b1-62f7-4a51-bd93-6ed44e571ed2" />
     &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
<img width="300" height="300" alt="monitor_display" src="https://github.com/user-attachments/assets/fc09bf89-40ea-4b89-b701-1d0e0c1cf3a3" />
</p>
<p align="center"><i>Left: LED output. Right: HDMI visualization.</i></p>

---

## Highlights
- **48 kHz stereo I2S ADC/DAC**, 24-bit samples + audio pass-through
- **Single-clock compute domain**: generated **98.304 MHz** system clock (2048 × 48 kHz) to meet audio timing and reduce CDC complexity
- LED output: **4 × 8×32 WS2812B panels** for expressive animations
- HDMI output: live **waveform** + **frequency bars**, with user-controlled thresholds
- **Verification**: cocotb testbenches (NumPy) + hardware validation with a logic analyzer

---

## Hardware
- **FPGA board:** AMD Urbana (Spartan-7)
- **Audio I/O:** Digilent **Pmod I2S2 (Rev A)** (Cirrus **CS5343** ADC + **CS4344** DAC)
- **LEDs:** WS2812B LED panels (4 × 8×32)
- **Display:** HDMI monitor

---

## System Overview
<p align="center">
<img width="1601" height="801" alt="image" src="https://github.com/user-attachments/assets/1a56e1da-ceb8-449a-b782-94649add6d7e" />
</p>

### Dataflow (high-level)
1. **I2S RX** captures 48 kHz stereo 24-bit samples into a frame buffer
2. **FFT (partner-authored)** generates magnitudes / spectral features
3. Spectral features are accumulated into bands (low/mid/high) to drive:
   - **Face expression state machine** (LED panels)
   - **HDMI visualization** (waveform + bars)
4. **I2S TX** outputs the original audio stream (pass-through)

### Clocking
- Main compute domain runs at **98.304 MHz** (derived via Clock Wizard)
- Generates required audio clocks (e.g., MCLK) from the same domain where needed
- HDMI pixel clock runs in a separate domain; display data is transferred using a
  **ping-pong BRAM** approach for stability across domains

---

## Repo Layout
- `hdl/` — RTL (SystemVerilog/Verilog): I2S, LED driver, HDMI pipeline, top-level integration
- `xdc/` — pin/clock constraints
- `data/` — `.mem` files (images/patterns, LUTs, etc.)
- `sim/` — cocotb-based verification
- `util/` — helper scripts/tools
- `led_bit_files/` — prebuilt testing bitstreams / programming artifacts (if included)

---

### Requirements
- Xilinx **Vivado**
- Project uses `build.tcl` to synthesize/implement and emit a bitstream
