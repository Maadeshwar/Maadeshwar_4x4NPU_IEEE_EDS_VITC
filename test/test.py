import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


def enc4(value: int) -> int:
    assert -8 <= value <= 7
    return value & 0xF


def signed12(value: int) -> int:
    value &= 0xFFF
    return value - 0x1000 if value & 0x800 else value


def clamp12(value: int) -> int:
    return max(-2048, min(2047, value))


async def result(dut, mode: int = 0) -> int:
    dut.uio_in.value = (mode & 0x7) << 5
    await Timer(1, units="ns")
    low = int(dut.uo_out.value)
    dut.uio_in.value = 0b0100 | ((mode & 0x7) << 5)
    await Timer(1, units="ns")
    high = int(dut.uo_out.value) & 0x0F
    dut.uio_in.value = 0
    return signed12((high << 8) | low)


async def activation_value(dut, mode: int) -> int:
    dut.uio_in.value = (mode & 0x7) << 5
    await Timer(1, units="ns")
    value = int(dut.uo_out.value)
    dut.uio_in.value = 0
    if mode == 4 and value & 0x80:
        return value - 0x100
    return value


async def status_overflow(dut) -> int:
    dut.uio_in.value = 0b1000
    await Timer(1, units="ns")
    value = int(dut.uo_out.value) & 1
    dut.uio_in.value = 0
    return value


async def status(dut) -> int:
    dut.uio_in.value = 0b1100
    await Timer(1, units="ns")
    value = int(dut.uo_out.value)
    dut.uio_in.value = 0
    return value


async def status_accepted(dut) -> int:
    return (await status(dut)) & 1


async def status_done(dut) -> int:
    return ((await status(dut)) >> 2) & 1


async def drive(dut, a: int, b: int, valid: int = 1, clear: int = 0,
               continuous: int = 0, mode: int = 0):
    dut.ui_in.value = (enc4(b) << 4) | enc4(a)
    dut.uio_in.value = ((valid & 1) | ((clear & 1) << 1) |
                        ((continuous & 1) << 4) | ((mode & 0x7) << 5))
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    dut.uio_in.value = 0


async def reset(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await Timer(2, units="ns")
    assert await result(dut) == 0
    assert await status_overflow(dut) == 0
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")


@cocotb.test()
async def test_exhaustive_signed_products(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut)

    for a in range(-8, 8):
        for b in range(-8, 8):
            await drive(dut, 0, 0, clear=1)
            await drive(dut, a, b)
            assert await result(dut) == a * b
            assert await status_accepted(dut) == 1
            assert await status_overflow(dut) == 0
            assert await status_done(dut) == 0


@cocotb.test()
async def test_random_accumulation_and_sticky_overflow(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut)
    rng = random.Random(0x4D4143)
    for _ in range(500):
        await drive(dut, 0, 0, clear=1)
        expected = 0
        for term in range(4):
            a = rng.randrange(-8, 8)
            b = rng.randrange(-8, 8)
            expected = clamp12(expected + a * b)
            await drive(dut, a, b)
            assert await status_accepted(dut) == 1
        assert await result(dut) == expected
        assert await status_done(dut) == 1
        assert await status_overflow(dut) == 0
        await drive(dut, 7, 7)
        assert await status_accepted(dut) == 0
        assert await result(dut) == expected


@cocotb.test()
async def test_control_priority_enable_and_reset(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut)

    await drive(dut, 7, 7)
    assert await result(dut) == 49

    # CLEAR wins when VALID and CLEAR are asserted together.
    await drive(dut, -8, -8, valid=1, clear=1)
    assert await result(dut) == 0
    assert await status_accepted(dut) == 0
    assert await status_done(dut) == 0

    # Disabled operation must not change state or report acceptance.
    dut.ena.value = 0
    await drive(dut, 7, 7)
    assert await result(dut) == 0
    assert await status_accepted(dut) == 0
    assert int(dut.uio_oe.value) == 0
    dut.ena.value = 1

    await drive(dut, 1, -1, valid=0)
    assert await result(dut) == 0
    assert await status_accepted(dut) == 0

    dut.rst_n.value = 0
    await Timer(1, units="ns")
    assert await result(dut) == 0
    assert await status_overflow(dut) == 0
    dut.rst_n.value = 1


@cocotb.test()
async def test_both_saturation_directions(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut)

    await drive(dut, 0, 0, clear=1, continuous=1)
    for _ in range(50):
        await drive(dut, 7, 7, continuous=1)
    assert await result(dut) == 2047
    assert await status_overflow(dut) == 1

    await drive(dut, 0, 0, clear=1, continuous=1)
    for _ in range(40):
        await drive(dut, -8, 7, continuous=1)
    assert await result(dut) == -2048
    assert await status_overflow(dut) == 1


@cocotb.test()
async def test_activation_modes(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut)

    await drive(dut, -3, 7, clear=1)
    await drive(dut, -3, 7)
    await drive(dut, 2, 4)
    await drive(dut, 1, 1)
    await drive(dut, 0, 0)
    # Accumulator is -21 + 8 + 1 + 0 = -12.
    assert await result(dut, mode=0) == -12
    assert await activation_value(dut, mode=1) == 0       # ReLU
    assert await activation_value(dut, mode=2) == 12      # absolute value
    assert await activation_value(dut, mode=3) == 0       # positive threshold
    assert await activation_value(dut, mode=4) == -12     # signed 8-bit clamp
    assert await activation_value(dut, mode=5) == 0xff    # sign mask
