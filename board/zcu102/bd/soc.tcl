
################################################################
# This is a generated script based on design: soc
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2020.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source soc_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xczu9eg-ffvb1156-2-e
   set_property BOARD_PART xilinx.com:zcu102:part0:3.4 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name uintr_soc

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:axi_dma:7.1\
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:zynq_ultra_ps_e:3.3\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:axi_clock_converter:2.1\
xilinx.com:ip:axi_crossbar:2.1\
xilinx.com:ip:axi_uart16550:2.0\
xilinx.com:ip:axi_uartlite:2.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: hier_uart
proc create_hier_cell_hier_uart { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_hier_uart() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_UART_arm

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_UART_core


  # Create pins
  create_bd_pin -dir I -type clk aclk
  create_bd_pin -dir O -type intr arm_uart_irq_0
  create_bd_pin -dir O -type intr arm_uart_irq_1
  create_bd_pin -dir O -type intr arm_uart_irq_2
  create_bd_pin -dir O -type intr arm_uart_irq_3
  create_bd_pin -dir O -from 4 -to 0 core_uart_irq
  create_bd_pin -dir I -type rst interconnect_aresetn
  create_bd_pin -dir I -type rst peripheral_aresetn

  # Create instance: axi_crossbar_arm, and set properties
  set axi_crossbar_arm [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_crossbar:2.1 axi_crossbar_arm ]
  set_property -dict [ list \
   CONFIG.NUM_MI {4} \
 ] $axi_crossbar_arm

  # Create instance: axi_crossbar_core, and set properties
  set axi_crossbar_core [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_crossbar:2.1 axi_crossbar_core ]
  set_property -dict [ list \
   CONFIG.NUM_MI {5} \
 ] $axi_crossbar_core

  # Create instance: axi_uart16550_core_1, and set properties
  set axi_uart16550_core_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uart16550:2.0 axi_uart16550_core_1 ]

  # Create instance: axi_uart16550_core_2, and set properties
  set axi_uart16550_core_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uart16550:2.0 axi_uart16550_core_2 ]

  # Create instance: axi_uart16550_core_3, and set properties
  set axi_uart16550_core_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uart16550:2.0 axi_uart16550_core_3 ]

  # Create instance: axi_uart16550_core_4, and set properties
  set axi_uart16550_core_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uart16550:2.0 axi_uart16550_core_4 ]

  # Create instance: axi_uartlite_0, and set properties
  set axi_uartlite_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0 ]
  set_property -dict [ list \
   CONFIG.C_BAUDRATE {115200} \
 ] $axi_uartlite_0

  # Create instance: axi_uartlite_1, and set properties
  set axi_uartlite_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_1 ]
  set_property -dict [ list \
   CONFIG.C_BAUDRATE {115200} \
 ] $axi_uartlite_1

  # Create instance: axi_uartlite_2, and set properties
  set axi_uartlite_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_2 ]
  set_property -dict [ list \
   CONFIG.C_BAUDRATE {115200} \
 ] $axi_uartlite_2

  # Create instance: axi_uartlite_3, and set properties
  set axi_uartlite_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_3 ]
  set_property -dict [ list \
   CONFIG.C_BAUDRATE {115200} \
 ] $axi_uartlite_3

  # Create instance: axi_uartlite_core_0, and set properties
  set axi_uartlite_core_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_core_0 ]
  set_property -dict [ list \
   CONFIG.C_BAUDRATE {115200} \
 ] $axi_uartlite_core_0

  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [ list \
   CONFIG.NUM_PORTS {5} \
 ] $xlconcat_0

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins S_AXI_UART_core] [get_bd_intf_pins axi_crossbar_core/S00_AXI]
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins S_AXI_UART_arm] [get_bd_intf_pins axi_crossbar_arm/S00_AXI]
  connect_bd_intf_net -intf_net axi_crossbar_pardcore_M00_AXI [get_bd_intf_pins axi_crossbar_core/M00_AXI] [get_bd_intf_pins axi_uartlite_core_0/S_AXI]
  connect_bd_intf_net -intf_net axi_crossbar_pardcore_M01_AXI [get_bd_intf_pins axi_crossbar_core/M01_AXI] [get_bd_intf_pins axi_uart16550_core_1/S_AXI]
  connect_bd_intf_net -intf_net axi_crossbar_pardcore_M02_AXI [get_bd_intf_pins axi_crossbar_core/M02_AXI] [get_bd_intf_pins axi_uart16550_core_2/S_AXI]
  connect_bd_intf_net -intf_net axi_crossbar_pardcore_M03_AXI [get_bd_intf_pins axi_crossbar_core/M03_AXI] [get_bd_intf_pins axi_uart16550_core_3/S_AXI]
  connect_bd_intf_net -intf_net axi_crossbar_pardcore_M04_AXI [get_bd_intf_pins axi_crossbar_core/M04_AXI] [get_bd_intf_pins axi_uart16550_core_4/S_AXI]
  connect_bd_intf_net -intf_net axi_crossbar_prm_M00_AXI [get_bd_intf_pins axi_crossbar_arm/M00_AXI] [get_bd_intf_pins axi_uartlite_0/S_AXI]
  connect_bd_intf_net -intf_net axi_crossbar_prm_M01_AXI [get_bd_intf_pins axi_crossbar_arm/M01_AXI] [get_bd_intf_pins axi_uartlite_1/S_AXI]
  connect_bd_intf_net -intf_net axi_crossbar_prm_M02_AXI [get_bd_intf_pins axi_crossbar_arm/M02_AXI] [get_bd_intf_pins axi_uartlite_2/S_AXI]
  connect_bd_intf_net -intf_net axi_crossbar_prm_M03_AXI [get_bd_intf_pins axi_crossbar_arm/M03_AXI] [get_bd_intf_pins axi_uartlite_3/S_AXI]

  # Create port connections
  connect_bd_net -net aclk_1 [get_bd_pins aclk] [get_bd_pins axi_crossbar_arm/aclk] [get_bd_pins axi_crossbar_core/aclk] [get_bd_pins axi_uart16550_core_1/s_axi_aclk] [get_bd_pins axi_uart16550_core_2/s_axi_aclk] [get_bd_pins axi_uart16550_core_3/s_axi_aclk] [get_bd_pins axi_uart16550_core_4/s_axi_aclk] [get_bd_pins axi_uartlite_0/s_axi_aclk] [get_bd_pins axi_uartlite_1/s_axi_aclk] [get_bd_pins axi_uartlite_2/s_axi_aclk] [get_bd_pins axi_uartlite_3/s_axi_aclk] [get_bd_pins axi_uartlite_core_0/s_axi_aclk]
  connect_bd_net -net aresetn_1 [get_bd_pins interconnect_aresetn] [get_bd_pins axi_crossbar_arm/aresetn] [get_bd_pins axi_crossbar_core/aresetn]
  connect_bd_net -net axi_uart16550_1_ip2intc_irpt [get_bd_pins axi_uart16550_core_1/ip2intc_irpt] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net axi_uart16550_1_sout [get_bd_pins axi_uart16550_core_1/sout] [get_bd_pins axi_uartlite_1/rx]
  connect_bd_net -net axi_uart16550_2_ip2intc_irpt [get_bd_pins axi_uart16550_core_2/ip2intc_irpt] [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net axi_uart16550_2_sout [get_bd_pins axi_uart16550_core_2/sout] [get_bd_pins axi_uartlite_2/rx]
  connect_bd_net -net axi_uart16550_3_ip2intc_irpt [get_bd_pins axi_uart16550_core_3/ip2intc_irpt] [get_bd_pins xlconcat_0/In3]
  connect_bd_net -net axi_uart16550_3_sout [get_bd_pins axi_uart16550_core_3/sout] [get_bd_pins axi_uart16550_core_4/sin]
  connect_bd_net -net axi_uart16550_4_ip2intc_irpt [get_bd_pins axi_uart16550_core_4/ip2intc_irpt] [get_bd_pins xlconcat_0/In4]
  connect_bd_net -net axi_uart16550_4_sout [get_bd_pins axi_uart16550_core_3/sin] [get_bd_pins axi_uart16550_core_4/sout]
  connect_bd_net -net axi_uartlite_0_interrupt [get_bd_pins arm_uart_irq_0] [get_bd_pins axi_uartlite_0/interrupt]
  connect_bd_net -net axi_uartlite_0_tx [get_bd_pins axi_uartlite_0/tx] [get_bd_pins axi_uartlite_core_0/rx]
  connect_bd_net -net axi_uartlite_1_interrupt [get_bd_pins arm_uart_irq_1] [get_bd_pins axi_uartlite_1/interrupt]
  connect_bd_net -net axi_uartlite_1_tx [get_bd_pins axi_uart16550_core_1/sin] [get_bd_pins axi_uartlite_1/tx]
  connect_bd_net -net axi_uartlite_2_interrupt [get_bd_pins arm_uart_irq_2] [get_bd_pins axi_uartlite_2/interrupt]
  connect_bd_net -net axi_uartlite_2_tx [get_bd_pins axi_uart16550_core_2/sin] [get_bd_pins axi_uartlite_2/tx]
  connect_bd_net -net axi_uartlite_3_interrupt [get_bd_pins arm_uart_irq_3] [get_bd_pins axi_uartlite_3/interrupt]
  connect_bd_net -net axi_uartlite_pardcore_0_interrupt [get_bd_pins axi_uartlite_core_0/interrupt] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net axi_uartlite_pardcore_0_tx [get_bd_pins axi_uartlite_0/rx] [get_bd_pins axi_uartlite_core_0/tx]
  connect_bd_net -net s_axi_aresetn_1 [get_bd_pins peripheral_aresetn] [get_bd_pins axi_uart16550_core_3/s_axi_aresetn] [get_bd_pins axi_uartlite_0/s_axi_aresetn] [get_bd_pins axi_uartlite_1/s_axi_aresetn] [get_bd_pins axi_uartlite_2/s_axi_aresetn] [get_bd_pins axi_uartlite_3/s_axi_aresetn]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins core_uart_irq] [get_bd_pins xlconcat_0/dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: hier_slow_ddr
proc create_hier_cell_hier_slow_ddr { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_hier_slow_ddr() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_MEM


  # Create pins
  create_bd_pin -dir I -type clk axi_aclk
  create_bd_pin -dir I -type rst axi_aresetn

  # Create instance: slow_ddr_clk_converter_0, and set properties
  set slow_ddr_clk_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 slow_ddr_clk_converter_0 ]

  # Create instance: slow_ddr_clk_converter_1, and set properties
  set slow_ddr_clk_converter_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 slow_ddr_clk_converter_1 ]

  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins M_AXI] [get_bd_intf_pins slow_ddr_clk_converter_1/M_AXI]
  connect_bd_intf_net -intf_net S_AXI_0_1 [get_bd_intf_pins S_AXI_MEM] [get_bd_intf_pins slow_ddr_clk_converter_0/S_AXI]
  connect_bd_intf_net -intf_net slow_ddr_clk_converter_0_M_AXI [get_bd_intf_pins slow_ddr_clk_converter_0/M_AXI] [get_bd_intf_pins slow_ddr_clk_converter_1/S_AXI]

  # Create port connections
  connect_bd_net -net clk_wiz_core_clk [get_bd_pins axi_aclk] [get_bd_pins slow_ddr_clk_converter_0/m_axi_aclk] [get_bd_pins slow_ddr_clk_converter_0/s_axi_aclk] [get_bd_pins slow_ddr_clk_converter_1/m_axi_aclk] [get_bd_pins slow_ddr_clk_converter_1/s_axi_aclk]
  connect_bd_net -net core_rst_interconnect_aresetn [get_bd_pins axi_aresetn] [get_bd_pins slow_ddr_clk_converter_0/m_axi_aresetn] [get_bd_pins slow_ddr_clk_converter_0/s_axi_aresetn] [get_bd_pins slow_ddr_clk_converter_1/m_axi_aresetn] [get_bd_pins slow_ddr_clk_converter_1/s_axi_aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: hier_core
proc create_hier_cell_hier_core { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_hier_core() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M00_AXI_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M01_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 M_AXIS_MM2S

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 S_AXIS_S2MM

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_MMIO


  # Create pins
  create_bd_pin -dir I -type clk axi_aclk
  create_bd_pin -dir I -type rst axi_resetn
  create_bd_pin -dir I -type rst interconnect_aresetn
  create_bd_pin -dir O -type intr mm2s_introut_0
  create_bd_pin -dir O -type intr s2mm_introut_0

  # Create instance: axi_dma_core, and set properties
  set axi_dma_core [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_core ]
  set_property -dict [ list \
   CONFIG.c_addr_width {40} \
   CONFIG.c_include_mm2s_dre {1} \
   CONFIG.c_include_s2mm_dre {1} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
   CONFIG.c_sg_length_width {16} \
 ] $axi_dma_core

  # Create instance: axi_interconnect_2, and set properties
  set axi_interconnect_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_2 ]

  # Create instance: axi_interconnect_3, and set properties
  set axi_interconnect_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_3 ]
  set_property -dict [ list \
   CONFIG.NUM_MI {1} \
   CONFIG.NUM_SI {3} \
 ] $axi_interconnect_3

  # Create interface connections
  connect_bd_intf_net -intf_net S00_AXI_0_1 [get_bd_intf_pins S_AXI_MMIO] [get_bd_intf_pins axi_interconnect_2/S00_AXI]
  connect_bd_intf_net -intf_net S00_AXI_2 [get_bd_intf_pins axi_dma_core/M_AXI_SG] [get_bd_intf_pins axi_interconnect_3/S00_AXI]
  connect_bd_intf_net -intf_net S00_AXI_3 [get_bd_intf_pins M01_AXI] [get_bd_intf_pins axi_interconnect_2/M01_AXI]
  connect_bd_intf_net -intf_net S01_AXI_2 [get_bd_intf_pins axi_dma_core/M_AXI_MM2S] [get_bd_intf_pins axi_interconnect_3/S01_AXI]
  connect_bd_intf_net -intf_net S02_AXI_2 [get_bd_intf_pins axi_dma_core/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_3/S02_AXI]
  connect_bd_intf_net -intf_net axi_dma_arm_M_AXIS_MM2S [get_bd_intf_pins S_AXIS_S2MM] [get_bd_intf_pins axi_dma_core/S_AXIS_S2MM]
  connect_bd_intf_net -intf_net axi_dma_core_M_AXIS_MM2S [get_bd_intf_pins M_AXIS_MM2S] [get_bd_intf_pins axi_dma_core/M_AXIS_MM2S]
  connect_bd_intf_net -intf_net axi_interconnect_2_M00_AXI [get_bd_intf_pins axi_dma_core/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_2/M00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_3_M00_AXI [get_bd_intf_pins M00_AXI_0] [get_bd_intf_pins axi_interconnect_3/M00_AXI]

  # Create port connections
  connect_bd_net -net axi_dma_core_mm2s_introut [get_bd_pins mm2s_introut_0] [get_bd_pins axi_dma_core/mm2s_introut]
  connect_bd_net -net axi_dma_core_s2mm_introut [get_bd_pins s2mm_introut_0] [get_bd_pins axi_dma_core/s2mm_introut]
  connect_bd_net -net clk_wiz_core_clk [get_bd_pins axi_aclk] [get_bd_pins axi_dma_core/m_axi_mm2s_aclk] [get_bd_pins axi_dma_core/m_axi_s2mm_aclk] [get_bd_pins axi_dma_core/m_axi_sg_aclk] [get_bd_pins axi_dma_core/s_axi_lite_aclk] [get_bd_pins axi_interconnect_2/ACLK] [get_bd_pins axi_interconnect_2/M00_ACLK] [get_bd_pins axi_interconnect_2/M01_ACLK] [get_bd_pins axi_interconnect_2/S00_ACLK] [get_bd_pins axi_interconnect_3/ACLK] [get_bd_pins axi_interconnect_3/M00_ACLK] [get_bd_pins axi_interconnect_3/S00_ACLK] [get_bd_pins axi_interconnect_3/S01_ACLK] [get_bd_pins axi_interconnect_3/S02_ACLK]
  connect_bd_net -net core_rst_interconnect_aresetn [get_bd_pins interconnect_aresetn] [get_bd_pins axi_interconnect_2/ARESETN] [get_bd_pins axi_interconnect_2/M00_ARESETN] [get_bd_pins axi_interconnect_2/M01_ARESETN] [get_bd_pins axi_interconnect_2/S00_ARESETN] [get_bd_pins axi_interconnect_3/ARESETN] [get_bd_pins axi_interconnect_3/M00_ARESETN] [get_bd_pins axi_interconnect_3/S00_ARESETN] [get_bd_pins axi_interconnect_3/S01_ARESETN] [get_bd_pins axi_interconnect_3/S02_ARESETN]
  connect_bd_net -net hier_clk_rst_peripheral_aresetn [get_bd_pins axi_resetn] [get_bd_pins axi_dma_core/axi_resetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: hier_clk_rst
proc create_hier_cell_hier_clk_rst { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_hier_clk_rst() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir I -type clk clk_in1
  create_bd_pin -dir O -type clk core_clk
  create_bd_pin -dir O -from 0 -to 0 -type rst interconnect_aresetn
  create_bd_pin -dir O -from 0 -to 0 -type rst peripheral_aresetn
  create_bd_pin -dir I -type rst reset

  # Create instance: clk_wiz, and set properties
  set clk_wiz [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz ]
  set_property -dict [ list \
   CONFIG.CLK_IN1_BOARD_INTERFACE {Custom} \
   CONFIG.CLK_IN2_BOARD_INTERFACE {Custom} \
   CONFIG.CLK_OUT1_PORT {core_clk} \
   CONFIG.RESET_BOARD_INTERFACE {Custom} \
   CONFIG.RESET_PORT {resetn} \
   CONFIG.RESET_TYPE {ACTIVE_LOW} \
 ] $clk_wiz

  # Create instance: core_rst, and set properties
  set core_rst [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 core_rst ]
  set_property -dict [ list \
   CONFIG.RESET_BOARD_INTERFACE {Custom} \
   CONFIG.USE_BOARD_FLOW {true} \
 ] $core_rst

  # Create port connections
  connect_bd_net -net clk_wiz_core_clk [get_bd_pins core_clk] [get_bd_pins clk_wiz/core_clk] [get_bd_pins core_rst/slowest_sync_clk]
  connect_bd_net -net clk_wiz_locked [get_bd_pins clk_wiz/locked] [get_bd_pins core_rst/dcm_locked]
  connect_bd_net -net core_rst_interconnect_aresetn [get_bd_pins interconnect_aresetn] [get_bd_pins core_rst/interconnect_aresetn]
  connect_bd_net -net core_rst_peripheral_aresetn [get_bd_pins peripheral_aresetn] [get_bd_pins core_rst/peripheral_aresetn]
  connect_bd_net -net zync_ultra_core_pl_clk0 [get_bd_pins clk_in1] [get_bd_pins clk_wiz/clk_in1]
  connect_bd_net -net zync_ultra_core_pl_resetn0 [get_bd_pins reset] [get_bd_pins clk_wiz/resetn] [get_bd_pins core_rst/ext_reset_in]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set M_AXI_DMA [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_DMA ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {40} \
   CONFIG.DATA_WIDTH {64} \
   CONFIG.NUM_READ_OUTSTANDING {2} \
   CONFIG.NUM_WRITE_OUTSTANDING {2} \
   CONFIG.PROTOCOL {AXI4} \
   ] $M_AXI_DMA

  set S_AXI_MEM [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_MEM ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {40} \
   CONFIG.ARUSER_WIDTH {1} \
   CONFIG.AWUSER_WIDTH {1} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {64} \
   CONFIG.HAS_BRESP {1} \
   CONFIG.HAS_BURST {1} \
   CONFIG.HAS_CACHE {1} \
   CONFIG.HAS_LOCK {1} \
   CONFIG.HAS_PROT {1} \
   CONFIG.HAS_QOS {1} \
   CONFIG.HAS_REGION {1} \
   CONFIG.HAS_RRESP {1} \
   CONFIG.HAS_WSTRB {1} \
   CONFIG.ID_WIDTH {4} \
   CONFIG.MAX_BURST_LENGTH {256} \
   CONFIG.NUM_READ_OUTSTANDING {16} \
   CONFIG.NUM_READ_THREADS {1} \
   CONFIG.NUM_WRITE_OUTSTANDING {16} \
   CONFIG.NUM_WRITE_THREADS {1} \
   CONFIG.PROTOCOL {AXI4} \
   CONFIG.READ_WRITE_MODE {READ_WRITE} \
   CONFIG.RUSER_BITS_PER_BYTE {0} \
   CONFIG.RUSER_WIDTH {0} \
   CONFIG.SUPPORTS_NARROW_BURST {1} \
   CONFIG.WUSER_BITS_PER_BYTE {0} \
   CONFIG.WUSER_WIDTH {0} \
   ] $S_AXI_MEM

  set S_AXI_MMIO [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_MMIO ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {40} \
   CONFIG.ARUSER_WIDTH {0} \
   CONFIG.AWUSER_WIDTH {0} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH {64} \
   CONFIG.HAS_BRESP {1} \
   CONFIG.HAS_BURST {0} \
   CONFIG.HAS_CACHE {0} \
   CONFIG.HAS_LOCK {0} \
   CONFIG.HAS_PROT {1} \
   CONFIG.HAS_QOS {0} \
   CONFIG.HAS_REGION {0} \
   CONFIG.HAS_RRESP {1} \
   CONFIG.HAS_WSTRB {1} \
   CONFIG.ID_WIDTH {8} \
   CONFIG.MAX_BURST_LENGTH {1} \
   CONFIG.NUM_READ_OUTSTANDING {2} \
   CONFIG.NUM_READ_THREADS {1} \
   CONFIG.NUM_WRITE_OUTSTANDING {2} \
   CONFIG.NUM_WRITE_THREADS {1} \
   CONFIG.PROTOCOL {AXI4} \
   CONFIG.READ_WRITE_MODE {READ_WRITE} \
   CONFIG.RUSER_BITS_PER_BYTE {0} \
   CONFIG.RUSER_WIDTH {0} \
   CONFIG.SUPPORTS_NARROW_BURST {0} \
   CONFIG.WUSER_BITS_PER_BYTE {0} \
   CONFIG.WUSER_WIDTH {0} \
   ] $S_AXI_MMIO


  # Create ports
  set core_clk [ create_bd_port -dir O -type clk core_clk ]
  set_property -dict [ list \
   CONFIG.ASSOCIATED_BUSIF {S_AXI_MEM:S_AXI_MMIO:M_AXI_DMA} \
 ] $core_clk
  set core_rstn [ create_bd_port -dir O -type rst core_rstn ]
  set core_uart_irq_0 [ create_bd_port -dir O -from 4 -to 0 core_uart_irq_0 ]
  set mm2s_introut_0 [ create_bd_port -dir O -type intr mm2s_introut_0 ]
  set s2mm_introut_0 [ create_bd_port -dir O -type intr s2mm_introut_0 ]

  # Create instance: axi_dma_arm, and set properties
  set axi_dma_arm [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_arm ]
  set_property -dict [ list \
   CONFIG.c_include_mm2s_dre {1} \
   CONFIG.c_include_s2mm_dre {1} \
   CONFIG.c_sg_include_stscntrl_strm {0} \
   CONFIG.c_sg_length_width {16} \
 ] $axi_dma_arm

  # Create instance: axi_interconnect_0, and set properties
  set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]

  # Create instance: axi_interconnect_1, and set properties
  set axi_interconnect_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_1 ]
  set_property -dict [ list \
   CONFIG.NUM_MI {1} \
   CONFIG.NUM_SI {4} \
 ] $axi_interconnect_1

  # Create instance: hier_clk_rst
  create_hier_cell_hier_clk_rst [current_bd_instance .] hier_clk_rst

  # Create instance: hier_core
  create_hier_cell_hier_core [current_bd_instance .] hier_core

  # Create instance: hier_slow_ddr
  create_hier_cell_hier_slow_ddr [current_bd_instance .] hier_slow_ddr

  # Create instance: hier_uart
  create_hier_cell_hier_uart [current_bd_instance .] hier_uart

  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [ list \
   CONFIG.NUM_PORTS {6} \
 ] $xlconcat_0

  # Create instance: zynq_soc, and set properties
  set zynq_soc [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 zynq_soc ]
  set_property -dict [ list \
   CONFIG.PSU_DDR_RAM_HIGHADDR_OFFSET {0x00000002} \
   CONFIG.PSU_DDR_RAM_LOWADDR_OFFSET {0x80000000} \
   CONFIG.PSU__DDR_HIGH_ADDRESS_GUI_ENABLE {0} \
   CONFIG.PSU__MAXIGP0__DATA_WIDTH {64} \
   CONFIG.PSU__MAXIGP2__DATA_WIDTH {32} \
   CONFIG.PSU__PROTECTION__MASTERS {USB1:NonSecure;0|USB0:NonSecure;0|S_AXI_LPD:NA;0|S_AXI_HPC1_FPD:NA;0|S_AXI_HPC0_FPD:NA;0|S_AXI_HP3_FPD:NA;0|S_AXI_HP2_FPD:NA;0|S_AXI_HP1_FPD:NA;0|S_AXI_HP0_FPD:NA;1|S_AXI_ACP:NA;0|S_AXI_ACE:NA;0|SD1:NonSecure;0|SD0:NonSecure;0|SATA1:NonSecure;0|SATA0:NonSecure;0|RPU1:Secure;1|RPU0:Secure;1|QSPI:NonSecure;0|PMU:NA;1|PCIe:NonSecure;0|NAND:NonSecure;0|LDMA:NonSecure;1|GPU:NonSecure;1|GEM3:NonSecure;0|GEM2:NonSecure;0|GEM1:NonSecure;0|GEM0:NonSecure;0|FDMA:NonSecure;1|DP:NonSecure;0|DAP:NA;1|Coresight:NA;1|CSU:NA;1|APU:NA;1} \
   CONFIG.PSU__PROTECTION__SLAVES { \
     LPD;USB3_1_XHCI;FE300000;FE3FFFFF;0|LPD;USB3_1;FF9E0000;FF9EFFFF;0|LPD;USB3_0_XHCI;FE200000;FE2FFFFF;0|LPD;USB3_0;FF9D0000;FF9DFFFF;0|LPD;UART1;FF010000;FF01FFFF;0|LPD;UART0;FF000000;FF00FFFF;0|LPD;TTC3;FF140000;FF14FFFF;0|LPD;TTC2;FF130000;FF13FFFF;0|LPD;TTC1;FF120000;FF12FFFF;0|LPD;TTC0;FF110000;FF11FFFF;0|FPD;SWDT1;FD4D0000;FD4DFFFF;0|LPD;SWDT0;FF150000;FF15FFFF;0|LPD;SPI1;FF050000;FF05FFFF;0|LPD;SPI0;FF040000;FF04FFFF;0|FPD;SMMU_REG;FD5F0000;FD5FFFFF;1|FPD;SMMU;FD800000;FDFFFFFF;1|FPD;SIOU;FD3D0000;FD3DFFFF;1|FPD;SERDES;FD400000;FD47FFFF;1|LPD;SD1;FF170000;FF17FFFF;0|LPD;SD0;FF160000;FF16FFFF;0|FPD;SATA;FD0C0000;FD0CFFFF;0|LPD;RTC;FFA60000;FFA6FFFF;1|LPD;RSA_CORE;FFCE0000;FFCEFFFF;1|LPD;RPU;FF9A0000;FF9AFFFF;1|LPD;R5_TCM_RAM_GLOBAL;FFE00000;FFE3FFFF;1|LPD;R5_1_Instruction_Cache;FFEC0000;FFECFFFF;1|LPD;R5_1_Data_Cache;FFED0000;FFEDFFFF;1|LPD;R5_1_BTCM_GLOBAL;FFEB0000;FFEBFFFF;1|LPD;R5_1_ATCM_GLOBAL;FFE90000;FFE9FFFF;1|LPD;R5_0_Instruction_Cache;FFE40000;FFE4FFFF;1|LPD;R5_0_Data_Cache;FFE50000;FFE5FFFF;1|LPD;R5_0_BTCM_GLOBAL;FFE20000;FFE2FFFF;1|LPD;R5_0_ATCM_GLOBAL;FFE00000;FFE0FFFF;1|LPD;QSPI_Linear_Address;C0000000;DFFFFFFF;1|LPD;QSPI;FF0F0000;FF0FFFFF;0|LPD;PMU_RAM;FFDC0000;FFDDFFFF;1|LPD;PMU_GLOBAL;FFD80000;FFDBFFFF;1|FPD;PCIE_MAIN;FD0E0000;FD0EFFFF;0|FPD;PCIE_LOW;E0000000;EFFFFFFF;0|FPD;PCIE_HIGH2;8000000000;BFFFFFFFFF;0|FPD;PCIE_HIGH1;600000000;7FFFFFFFF;0|FPD;PCIE_DMA;FD0F0000;FD0FFFFF;0|FPD;PCIE_ATTRIB;FD480000;FD48FFFF;0|LPD;OCM_XMPU_CFG;FFA70000;FFA7FFFF;1|LPD;OCM_SLCR;FF960000;FF96FFFF;1|OCM;OCM;FFFC0000;FFFFFFFF;1|LPD;NAND;FF100000;FF10FFFF;0|LPD;MBISTJTAG;FFCF0000;FFCFFFFF;1|LPD;LPD_XPPU_SINK;FF9C0000;FF9CFFFF;1|LPD;LPD_XPPU;FF980000;FF98FFFF;1|LPD;LPD_SLCR_SECURE;FF4B0000;FF4DFFFF;1|LPD;LPD_SLCR;FF410000;FF4AFFFF;1|LPD;LPD_GPV;FE100000;FE1FFFFF;1|LPD;LPD_DMA_7;FFAF0000;FFAFFFFF;1|LPD;LPD_DMA_6;FFAE0000;FFAEFFFF;1|LPD;LPD_DMA_5;FFAD0000;FFADFFFF;1|LPD;LPD_DMA_4;FFAC0000;FFACFFFF;1|LPD;LPD_DMA_3;FFAB0000;FFABFFFF;1|LPD;LPD_DMA_2;FFAA0000;FFAAFFFF;1|LPD;LPD_DMA_1;FFA90000;FFA9FFFF;1|LPD;LPD_DMA_0;FFA80000;FFA8FFFF;1|LPD;IPI_CTRL;FF380000;FF3FFFFF;1|LPD;IOU_SLCR;FF180000;FF23FFFF;1|LPD;IOU_SECURE_SLCR;FF240000;FF24FFFF;1|LPD;IOU_SCNTRS;FF260000;FF26FFFF;1|LPD;IOU_SCNTR;FF250000;FF25FFFF;1|LPD;IOU_GPV;FE000000;FE0FFFFF;1|LPD;I2C1;FF030000;FF03FFFF;0|LPD;I2C0;FF020000;FF02FFFF;0|FPD;GPU;FD4B0000;FD4BFFFF;1|LPD;GPIO;FF0A0000;FF0AFFFF;1|LPD;GEM3;FF0E0000;FF0EFFFF;0|LPD;GEM2;FF0D0000;FF0DFFFF;0|LPD;GEM1;FF0C0000;FF0CFFFF;0|LPD;GEM0;FF0B0000;FF0BFFFF;0|FPD;FPD_XMPU_SINK;FD4F0000;FD4FFFFF;1|FPD;FPD_XMPU_CFG;FD5D0000;FD5DFFFF;1|FPD;FPD_SLCR_SECURE;FD690000;FD6CFFFF;1|FPD;FPD_SLCR;FD610000;FD68FFFF;1|FPD;FPD_DMA_CH7;FD570000;FD57FFFF;1|FPD;FPD_DMA_CH6;FD560000;FD56FFFF;1|FPD;FPD_DMA_CH5;FD550000;FD55FFFF;1|FPD;FPD_DMA_CH4;FD540000;FD54FFFF;1|FPD;FPD_DMA_CH3;FD530000;FD53FFFF;1|FPD;FPD_DMA_CH2;FD520000;FD52FFFF;1|FPD;FPD_DMA_CH1;FD510000;FD51FFFF;1|FPD;FPD_DMA_CH0;FD500000;FD50FFFF;1|LPD;EFUSE;FFCC0000;FFCCFFFF;1|FPD;Display Port;FD4A0000;FD4AFFFF;0|FPD;DPDMA;FD4C0000;FD4CFFFF;0|FPD;DDR_XMPU5_CFG;FD050000;FD05FFFF;1|FPD;DDR_XMPU4_CFG;FD040000;FD04FFFF;1|FPD;DDR_XMPU3_CFG;FD030000;FD03FFFF;1|FPD;DDR_XMPU2_CFG;FD020000;FD02FFFF;1|FPD;DDR_XMPU1_CFG;FD010000;FD01FFFF;1|FPD;DDR_XMPU0_CFG;FD000000;FD00FFFF;1|FPD;DDR_QOS_CTRL;FD090000;FD09FFFF;1|FPD;DDR_PHY;FD080000;FD08FFFF;1|DDR;DDR_LOW;0;7FFFFFFF;1|DDR;DDR_HIGH;800000000;800000000;0|FPD;DDDR_CTRL;FD070000;FD070FFF;1|LPD;Coresight;FE800000;FEFFFFFF;1|LPD;CSU_DMA;FFC80000;FFC9FFFF;1|LPD;CSU;FFCA0000;FFCAFFFF;1|LPD;CRL_APB;FF5E0000;FF85FFFF;1|FPD;CRF_APB;FD1A0000;FD2DFFFF;1|FPD;CCI_REG;FD5E0000;FD5EFFFF;1|LPD;CAN1;FF070000;FF07FFFF;0|LPD;CAN0;FF060000;FF06FFFF;0|FPD;APU;FD5C0000;FD5CFFFF;1|LPD;APM_INTC_IOU;FFA20000;FFA2FFFF;1|LPD;APM_FPD_LPD;FFA30000;FFA3FFFF;1|FPD;APM_5;FD490000;FD49FFFF;1|FPD;APM_0;FD0B0000;FD0BFFFF;1|LPD;APM2;FFA10000;FFA1FFFF;1|LPD;APM1;FFA00000;FFA0FFFF;1|LPD;AMS;FFA50000;FFA5FFFF;1|FPD;AFI_5;FD3B0000;FD3BFFFF;1|FPD;AFI_4;FD3A0000;FD3AFFFF;1|FPD;AFI_3;FD390000;FD39FFFF;1|FPD;AFI_2;FD380000;FD38FFFF;1|FPD;AFI_1;FD370000;FD37FFFF;1|FPD;AFI_0;FD360000;FD36FFFF;1|LPD;AFIFM6;FF9B0000;FF9BFFFF;1|FPD;ACPU_GIC;F9010000;F907FFFF;1 \
   } \
   CONFIG.PSU__SAXIGP2__DATA_WIDTH {64} \
   CONFIG.PSU__USE__IRQ0 {1} \
   CONFIG.PSU__USE__M_AXI_GP0 {1} \
   CONFIG.PSU__USE__M_AXI_GP2 {0} \
   CONFIG.PSU__USE__S_AXI_GP2 {1} \
 ] $zynq_soc

  # Create interface connections
  connect_bd_intf_net -intf_net M_AXI_DMA [get_bd_intf_ports M_AXI_DMA] [get_bd_intf_pins hier_core/M00_AXI_0]
  connect_bd_intf_net -intf_net S00_AXI_0_1 [get_bd_intf_ports S_AXI_MMIO] [get_bd_intf_pins hier_core/S_AXI_MMIO]
  connect_bd_intf_net -intf_net S00_AXI_1 [get_bd_intf_pins axi_dma_arm/M_AXI_SG] [get_bd_intf_pins axi_interconnect_1/S00_AXI]
  connect_bd_intf_net -intf_net S00_AXI_3 [get_bd_intf_pins hier_core/M01_AXI] [get_bd_intf_pins hier_uart/S_AXI_UART_core]
  connect_bd_intf_net -intf_net S01_AXI_1 [get_bd_intf_pins axi_dma_arm/M_AXI_MM2S] [get_bd_intf_pins axi_interconnect_1/S01_AXI]
  connect_bd_intf_net -intf_net S02_AXI_1 [get_bd_intf_pins axi_dma_arm/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_1/S02_AXI]
  connect_bd_intf_net -intf_net S03_AXI_1 [get_bd_intf_pins axi_interconnect_1/S03_AXI] [get_bd_intf_pins hier_slow_ddr/M_AXI]
  connect_bd_intf_net -intf_net S_AXI_0_1 [get_bd_intf_ports S_AXI_MEM] [get_bd_intf_pins hier_slow_ddr/S_AXI_MEM]
  connect_bd_intf_net -intf_net axi_dma_arm_M_AXIS_MM2S [get_bd_intf_pins axi_dma_arm/M_AXIS_MM2S] [get_bd_intf_pins hier_core/S_AXIS_S2MM]
  connect_bd_intf_net -intf_net axi_dma_core_M_AXIS_MM2S [get_bd_intf_pins axi_dma_arm/S_AXIS_S2MM] [get_bd_intf_pins hier_core/M_AXIS_MM2S]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_interconnect_1/M00_AXI] [get_bd_intf_pins zynq_soc/S_AXI_HP0_FPD]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI1 [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins hier_uart/S_AXI_UART_arm]
  connect_bd_intf_net -intf_net axi_interconnect_arm_M01_AXI [get_bd_intf_pins axi_dma_arm/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_0/M01_AXI]
  connect_bd_intf_net -intf_net zync_ultra_core_M_AXI_HPM0_FPD [get_bd_intf_pins axi_interconnect_0/S00_AXI] [get_bd_intf_pins zynq_soc/M_AXI_HPM0_FPD]

  # Create port connections
  connect_bd_net -net axi_dma_arm_mm2s_introut [get_bd_pins axi_dma_arm/mm2s_introut] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net axi_dma_arm_s2mm_introut [get_bd_pins axi_dma_arm/s2mm_introut] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net clk_wiz_core_clk [get_bd_ports core_clk] [get_bd_pins axi_dma_arm/m_axi_mm2s_aclk] [get_bd_pins axi_dma_arm/m_axi_s2mm_aclk] [get_bd_pins axi_dma_arm/m_axi_sg_aclk] [get_bd_pins axi_dma_arm/s_axi_lite_aclk] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/M01_ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_1/ACLK] [get_bd_pins axi_interconnect_1/M00_ACLK] [get_bd_pins axi_interconnect_1/S00_ACLK] [get_bd_pins axi_interconnect_1/S01_ACLK] [get_bd_pins axi_interconnect_1/S02_ACLK] [get_bd_pins axi_interconnect_1/S03_ACLK] [get_bd_pins hier_clk_rst/core_clk] [get_bd_pins hier_core/axi_aclk] [get_bd_pins hier_slow_ddr/axi_aclk] [get_bd_pins hier_uart/aclk] [get_bd_pins zynq_soc/maxihpm0_fpd_aclk] [get_bd_pins zynq_soc/saxihp0_fpd_aclk]
  connect_bd_net -net core_rst_interconnect_aresetn [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins axi_interconnect_0/M01_ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_1/ARESETN] [get_bd_pins axi_interconnect_1/M00_ARESETN] [get_bd_pins axi_interconnect_1/S00_ARESETN] [get_bd_pins axi_interconnect_1/S01_ARESETN] [get_bd_pins axi_interconnect_1/S02_ARESETN] [get_bd_pins axi_interconnect_1/S03_ARESETN] [get_bd_pins hier_clk_rst/interconnect_aresetn] [get_bd_pins hier_core/interconnect_aresetn] [get_bd_pins hier_slow_ddr/axi_aresetn] [get_bd_pins hier_uart/interconnect_aresetn]
  connect_bd_net -net hier_clk_rst_peripheral_aresetn [get_bd_pins axi_dma_arm/axi_resetn] [get_bd_pins hier_clk_rst/peripheral_aresetn] [get_bd_pins hier_core/axi_resetn] [get_bd_pins hier_uart/peripheral_aresetn]
  connect_bd_net -net hier_core_mm2s_introut_0 [get_bd_ports mm2s_introut_0] [get_bd_pins hier_core/mm2s_introut_0]
  connect_bd_net -net hier_core_s2mm_introut_0 [get_bd_ports s2mm_introut_0] [get_bd_pins hier_core/s2mm_introut_0]
  connect_bd_net -net hier_uart_arm_uart_irq_0 [get_bd_pins hier_uart/arm_uart_irq_0] [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net hier_uart_arm_uart_irq_1 [get_bd_pins hier_uart/arm_uart_irq_1] [get_bd_pins xlconcat_0/In3]
  connect_bd_net -net hier_uart_arm_uart_irq_2 [get_bd_pins hier_uart/arm_uart_irq_2] [get_bd_pins xlconcat_0/In4]
  connect_bd_net -net hier_uart_arm_uart_irq_3 [get_bd_pins hier_uart/arm_uart_irq_3] [get_bd_pins xlconcat_0/In5]
  connect_bd_net -net hier_uart_core_uart_irq [get_bd_ports core_uart_irq_0] [get_bd_pins hier_uart/core_uart_irq]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins xlconcat_0/dout] [get_bd_pins zynq_soc/pl_ps_irq0]
  connect_bd_net -net zync_ultra_core_pl_clk0 [get_bd_pins hier_clk_rst/clk_in1] [get_bd_pins zynq_soc/pl_clk0]
  connect_bd_net -net zync_ultra_core_pl_resetn0 [get_bd_ports core_rstn] [get_bd_pins hier_clk_rst/reset] [get_bd_pins zynq_soc/pl_resetn0]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_arm/Data_SG] [get_bd_addr_segs zynq_soc/SAXIGP2/HP0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_arm/Data_MM2S] [get_bd_addr_segs zynq_soc/SAXIGP2/HP0_DDR_LOW] -force
  assign_bd_address -offset 0x00000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces axi_dma_arm/Data_S2MM] [get_bd_addr_segs zynq_soc/SAXIGP2/HP0_DDR_LOW] -force
  assign_bd_address -offset 0xA0040000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_soc/Data] [get_bd_addr_segs axi_dma_arm/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0xA0010000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_soc/Data] [get_bd_addr_segs hier_uart/axi_uartlite_0/S_AXI/Reg] -force
  assign_bd_address -offset 0xA0000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_soc/Data] [get_bd_addr_segs hier_uart/axi_uartlite_1/S_AXI/Reg] -force
  assign_bd_address -offset 0xA0020000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_soc/Data] [get_bd_addr_segs hier_uart/axi_uartlite_2/S_AXI/Reg] -force
  assign_bd_address -offset 0xA0030000 -range 0x00001000 -target_address_space [get_bd_addr_spaces zynq_soc/Data] [get_bd_addr_segs hier_uart/axi_uartlite_3/S_AXI/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x010000000000 -target_address_space [get_bd_addr_spaces hier_core/axi_dma_core/Data_SG] [get_bd_addr_segs M_AXI_DMA/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x010000000000 -target_address_space [get_bd_addr_spaces hier_core/axi_dma_core/Data_MM2S] [get_bd_addr_segs M_AXI_DMA/Reg] -force
  assign_bd_address -offset 0x00000000 -range 0x010000000000 -target_address_space [get_bd_addr_spaces hier_core/axi_dma_core/Data_S2MM] [get_bd_addr_segs M_AXI_DMA/Reg] -force
  assign_bd_address -offset 0x60010000 -range 0x00001000 -target_address_space [get_bd_addr_spaces S_AXI_MMIO] [get_bd_addr_segs hier_core/axi_dma_core/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x60001000 -range 0x00001000 -target_address_space [get_bd_addr_spaces S_AXI_MMIO] [get_bd_addr_segs hier_uart/axi_uart16550_core_1/S_AXI/Reg] -force
  assign_bd_address -offset 0x60002000 -range 0x00001000 -target_address_space [get_bd_addr_spaces S_AXI_MMIO] [get_bd_addr_segs hier_uart/axi_uart16550_core_2/S_AXI/Reg] -force
  assign_bd_address -offset 0x60003000 -range 0x00001000 -target_address_space [get_bd_addr_spaces S_AXI_MMIO] [get_bd_addr_segs hier_uart/axi_uart16550_core_3/S_AXI/Reg] -force
  assign_bd_address -offset 0x60004000 -range 0x00001000 -target_address_space [get_bd_addr_spaces S_AXI_MMIO] [get_bd_addr_segs hier_uart/axi_uart16550_core_4/S_AXI/Reg] -force
  assign_bd_address -offset 0x60000000 -range 0x00001000 -target_address_space [get_bd_addr_spaces S_AXI_MMIO] [get_bd_addr_segs hier_uart/axi_uartlite_core_0/S_AXI/Reg] -force
  assign_bd_address -offset 0x000800000000 -range 0x80000000 -target_address_space [get_bd_addr_spaces S_AXI_MEM] [get_bd_addr_segs zynq_soc/SAXIGP2/HP0_DDR_LOW] -force


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


