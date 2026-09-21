SIM ?= icarus
TOPLEVEL_LANG ?= verilog

SRC_DIR = $(PWD)/../src
VERILOG_SOURCES += $(SRC_DIR)/tt_um_4x4npu.v
VERILOG_SOURCES += $(SRC_DIR)/npu4_core.v
VERILOG_SOURCES += $(SRC_DIR)/int4_multiplier.sv
VERILOG_SOURCES += $(SRC_DIR)/int4_quantizer.sv
VERILOG_SOURCES += $(PWD)/tb_tt_um_4x4npu.v

COMPILE_ARGS += -g2012 -I$(SRC_DIR)
TOPLEVEL = tb_tt_um_4x4npu
COCOTB_TEST_MODULES = test

include $(shell cocotb-config --makefiles)/Makefile.sim
