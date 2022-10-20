# U-interrupt

This is a zcu102 port for the implementation of RISC-V user interrupt extension, based on [Rocket](https://github.com/chipsalliance/rocket-chip).

## Introductions

If you clone the repository for the first time, you must update submodules recursively. You may follow the [README](rocket-chip/README.md) to install a riscv toolchain.

Run the following scripts in the root directory to generate Rocket Chip verilog outputs.

```sh
make build
```

## Table of contents

- What is user interrupt?
- System stack of Zynq FPGA, going top-down from RISC-V software to hardware layouts.
- Modifications to Rocket Chip to support user interrupt.
- Modifications to rCore to take advantage of new hardware features.
- Modifications to Linux for further design and evaluation.

## Plans

- Get familiar with the process of hardware development on zcu102.
  - Port Rocket Chip to zcu102.
  - Boot rCore and Linux on Rocket Chip.
- Apply user-interrupt hardware design to Rocket.


## Rocket chip


We don't have access to VCS simulator, but we can generate the synthesizable Verilog file with the commands:

```sh
make verilog CONFIG=freechips.rocketchip.system.DefaultFPGAConfig
```

The target Verilog will be generated in directory `vsim/generated-src`. What we need to know is how the `DefaultFPGAConfig` works. See `vsim/Makefrag-verilog` and keep tracking on all Makefile variables.

```Makefile
# Prepare for sbt and java environment
SBT ?= java -Xmx$(JVM_MEMORY) -Xss8M -jar $(base_dir)/sbt-launch.jar
JAVA ?= java -Xmx$(JVM_MEMORY) -Xss8M
FIRRTL ?= $(JAVA) -cp $(ROCKET_CHIP_JAR) firrtl.stage.FirrtlMain
GENERATOR ?= $(JAVA) -cp $(ROCKET_CHIP_JAR) $(PROJECT).Generator

# List all resource files in Rocket Chip project.
scala_srcs := $(shell find $(base_dir) -name "*.scala" -o -name "*.sbt")
resource_dirs := $(shell find $(base_dir) -type d -path "*/src/main/resources")
resources := $(foreach d,$(resource_dirs),$(shell find $(d) -type f))
all_srcs := $(scala_srcs) $(resources)

# Get rocket chip .jar file
ROCKET_CHIP_JAR := $(base_dir)/rocketchip.jar
$(ROCKET_CHIP_JAR): $(all_srcs)
	cd $(base_dir) && $(SBT) assembly

# Use pre-generated bootrom image
bootrom_img = $(base_dir)/bootrom/bootrom.img

# We need to change the CONFIG mannually
$(generated_dir)/%.fir $(generated_dir)/%.d: $(ROCKET_CHIP_JAR) $(bootrom_img)
	mkdir -p $(dir $@)
	cd $(base_dir) && $(GENERATOR) -td $(generated_dir) -T $(PROJECT).$(MODEL) -C $(CONFIG)

$(generated_dir)/%.v $(generated_dir)/%.conf: $(generated_dir)/%.fir $(ROCKET_CHIP_JAR)
	mkdir -p $(dir $@)
	$(FIRRTL) -i $< \
    -o $(generated_dir)/$*.v \
    -X verilog \
    --infer-rw $(MODEL) \
    --repl-seq-mem -c:$(MODEL):-o:$(generated_dir)/$*.conf \
    -faf $(generated_dir)/$*.anno.json \
    -td $(generated_dir)/$(long_name)/ \
    -fct $(subst $(SPACE),$(COMMA),$(FIRRTL_TRANSFORMS)) \
```

In conclusion, what we should prepare is:

- A bootrom image to load device tree and boot system softwares (uboot, linux). Maybe we can use RustSBI or OpenSBI instead.
- A device tree to let the generator know what the zcu102 board looks like
- A configuration written in Chisel and passed to the generator while building .fir file, which can be found in `src/main/scala/system`.