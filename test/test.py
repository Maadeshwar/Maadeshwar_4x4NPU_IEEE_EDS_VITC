import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

CMD_NOP = 0
CMD_CLEAR = 1
CMD_BIAS_LOW = 2
CMD_BIAS_HIGH = 3
CMD_MAC = 4
CMD_RELU = 5
CMD_LINEAR = 6
CMD_READ_ACC = 7


def nibble(value):
    assert -8 <= value <= 7
    return value & 0xF


def signed4(value):
    value &= 0xF
    return value - 16 if value & 8 else value


def signed16(value):
    value &= 0xFFFF
    return value - 0x10000 if value & 0x8000 else value


class Driver:
    def __init__(self, dut):
        self.dut = dut

    async def reset(self):
        self.dut.ena.value = 1
        self.dut.ui_in.value = 0
        self.dut.uio_in.value = 0
        self.dut.rst_n.value = 0
        await Timer(20, units="ns")
        self.dut.rst_n.value = 1
        await RisingEdge(self.dut.clk)
        assert int(self.dut.uio_oe.value) == 0

    async def command(self, opcode, data=0, parameter=0):
        # The three-state controller needs one edge to capture and one to execute.
        await RisingEdge(self.dut.clk)
        self.dut.ui_in.value = data & 0xFF
        self.dut.uio_in.value = ((opcode & 7) |
                                 (1 << 3) |
                                 ((parameter & 0xF) << 4))
        await RisingEdge(self.dut.clk)
        self.dut.uio_in.value = 0
        await RisingEdge(self.dut.clk)
        await Timer(1, units="ns")
        return int(self.dut.uo_out.value)


async def load_bias(drv, lane, value):
    value &= 0xFF
    await drv.command(CMD_BIAS_LOW, lane, value & 0xF)
    await drv.command(CMD_BIAS_HIGH, lane, (value >> 4) & 0xF)


async def mac(drv, activation, weight0, weight1):
    data = (nibble(weight0) << 4) | nibble(activation)
    await drv.command(CMD_MAC, data, nibble(weight1))


async def finish(drv, opcode, lane, shift=0):
    return await drv.command(opcode, lane, shift)


async def read_acc(drv, lane, nibble_index):
    raw = await drv.command(CMD_READ_ACC, lane, nibble_index)
    return raw & 0xF


@cocotb.test()
async def test_dual_lane_dot_product(dut):
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    drv = Driver(dut)
    await drv.reset()
    await drv.command(CMD_CLEAR)
    await load_bias(drv, 0, 0)
    await load_bias(drv, 1, 0)

    expected0 = 0
    expected1 = 0
    vectors = [(2, 3, -1), (1, -2, 4), (-3, -2, 2), (7, 1, -3)]
    for a, w0, w1 in vectors:
        await mac(drv, a, w0, w1)
        expected0 += a * w0
        expected1 += a * w1

    out0 = await finish(drv, CMD_LINEAR, 0)
    assert out0 & 0x0F == (expected0 & 0xF)
    assert (out0 >> 3) & 1 == 1  # DONE
    assert (out0 >> 7) & 1 == 1  # RESULT_VALID

    out1 = await finish(drv, CMD_LINEAR, 1)
    assert out1 & 0x0F == (expected1 & 0xF)
    assert (out1 >> 7) & 1 == 1

    reconstructed0 = sum((await read_acc(drv, 0, i)) << (4 * i)
                         for i in range(4))
    reconstructed1 = sum((await read_acc(drv, 1, i)) << (4 * i)
                         for i in range(4))
    assert signed16(reconstructed0) == expected0
    assert signed16(reconstructed1) == expected1


@cocotb.test()
async def test_signed_products_and_relu(dut):
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    drv = Driver(dut)
    await drv.reset()
    for a in range(-8, 8):
        for b in range(-8, 8):
            await drv.command(CMD_CLEAR)
            await mac(drv, a, b, 0)
            out = await finish(drv, CMD_LINEAR, 0)
            assert signed4(out & 0xF) == a * b

    await drv.command(CMD_CLEAR)
    await mac(drv, -3, 2, 0)
    out = await finish(drv, CMD_RELU, 0)
    assert out & 0xF == 0


@cocotb.test()
async def test_saturation_and_reset(dut):
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    drv = Driver(dut)
    await drv.reset()
    await drv.command(CMD_CLEAR)
    await load_bias(drv, 0, 0x7F)
    for _ in range(700):
        await mac(drv, 7, 7, 0)
    out = await finish(drv, CMD_LINEAR, 0)
    assert out & 0xF == 7
    assert (out >> 4) & 1 == 1  # overflow

    dut.rst_n.value = 0
    await Timer(2, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    assert await read_acc(drv, 0, 0) == 0
