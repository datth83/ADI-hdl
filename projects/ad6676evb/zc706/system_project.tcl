source ../../../scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

# get_env_param retrieves parameter value from the environment if exists,
# other case use the default value
#
#   Use over-writable parameters from the environment.
#
#    e.g.
#      make RX_JESD_L=1 
#      make RX_JESD_L=2   

# Parameter description:
#   RX_JESD_L : Number of lanes per link

set project_name [get_env_param ADI_PROJECT_NAME ad6676evb_zc706]

adi_project $project_name 0 [list \
  RX_JESD_L    [get_env_param RX_JESD_L    2 ] \
]

adi_project_files $project_name [list \
  "system_top.v" \
  "system_constr.xdc"\
  "$ad_hdl_dir/library/common/ad_iobuf.v" \
  "$ad_hdl_dir/library/common/ad_sysref_gen.v" \
  "$ad_hdl_dir/projects/common/zc706/zc706_system_constr.xdc" ]

adi_project_run $project_name


