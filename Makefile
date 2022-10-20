ROCKET_ROOT ?= rocket-chip

include $(ROCKET_ROOT)/Makefrag
include $(ROCKET_ROOT)/vsim/Makefrag
include $(ROCKET_ROOT)/vsim/Makefrag-verilog

rocket: $(BOOTROM_IMG)
	@mkdir build
	@cd $(ROCKET_ROOT)/vsim
	@make verilog CONFIG=$(CONFIG)
	