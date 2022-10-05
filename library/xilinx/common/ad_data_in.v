// ***************************************************************************
// ***************************************************************************
// Copyright 2014 - 2017 (c) Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module ad_data_in #(
  parameter   SINGLE_ENDED = 0,
  parameter   FPGA_TECHNOLOGY = 0,
  parameter   IDDR_CLK_EDGE ="SAME_EDGE",
  parameter   IODELAY_ENABLE = 1,
  parameter   IODELAY_CTRL = 0,
  parameter   IODELAY_GROUP = "dev_if_delay_group",
  parameter   REFCLK_FREQUENCY = 200
) (

  // data interface

  input               rx_clk,
  input               rx_data_in_p,
  input               rx_data_in_n,
  output              rx_data_p,
  output              rx_data_n,

  // delay-data interface

  input               up_clk,
  input               up_dld,
  input       [ 4:0]  up_dwdata,
  output      [ 4:0]  up_drdata,

  // delay-cntrl interface

  input               delay_clk,
  input               delay_rst,
  output              delay_locked
);

  // internal parameters

  localparam  NONE = -1;
  localparam  SEVEN_SERIES = 1;
  localparam  ULTRASCALE = 2;
  localparam  ULTRASCALE_PLUS = 3;

  localparam  IODELAY_CTRL_ENABLED = (IODELAY_ENABLE == 1) ? IODELAY_CTRL : 0;
  localparam  IODELAY_CTRL_SIM_DEVICE = (FPGA_TECHNOLOGY == ULTRASCALE_PLUS) ? "ULTRASCALE" :
    (FPGA_TECHNOLOGY == ULTRASCALE) ? "ULTRASCALE" : "7SERIES";

  localparam  IODELAY_FPGA_TECHNOLOGY = (IODELAY_ENABLE == 1) ? FPGA_TECHNOLOGY : NONE;
  localparam  IODELAY_SIM_DEVICE = (FPGA_TECHNOLOGY == ULTRASCALE_PLUS) ? "ULTRASCALE_PLUS" :
    (FPGA_TECHNOLOGY == ULTRASCALE) ? "ULTRASCALE" : "7SERIES";

  // internal signals

  wire          rx_data_ibuf_s;
  wire          rx_data_idelay_s;
  wire  [ 8:0]  up_drdata_s;

  // delay controller

  generate
  if (IODELAY_CTRL_ENABLED == 0) begin
    assign delay_locked = 1'b1;
  end else begin
    (* IODELAY_GROUP = IODELAY_GROUP *)
    IDELAYCTRL #(
      .SIM_DEVICE (IODELAY_CTRL_SIM_DEVICE)
    ) i_delay_ctrl (
      .RST (delay_rst),
      .REFCLK (delay_clk),
      .RDY (delay_locked));
  end
  endgenerate

  // receive data interface, ibuf -> idelay -> iddr

  // ibuf

  generate
  if (SINGLE_ENDED == 1) begin
    IBUF i_rx_data_ibuf (
      .I (rx_data_in_p),
      .O (rx_data_ibuf_s));
  end else begin
    IBUFDS i_rx_data_ibuf (
      .I (rx_data_in_p),
      .IB (rx_data_in_n),
      .O (rx_data_ibuf_s));
  end
  endgenerate

  // idelay

  generate
  if (IODELAY_FPGA_TECHNOLOGY == SEVEN_SERIES) begin
    (* IODELAY_GROUP = IODELAY_GROUP *)
    IDELAYE2 #(
      .CINVCTRL_SEL ("FALSE"),
      .DELAY_SRC ("IDATAIN"),
      .HIGH_PERFORMANCE_MODE ("FALSE"),
      .IDELAY_TYPE ("VAR_LOAD"),
      .IDELAY_VALUE (0),
      .REFCLK_FREQUENCY (REFCLK_FREQUENCY),
      .PIPE_SEL ("FALSE"),
      .SIGNAL_PATTERN ("DATA")
    ) i_rx_data_idelay (
      .CE (1'b0),
      .INC (1'b0),
      .DATAIN (1'b0),
      .LDPIPEEN (1'b0),
      .CINVCTRL (1'b0),
      .REGRST (1'b0),
      .C (up_clk),
      .IDATAIN (rx_data_ibuf_s),
      .DATAOUT (rx_data_idelay_s),
      .LD (up_dld),
      .CNTVALUEIN (up_dwdata),
      .CNTVALUEOUT (up_drdata));
  end
  endgenerate

  generate
  if ((IODELAY_FPGA_TECHNOLOGY == ULTRASCALE) || (IODELAY_FPGA_TECHNOLOGY == ULTRASCALE_PLUS)) begin
    assign up_drdata = up_drdata_s[8:4];
    (* IODELAY_GROUP = IODELAY_GROUP *)
    IDELAYE3 #(
      .CASCADE ("NONE"),                    // Cascade setting  (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
      .DELAY_FORMAT ("COUNT"),              // Units of the DELAY_VALUE  (COUNT, TIME)
      .DELAY_SRC ("IDATAIN"),               // Delay input  (DATAIN, IDATAIN)
      .DELAY_TYPE ("VAR_LOAD"),             // Set the type of tap delay line  (FIXED, VARIABLE, VAR_LOAD)
      .DELAY_VALUE (0),                     // Input delay value setting
      .IS_CLK_INVERTED (1'b0),              // Optional inversion for CLK
      .IS_RST_INVERTED (1'b0),              // Optional inversion for RST
      .REFCLK_FREQUENCY (REFCLK_FREQUENCY), // IDELAYCTRL clock input frequency in MHz  (200.0-800.0)
      .SIM_DEVICE (IODELAY_SIM_DEVICE),     // Set the device version for simulation functionality
      .UPDATE_MODE ("ASYNC")                // Determines when updates to the delay will take effect  (ASYNC, MANUAL, SYNC)
    ) i_rx_data_idelay (
      .CASC_RETURN (1'b0),              // 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
      .CASC_IN (1'b0),                  // 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
      .CASC_OUT (),                     // 1-bit output: Cascade delay output to ODELAY input cascade
      .CE (1'b0),                       // 1-bit input: Active-High enable increment/decrement input
      .CLK (up_clk),                    // 1-bit input: Clock input
      .INC (1'b0),                      // 1-bit input: Increment / Decrement tap delay input
      .LOAD (up_dld),                   // 1-bit input: Load DELAY_VALUE input
      .CNTVALUEIN ({up_dwdata, 4'd0}),  // 9-bit input: Counter value input
      .CNTVALUEOUT (up_drdata_s),       // 9-bit output: Counter value output
      .DATAIN (1'b0),                   // 1-bit input: Data input from the logic
      .IDATAIN (rx_data_ibuf_s),        // 1-bit input: Data input from the IOBUF
      .DATAOUT (rx_data_idelay_s),      // 1-bit output: Delayed data output
      .RST (1'b0),                      // 1-bit input: Asynchronous Reset to the DELAY_VALUE
      .EN_VTC (~up_dld));               // 1-bit input: Keep delay constant over VT
  end
  endgenerate

  generate
  if (IODELAY_FPGA_TECHNOLOGY == NONE) begin
    assign rx_data_idelay_s = rx_data_ibuf_s;
    assign up_drdata = 5'd0;
  end
  endgenerate

  // iddr

  generate
  if (FPGA_TECHNOLOGY == SEVEN_SERIES) begin
    IDDR #(
      .DDR_CLK_EDGE (IDDR_CLK_EDGE), // "OPPOSITE_EDGE", "SAME_EDGE", "SAME_EDGE_PIPELINED"
      .INIT_Q1 (1'b0),               // Initial value of Q1: 1'b0 or 1'b1
      .INIT_Q2 (1'b0),               // Initial value of Q2: 1'b0 or 1'b1
      .SRTYPE ("SYNC")               // Set/Reset type: "SYNC" or "ASYNC"
    ) i_rx_data_iddr (
      .CE (1'b1),            // 1-bit clock enable input
      .R (1'b0),             // 1-bit reset
      .S (1'b0),             // 1-bit set
      .C (rx_clk),           // 1-bit clock input
      .D (rx_data_idelay_s), // 1-bit DDR data input
      .Q1 (rx_data_p),       // 1-bit output for positive edge of clock
      .Q2 (rx_data_n));      // 1-bit output for negative edge of clock
  end
  endgenerate

  generate
  if ((FPGA_TECHNOLOGY == ULTRASCALE) || (FPGA_TECHNOLOGY == ULTRASCALE_PLUS)) begin
    IDDRE1 #(
      .DDR_CLK_EDGE (IDDR_CLK_EDGE), // IDDRE1 mode (OPPOSITE_EDGE, SAME_EDGE, SAME_EDGE_PIPELINED)
      .IS_CB_INVERTED (1'b0),         // Optional inversion for CB
      .IS_C_INVERTED (1'b0)           // Optional inversion for C
    ) i_rx_data_iddr (
      .R (1'b0),             // 1-bit output: Registered parallel output 1
      .C (rx_clk),           // 1-bit output: Registered parallel output 2
      .CB (~rx_clk),         // 1-bit input: High-speed clock
      .D (rx_data_idelay_s), // 1-bit input: Inversion of High-speed clock C
      .Q1 (rx_data_p),       // 1-bit input: Serial Data Input
      .Q2 (rx_data_n));      // 1-bit input: Active-High Async Reset
  end
  endgenerate

endmodule
