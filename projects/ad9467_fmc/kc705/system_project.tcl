# load script
source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

set project_name [get_env_param ADI_PROJECT_NAME ad9467_fmc_kc705]

adi_project $project_name
adi_project_files $project_name [list \
  "../common/ad9467_spi.v" \
  "$ad_hdl_dir/library/common/ad_iobuf.v" \
  "system_top.v" \
  "system_constr.xdc" \
  "$ad_hdl_dir/projects/common/kc705/kc705_system_constr.xdc"]

adi_project_run $project_name

