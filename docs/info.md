# StreamDot-4 specification

StreamDot-4 is a time-multiplexed signed dot-product accelerator for a single
IHP SG13G2 Tiny Tapeout 1x1 tile. It deliberately uses one reusable 4-bit
multiplier instead of a parallel processing-element array.

## Arithmetic

Operands are signed two's-complement values in the range -8 through +7:

```text
ui_in[3:0] = A
ui_in[7:4] = B
```

Each accepted operation computes `A*B` and adds it to a signed 12-bit
accumulator. The accumulator saturates at -2048 and +2047. Saturation sets a
sticky overflow flag until reset or clear.

## Modes

In dot-product mode (`uio_in[4] = 0`), `CLEAR` starts a new vector. The next
four valid products are accepted as terms 0 through 3. The fourth term sets
`DONE`; further valid pulses are ignored until another clear.

In continuous mode (`uio_in[4] = 1`), every valid product is accepted until
clear. This mode supports longer FIR filters, sensor fusion sequences, and
software-controlled MAC loops.

Control inputs:

- `uio_in[0]`: `VALID`; sample and accumulate on the rising clock edge
- `uio_in[1]`: `CLEAR`; clear accumulator, term count, done, and overflow
- `uio_in[3:2]`: output page select
- `uio_in[4]`: continuous mode
- `uio_in[7:5]`: activation/output mode

`uio_oe` is always zero. All bidirectional pads are inputs, preventing output
contention with the host board.

## Output pages

The selected page is presented on `uo_out`:

- page 0: activation-mode output derived from the accumulator
- page 1: accumulator bits `[11:8]` in `uo_out[3:0]`
- page 2: sticky overflow in `uo_out[0]`
- page 3: accepted pulse in `uo_out[0]`, ready in `uo_out[1]`, `DONE` in
  `uo_out[2]`, and the current term count in `uo_out[4:3]`

`uio_out` is tied low because the bidirectional pins are input-only.

Activation modes for page 0 are:

- `000`: raw signed accumulator low byte
- `001`: ReLU (`max(accumulator, 0)`)
- `010`: absolute value
- `011`: positive threshold classifier (`1` when accumulator is positive)
- `100`: signed 8-bit clamp to `[-128, 127]`
- `101`: sign mask (`0xff` for negative, otherwise `0x00`)

This makes the block directly usable as a small neural-network activation
engine, a four-tap FIR/filter primitive, or a sensor-feature classifier.

## Verification and limits

The cocotb model checks all signed operand combinations, four-term dot
products, ignored post-DONE operations, continuous mode, reset, enable, clear
priority, and positive/negative saturation. Passing simulation is necessary but
not sufficient for silicon. The Tiny Tapeout IHP130 flow must also pass
synthesis, placement, routing, STA, DRC, LVS, and project-level checks.
