
# ad40xx_fmc SPI interface

set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS25} [get_ports ad3552r_spi_sdio[0]]       ; ##  LA02_P
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS25} [get_ports ad3552r_spi_sdio[1]]       ; ##  LA02_N
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS25} [get_ports ad3552r_spi_sdio[2]]       ; ##  LA03_P
set_property -dict {PACKAGE_PIN P22 IOSTANDARD LVCMOS25} [get_ports ad3552r_spi_sdio[3]]       ; ##  LA03_N

set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS25} [get_ports ad3552r_spi_sclk]          ; ##  LA00_P_CC
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS25} [get_ports ad3552r_spi_cs]            ; ##  LA00_N_CC

set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS25} [get_ports ad3552r_ldacn]             ; ##  LA05_P
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS25} [get_ports ad3552r_resetn]            ; ##  LA05_N
set_property -dict {PACKAGE_PIN M21 IOSTANDARD LVCMOS25} [get_ports ad3552r_alertn]            ; ##  LA04_P
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS25} [get_ports ad3552r_qspi_sel]          ; ##  LA04_N

set_property -dict {PACKAGE_PIN L21 IOSTANDARD LVCMOS25} [get_ports ad3552r_gpio_6]            ; ##  LA06_P VADJ POWER
set_property -dict {PACKAGE_PIN L22 IOSTANDARD LVCMOS25} [get_ports ad3552r_gpio_7]            ; ##  LA06_N
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS25} [get_ports ad3552r_gpio_8]            ; ##  LA07_P
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS25} [get_ports ad3552r_gpio_9]            ; ##  LA07_N
