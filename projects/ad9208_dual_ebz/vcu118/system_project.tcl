source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

set project_name [get_env_param ADI_PROJECT_NAME ad9208_dual_ebz_vcu118]

adi_project $project_name
adi_project_files $project_name [list \
  "system_top.v" \
  "system_constr.xdc"\
  "$ad_hdl_dir/library/common/ad_iobuf.v" \
  "$ad_hdl_dir/projects/daq3/common/daq3_spi.v" \
  "$ad_hdl_dir/projects/common/vcu118/vcu118_system_constr.xdc" ]

## To improve timing in DDR4 MIG
#set_property strategy Performance_Retiming [get_runs impl_1]
set_property strategy Performance_SpreadSLLs [get_runs impl_1]

adi_project_run $project_name

