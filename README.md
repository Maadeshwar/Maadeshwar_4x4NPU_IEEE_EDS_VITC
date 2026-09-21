# 4x4NPU — Dual-Lane INT4 Neural Accelerator

4x4NPU is an original Tiny Tapeout IHP SG13G2 design inspired by the
architecture of small command-driven INT4 neural accelerators. It is not a
copy of another repository. The datapath contains two independent signed
INT4 MAC lanes, signed 16-bit saturation, bias loading, ReLU/linear INT4
quantization, and accumulator readback.

The host streams one activation and two weights per `MAC` command. Both lanes
update in parallel. This enables compact neural-network inference using
quantized weights, while the host retains control of model scheduling.

## Verification

The Cocotb testbench checks reset and pin direction, dual-lane signed dot
products, all 256 signed INT4 products, ReLU behavior, saturation, and full
16-bit accumulator nibble readback. Run it from `test/` with:

```text
python -m pip install -r requirements.txt
make
```

The Tiny Tapeout IHP130 GDS, precheck, and gate-level workflows are included in
the repository. Passing RTL simulation is necessary but does not by itself
prove silicon timing or area.
