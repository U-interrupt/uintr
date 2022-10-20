ROCKET_ROOT ?= rocket-chip
CONFIG ?= freechips.rocketchip.system.DefaultFPGAConfig
BUILD ?= build

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