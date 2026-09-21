SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/../src/project.v

TOPLEVEL = tt_um_streamdot4
MODULE = test

COMPILE_ARGS += -g2012

include $(shell cocotb-config --makefiles)/Makefile.sim
