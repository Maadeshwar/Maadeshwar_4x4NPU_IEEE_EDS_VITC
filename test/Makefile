SIM ?= icarus
TOPLEVEL_LANG ?= verilog

SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = tt_um_4x4npu.v npu4_core.v int4_multiplier.sv int4_quantizer.sv

ifneq ($(GATES),yes)

# RTL simulation
SIM_BUILD = sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate-level simulation. The GDS action supplies gate_level_netlist.v.
SIM_BUILD = sim_build/gl
COMPILE_ARGS += -DGL_TEST -DFUNCTIONAL -DSIM
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

VERILOG_SOURCES += $(PWD)/tb_tt_um_4x4npu.v

COMPILE_ARGS += -g2012 -I$(SRC_DIR)
TOPLEVEL = tb_tt_um_4x4npu
COCOTB_TEST_MODULES = test

include $(shell cocotb-config --makefiles)/Makefile.sim
