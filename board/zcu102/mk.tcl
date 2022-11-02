set device xczu9eg-ffvb1156-2-e
set board xilinx.com:zcu102:part0:3.3

set script_dir [file dirname [info script]]

set src_files [list \
    "[file normalize "${script_dir}/rtl/system_top.v"]" \
    "[file normalize "${script_dir}/rtl/addr_mapper.v"]" \
]

set xdc_files [list \
    "[file normalize "${script_dir}/constr/constr.xdc"]" \
]

source ${script_dir}/../common.tcl