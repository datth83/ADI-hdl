source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

set project_name [get_env_param ADI_PROJECT_NAME adrv9001_zed]

adi_project $project_name 0 [list \
  CMOS_LVDS_N 1 \
]
adi_project_files $project_name [list \
  "system_top.v" \
  "system_constr.xdc" \
  "cmos_constr.xdc" \
  "$ad_hdl_dir/library/common/ad_iobuf.v" \
  "$ad_hdl_dir/projects/common/zed/zed_system_constr.xdc" ]

set_property PROCESSING_ORDER LATE [get_files system_constr.xdc]

adi_project_run $project_name

