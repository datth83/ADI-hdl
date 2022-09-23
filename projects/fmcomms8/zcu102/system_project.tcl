source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

set project_name [get_env_param ADI_PROJECT_NAME fmcomms8_zcu102]

adi_project $project_name 0 [list \
  RX_JESD_M       [get_env_param RX_JESD_M     8 ] \
  RX_JESD_L       [get_env_param RX_JESD_L     4 ] \
  RX_JESD_S       [get_env_param RX_JESD_S     1 ] \
  TX_JESD_M       [get_env_param TX_JESD_M     8 ] \
  TX_JESD_L       [get_env_param TX_JESD_L     8 ] \
  TX_JESD_S       [get_env_param TX_JESD_S     1 ] \
  RX_OS_JESD_M    [get_env_param RX_OS_JESD_M  4 ] \
  RX_OS_JESD_L    [get_env_param RX_OS_JESD_L  4 ] \
  RX_OS_JESD_S    [get_env_param RX_OS_JESD_S  1 ] \
]
adi_project_files  $project_name [list \
  "system_top.v" \
  "system_constr.xdc"\
  "../common/fmcomms8_spi.v" \
  "$ad_hdl_dir/library/common/ad_iobuf.v" \
  "$ad_hdl_dir/projects/common/zcu102/zcu102_system_constr.xdc" ]

adi_project_run $project_name
