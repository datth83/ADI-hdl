source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

set project_name [get_env_param ADI_PROJECT_NAME fmcomms11_zc706]

adi_project $project_name
adi_project_files $project_name [list \
  "../common/fmcomms11_spi.v" \
  "system_top.v" \
  "system_constr.xdc"\
  "$ad_hdl_dir/library/common/ad_iobuf.v" \
  "$ad_hdl_dir/projects/common/zc706/zc706_plddr3_constr.xdc" \
  "$ad_hdl_dir/projects/common/zc706/zc706_system_constr.xdc" ]

set_property part "xc7z045ffg900-3" [get_runs synth_1]
set_property part "xc7z045ffg900-3" [get_runs impl_1]
adi_project_run $project_name

