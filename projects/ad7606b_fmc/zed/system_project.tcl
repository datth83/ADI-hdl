
source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

if {[info exists ::env(SIMPLE_STATUS)]} {
  set SIMPLE_STATUS [get_env_param SIMPLE_STATUS 0]
} elseif {![info exists SIMPLE_STATUS]} {
  set SIMPLE_STATUS 0
}

adi_project ad7606b_fmc_zed 0 [list \
  SIMPLE_STATUS $SIMPLE_STATUS \
]

adi_project_files ad7606b_fmc_zed [list \
  "$ad_hdl_dir/library/common/ad_iobuf.v" \
  "$ad_hdl_dir/projects/common/zed/zed_system_constr.xdc" \
  "system_top.v" \
  "system_constr.xdc"]

adi_project_run ad7606b_fmc_zed
