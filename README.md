# StreamDot-4 — IHP130 Tiny Tapeout Dot-Product Accelerator

StreamDot-4 is a compact, standalone digital accelerator for the IHP SG13G2
130 nm Tiny Tapeout shuttle. It reuses one signed 4-bit multiplier and a
12-bit saturating accumulator, then provides selectable activation functions
for edge-AI and DSP workloads.

In its default mode, four accepted products form one complete dot product:

```text
Y = A0*B0 + A1*B1 + A2*B2 + A3*B3
```

After the fourth term, `DONE` asserts and additional terms are ignored until
`CLEAR`. A continuous mode is also provided for longer FIR/DSP-style MAC
sequences. The remaining bidirectional input pins select raw, ReLU, absolute,
threshold, and signed-clamp output modes.

## Project files

- `src/project.v` — synthesizable `tt_um_streamdot4` top module
- `test/test.py` — cocotb verification
- `test/Makefile` — local simulator entry point
- `info.yaml` — Tiny Tapeout metadata and pinout
- `docs/info.md` — detailed protocol and verification documentation

## Verification

The cocotb testbench exhaustively tests all 256 signed 4-bit products and also
checks four-term dot products, completion locking, continuous accumulation,
reset, enable gating, clear priority, and both saturation directions.

Run locally from `test/` with:

```text
make
```

The IHP130 Tiny Tapeout hardening flow must pass before submission. Cocotb
cannot prove final silicon timing, area, power, DRC, LVS, or pad behavior.
