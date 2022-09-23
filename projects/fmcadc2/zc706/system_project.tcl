source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

# get_env_param retrieves parameter value from the environment if exists,
# other case use the default value
#
#   Use over-writable parameters from the environment.
#
#    e.g.
#      make RX_JESD_L=8  

# Parameter description:
#   RX_JESD_M : Number of converters per link
#   RX_JESD_L : Number of lanes per link
#   RX_JESD_S : Number of samples per frame
#   RX_JESD_NP : Number of bits per sample

set project_name [get_env_param ADI_PROJECT_NAME fmcadc2_zc706]

adi_project $project_name 0 [list \
  RX_JESD_M    [get_env_param RX_JESD_M    1 ] \
  RX_JESD_L    [get_env_param RX_JESD_L    8 ] \
  RX_JESD_S    [get_env_param RX_JESD_S    4 ] \
  RX_JESD_NP   [get_env_param RX_JESD_NP   16] \
]

adi_project_files $project_name [list \
  "../common/fmcadc2_spi.v" \
  "system_top.v" \
  "system_constr.xdc" \
  "$ad_hdl_dir/library/common/ad_iobuf.v" \
  "$ad_hdl_dir/library/common/ad_sysref_gen.v" \
  "$ad_hdl_dir/projects/common/zc706/zc706_plddr3_constr.xdc" \
  "$ad_hdl_dir/projects/common/zc706/zc706_system_constr.xdc" ]

adi_project_run $project_name
