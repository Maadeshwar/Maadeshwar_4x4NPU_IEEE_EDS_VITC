# 4x4NPU

![Process](https://img.shields.io/badge/Process-IHP%20SG13G2-2455a4)
![Target](https://img.shields.io/badge/Target-Tiny%20Tapeout%201x1-6f42c1)
![Clock](https://img.shields.io/badge/Clock-50%20MHz-0b7285)
![Datapath](https://img.shields.io/badge/Datapath-Dual%20INT4%20MACs-d9480f)
![Verification](https://img.shields.io/badge/RTL%20Verification-Cocotb%203%2F3-2f9e44)
![Controller](https://img.shields.io/badge/Controller-Three--State%20FSM-f08c46)

## Overview

4x4NPU is a compact, host-controlled neural arithmetic accelerator for one
Tiny Tapeout IHP SG13G2 tile. It accepts one signed INT4 activation and two
signed INT4 weights, updates two independent signed 16-bit accumulators in
parallel, and returns quantized INT4 results.

The design is an original RTL implementation of the same small command-driven
accelerator class as TinyNPU4. It uses a compatible low-pin-count control
protocol, but has its own module structure, explicit three-process FSM, and
verification suite.

## What the chip does

Each `MAC` command performs two signed products in parallel:

```text
accumulator_0 = accumulator_0 + activation * weight_0
accumulator_1 = accumulator_1 + activation * weight_1
```

The accumulators saturate at signed 16-bit limits. The host can then select a
lane, apply linear or ReLU quantization with an arithmetic right shift, and
read the result as signed INT4. The host performs model scheduling; the chip
performs deterministic INT4 inference arithmetic.

## Command protocol

Commands are accepted when `uio_in[3]` is high. The three-process controller
uses the following cycle sequence:

```text
IDLE -> EXEC -> DONE -> IDLE
```

| Code | Command | Function |
| ---: | --- | --- |
| 000 | `NOP` | No operation |
| 001 | `CLEAR` | Clear biases, accumulators, result, and overflow |
| 010 | `BIAS_LOW` | Store the low bias nibble for the selected lane |
| 011 | `BIAS_HIGH` | Complete and load the signed INT8 bias |
| 100 | `MAC` | Update both accumulators in parallel |
| 101 | `FINISH_RELU` | ReLU, shift, and signed INT4 saturation |
| 110 | `FINISH_LINEAR` | Shift and signed INT4 saturation |
| 111 | `READ_ACC` | Read one nibble of the selected accumulator |

## Pin use

All 24 Tiny Tapeout pins are assigned:

| Pins | Use |
| --- | --- |
| `ui_in[3:0]` | Signed activation; bit 0 also selects the lane for control commands |
| `ui_in[7:4]` | Lane-0 signed INT4 weight |
| `uio_in[2:0]` | Command code |
| `uio_in[3]` | Command-valid qualifier |
| `uio_in[7:4]` | Lane-1 weight or command parameter |
| `uo_out[3:0]` | Quantized result or accumulator nibble |
| `uo_out[4]` | One-cycle `DONE` indication |
| `uo_out[5]` | Sticky overflow status |
| `uo_out[6]` | Selected accumulator sign |
| `uo_out[7]` | `RESULT_VALID` status |
| `uio_oe` | All zero; bidirectional pins are input-only |

## Verification

The Cocotb regression currently contains three tests:

1. Dual-lane dot-product and full 16-bit accumulator readback.
2. All 256 signed INT4 activation/weight combinations, plus ReLU behavior.
3. Positive saturation, overflow reporting, and asynchronous reset clearing.

Run the regression locally:

```text
cd test
python -m pip install -r requirements.txt
make
```

Verilator lint is also part of the local review process. The repository
contains Tiny Tapeout documentation, IHP SG13G2 configuration, RTL simulation,
FPGA, GDS, precheck, and gate-level workflow definitions.

Passing RTL simulation and lint are necessary evidence, not a guarantee of
manufacturing success. A responsible silicon sign-off additionally requires
successful CI, synthesis, STA, DRC, LVS, extracted or gate-level checks, and
post-fabrication electrical measurements.

## Repository layout

```text
src/                 RTL and IHP SG13G2 configuration
test/                Cocotb regression and simulation wrapper
docs/info.md         Pin-level and functional specification
info.yaml            Tiny Tapeout project metadata
.github/workflows/   Automated Tiny Tapeout and verification workflows
```

## Intended applications

The accelerator is suitable for two-neuron perceptrons, quantized sensor
classification, small dot-product kernels, compact convolution inner loops,
and low-precision DSP-style feature processing. It is intentionally
host-controlled so an RP2040 or similar microcontroller can stream weights,
activations, commands, and result reads over a simple synchronous interface.

## License

See [LICENSE](LICENSE).
