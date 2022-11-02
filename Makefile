# FPGA project

ROCKET_ROOT ?= rocket-chip
CONFIG ?= freechips.rocketchip.system.DefaultFPGAConfig
BUILD ?= build

# Generate vivado project

BOARD ?= zcu102
BOARD_ROOT = board/$(BOARD)

PRJ ?= myproject
PRJ_FULL = $(PRJ)-$(BOARD)
PRJ_ROOT = $(BOARD_ROOT)/build/$(PRJ_FULL)

# Vivado project files

BD_TCL_FILE = $(BOARD_ROOT)/bd/prm.tcl
XPR_FILE = $(PRJ_ROOT)/$(PRJ_FULL).xpr

VIVADO_FLAGS ?= -nolog -nojournal -notrace

$(XPR_FILE): $(BD_TCL_FILE)
	@vivado $(VIVADO_FLAGS) -mode batch -source $(BOARD_ROOT)/mk.tcl -tclargs $(PRJ_FULL)

project: build $(XPR_FILE)

rocket: $(BOOTROM_IMG)
	@cd $(ROCKET_ROOT); git submodule update --init --recursive
	@echo "Building rocket-chip verilog..."
	@cd $(ROCKET_ROOT)/vsim; make verilog CONFIG=$(CONFIG)

build: rocket
	@mkdir -p $(BUILD)
	@mv $(ROCKET_ROOT)/vsim/generated-src/ $(BUILD)/

clean:
	@rm -f *.log *.jou *.str
	@rm -rf $(BUILD)
	@cd $(ROCKET_ROOT)/vsim; make clean

.PHONY: clean rocket