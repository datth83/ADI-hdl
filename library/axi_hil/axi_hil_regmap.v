// ***************************************************************************
// ***************************************************************************
// Copyright 2014 - 2019 (c) Analog Devices, Inc. All rights reserved.
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

module axi_hil_regmap #(
    parameter ID = 0,
    parameter CORE_MAGIC = 0,
    parameter CORE_VERSION = 0,
    parameter ADC_0_THRESHOLD = 0,
    parameter ADC_1_THRESHOLD = 0,
    parameter ADC_2_THRESHOLD = 0,
    parameter ADC_3_THRESHOLD = 0,
    parameter ADC_0_DELAY_PRESCALER = 0,
    parameter ADC_1_DELAY_PRESCALER = 0,
    parameter ADC_2_DELAY_PRESCALER = 0,
    parameter ADC_3_DELAY_PRESCALER = 0,
    parameter DAC_0_MIN_VALUE = 0,
    parameter DAC_1_MIN_VALUE = 0,
    parameter DAC_2_MIN_VALUE = 0,
    parameter DAC_3_MIN_VALUE = 0,
    parameter DAC_0_MAX_VALUE = 0,
    parameter DAC_1_MAX_VALUE = 0,
    parameter DAC_2_MAX_VALUE = 0,
    parameter DAC_3_MAX_VALUE = 0,
    parameter DAC_0_PULSE_PRESCALER = 0,
    parameter DAC_1_PULSE_PRESCALER = 0,
    parameter DAC_2_PULSE_PRESCALER = 0,
    parameter DAC_3_PULSE_PRESCALER = 0,
    parameter DAC_0_BYPASS_MUX = 0,
    parameter DAC_1_BYPASS_MUX = 0,
    parameter DAC_2_BYPASS_MUX = 0,
    parameter DAC_3_BYPASS_MUX = 0
)(
  input                   ext_clk,

  // control and data signals
  output                  resetn,
  output                  dac_0_bypass_mux,
  output                  dac_1_bypass_mux,
  output                  dac_2_bypass_mux,
  output                  dac_3_bypass_mux,
  output      [15:0]      adc_0_threshold,
  output      [15:0]      adc_1_threshold,
  output      [15:0]      adc_2_threshold,
  output      [15:0]      adc_3_threshold,
  output      [31:0]      adc_0_delay_prescaler,
  output      [31:0]      adc_1_delay_prescaler,
  output      [31:0]      adc_2_delay_prescaler,
  output      [31:0]      adc_3_delay_prescaler,
  output      [15:0]      dac_0_min_value,
  output      [15:0]      dac_1_min_value,
  output      [15:0]      dac_2_min_value,
  output      [15:0]      dac_3_min_value,
  output      [15:0]      dac_0_max_value,
  output      [15:0]      dac_1_max_value,
  output      [15:0]      dac_2_max_value,
  output      [15:0]      dac_3_max_value,
  output      [31:0]      dac_0_pulse_prescaler,
  output      [31:0]      dac_1_pulse_prescaler,
  output      [31:0]      dac_2_pulse_prescaler,
  output      [31:0]      dac_3_pulse_prescaler,

  // processor interface
  input                   up_rstn,
  input                   up_clk,
  input                   up_wreq,
  input       [7:0]       up_waddr,
  input       [31:0]      up_wdata,
  output reg              up_wack,
  input                   up_rreq,
  input       [7:0]       up_raddr,
  output reg  [31:0]      up_rdata,
  output reg              up_rack
);

  // internal registers
  reg   [15:0]  up_adc_0_threshold;
  reg   [31:0]  up_adc_0_delay_prescaler;
  reg   [15:0]  up_dac_0_min_value;
  reg   [15:0]  up_dac_0_max_value;

  reg   [15:0]  up_adc_1_threshold;
  reg   [31:0]  up_adc_1_delay_prescaler;
  reg   [15:0]  up_dac_1_min_value;
  reg   [15:0]  up_dac_1_max_value;

  reg   [15:0]  up_adc_2_threshold;
  reg   [31:0]  up_adc_2_delay_prescaler;
  reg   [15:0]  up_dac_2_min_value; 
  reg   [15:0]  up_dac_2_max_value;

  reg   [15:0]  up_adc_3_threshold;
  reg   [31:0]  up_adc_3_delay_prescaler;
  reg   [15:0]  up_dac_3_min_value;
  reg   [15:0]  up_dac_3_max_value;

  reg   [31:0]  up_dac_0_pulse_prescaler;
  reg   [31:0]  up_dac_1_pulse_prescaler;
  reg   [31:0]  up_dac_2_pulse_prescaler;
  reg   [31:0]  up_dac_3_pulse_prescaler;

  reg           up_dac_0_bypass_mux;
  reg           up_dac_1_bypass_mux;
  reg           up_dac_2_bypass_mux;
  reg           up_dac_3_bypass_mux;

  reg   [31:0]  up_scratch = 'd0;
  reg           up_reset = 1'd0;

  always @(posedge up_clk) begin
    if (up_rstn == 1'b0) begin
      up_scratch <= 'd0;
      up_wack <= 1'd0;
      up_reset <= 1'd1;
      up_adc_0_threshold <= ADC_0_THRESHOLD;
      up_adc_1_threshold <= ADC_1_THRESHOLD;
      up_adc_2_threshold <= ADC_2_THRESHOLD;
      up_adc_3_threshold <= ADC_3_THRESHOLD;
      up_adc_0_delay_prescaler <= ADC_0_DELAY_PRESCALER;
      up_adc_1_delay_prescaler <= ADC_1_DELAY_PRESCALER;
      up_adc_2_delay_prescaler <= ADC_2_DELAY_PRESCALER;
      up_adc_3_delay_prescaler <= ADC_3_DELAY_PRESCALER;
      up_dac_0_min_value <= DAC_0_MIN_VALUE;
      up_dac_1_min_value <= DAC_1_MIN_VALUE;
      up_dac_2_min_value <= DAC_2_MIN_VALUE;
      up_dac_3_min_value <= DAC_3_MIN_VALUE;
      up_dac_0_max_value <= DAC_0_MAX_VALUE;
      up_dac_1_max_value <= DAC_1_MAX_VALUE;
      up_dac_2_max_value <= DAC_2_MAX_VALUE;
      up_dac_3_max_value <= DAC_3_MAX_VALUE;
      up_dac_0_bypass_mux <= DAC_0_BYPASS_MUX;
      up_dac_1_bypass_mux <= DAC_1_BYPASS_MUX;
      up_dac_2_bypass_mux <= DAC_2_BYPASS_MUX;
      up_dac_3_bypass_mux <= DAC_3_BYPASS_MUX;
      up_dac_0_pulse_prescaler <= DAC_0_PULSE_PRESCALER;
      up_dac_1_pulse_prescaler <= DAC_1_PULSE_PRESCALER;
      up_dac_2_pulse_prescaler <= DAC_2_PULSE_PRESCALER;
      up_dac_3_pulse_prescaler <= DAC_3_PULSE_PRESCALER;
    end else begin
      up_wack <= up_wreq;
      up_reset <= 1'b0;
      if (up_wreq == 1'b1) begin
        case (up_waddr)
          8'h02: up_scratch <= up_wdata;
          8'h20: up_reset  <= up_wdata[0];
          8'h30: up_adc_0_threshold <= up_wdata[15:0];
          8'h31: up_adc_1_threshold <= up_wdata[15:0];
          8'h32: up_adc_2_threshold <= up_wdata[15:0];
          8'h33: up_adc_3_threshold <= up_wdata[15:0];
          8'h40: up_dac_0_min_value <= up_wdata[15:0];
          8'h41: up_dac_1_min_value <= up_wdata[15:0];
          8'h42: up_dac_2_min_value <= up_wdata[15:0];
          8'h43: up_dac_3_min_value <= up_wdata[15:0];
          8'h50: up_dac_0_max_value <= up_wdata[15:0];
          8'h51: up_dac_1_max_value <= up_wdata[15:0];
          8'h52: up_dac_2_max_value <= up_wdata[15:0];
          8'h53: up_dac_3_max_value <= up_wdata[15:0];
          8'h60: up_adc_0_delay_prescaler <= up_wdata;
          8'h61: up_adc_1_delay_prescaler <= up_wdata;
          8'h62: up_adc_2_delay_prescaler <= up_wdata;
          8'h63: up_adc_3_delay_prescaler <= up_wdata;
          8'h70: up_dac_0_bypass_mux <= up_wdata[0];
          8'h71: up_dac_1_bypass_mux <= up_wdata[0];
          8'h72: up_dac_2_bypass_mux <= up_wdata[0];
          8'h73: up_dac_3_bypass_mux <= up_wdata[0];
          8'h80: up_dac_0_pulse_prescaler <= up_wdata;
          8'h81: up_dac_1_pulse_prescaler <= up_wdata;
          8'h82: up_dac_2_pulse_prescaler <= up_wdata;
          8'h83: up_dac_3_pulse_prescaler <= up_wdata;
          default:; // nothing
        endcase
      end
    end
  end

  always @(posedge up_clk) begin
    if (up_rstn == 1'b0) begin
      up_rack <= 1'd0;
      up_rdata <= 'd0;
    end else begin
      up_rack <= up_rreq;
      up_rdata <= 32'd0;
      if (up_rreq == 1'b1) begin
        case (up_raddr)
          8'h00: up_rdata <= CORE_VERSION;
          8'h01: up_rdata <= ID;
          8'h02: up_rdata <= up_scratch;
          8'h03: up_rdata <= CORE_MAGIC;
          8'h20: up_rdata <= up_reset;
          8'h30: up_rdata <= up_adc_0_threshold;
          8'h31: up_rdata <= up_adc_1_threshold;
          8'h32: up_rdata <= up_adc_2_threshold;
          8'h33: up_rdata <= up_adc_3_threshold; 
          8'h40: up_rdata <= up_dac_0_min_value;
          8'h41: up_rdata <= up_dac_1_min_value;
          8'h42: up_rdata <= up_dac_2_min_value;
          8'h43: up_rdata <= up_dac_3_min_value;
          8'h50: up_rdata <= up_dac_0_max_value;
          8'h51: up_rdata <= up_dac_1_max_value;
          8'h52: up_rdata <= up_dac_2_max_value;
          8'h53: up_rdata <= up_dac_3_max_value;
          8'h60: up_rdata <= up_adc_0_delay_prescaler;
          8'h61: up_rdata <= up_adc_1_delay_prescaler;
          8'h62: up_rdata <= up_adc_2_delay_prescaler;
          8'h63: up_rdata <= up_adc_3_delay_prescaler;
          8'h70: up_rdata <= up_dac_0_bypass_mux;
          8'h71: up_rdata <= up_dac_1_bypass_mux;
          8'h72: up_rdata <= up_dac_2_bypass_mux;
          8'h73: up_rdata <= up_dac_3_bypass_mux;
          8'h80: up_rdata <= up_dac_0_pulse_prescaler;
          8'h81: up_rdata <= up_dac_1_pulse_prescaler;
          8'h82: up_rdata <= up_dac_2_pulse_prescaler;
          8'h83: up_rdata <= up_dac_3_pulse_prescaler;
          default: up_rdata <= 'd0;
        endcase
      end
    end
  end

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_adc_0_threshold (
    .in_clk(up_clk),
    .in_data(up_adc_0_threshold),
    .out_clk(ext_clk),
    .out_data(adc_0_threshold)
  );

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_adc_1_threshold (
    .in_clk(up_clk),
    .in_data(up_adc_1_threshold),
    .out_clk(ext_clk),
    .out_data(adc_1_threshold)
  );

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_adc_2_threshold (
    .in_clk(up_clk),
    .in_data(up_adc_2_threshold),
    .out_clk(ext_clk),
    .out_data(adc_2_threshold)
  );

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_adc_3_threshold (
    .in_clk(up_clk),
    .in_data(up_adc_3_threshold),
    .out_clk(ext_clk),
    .out_data(adc_3_threshold)
  );

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_dac_0_min_value (
    .in_clk(up_clk),
    .in_data(up_dac_0_min_value),
    .out_clk(ext_clk),
    .out_data(dac_0_min_value)
  );

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_dac_1_min_value (
    .in_clk(up_clk),
    .in_data(up_dac_1_min_value),
    .out_clk(ext_clk),
    .out_data(dac_1_min_value)
  );

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_dac_2_min_value (
    .in_clk(up_clk),
    .in_data(up_dac_2_min_value),
    .out_clk(ext_clk),
    .out_data(dac_2_min_value)
  );

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_dac_3_min_value (
    .in_clk(up_clk),
    .in_data(up_dac_3_min_value),
    .out_clk(ext_clk),
    .out_data(dac_3_min_value)
  );

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_dac_0_max_value (
    .in_clk(up_clk),
    .in_data(up_dac_0_max_value),
    .out_clk(ext_clk),
    .out_data(dac_0_max_value)
  );

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_dac_1_max_value (
    .in_clk(up_clk),
    .in_data(up_dac_1_max_value),
    .out_clk(ext_clk),
    .out_data(dac_1_max_value)
  );

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_dac_2_max_value (
    .in_clk(up_clk),
    .in_data(up_dac_2_max_value),
    .out_clk(ext_clk),
    .out_data(dac_2_max_value)
  );

  sync_data #(
    .NUM_OF_BITS (16),
    .ASYNC_CLK (1)
  ) sync_dac_3_max_value (
    .in_clk(up_clk),
    .in_data(up_dac_3_max_value),
    .out_clk(ext_clk),
    .out_data(dac_3_max_value)
  );

  sync_data #(
    .NUM_OF_BITS (32),
    .ASYNC_CLK (1)
  ) sync_adc_0_delay_prescaler (
    .in_clk(up_clk),
    .in_data(up_adc_0_delay_prescaler),
    .out_clk(ext_clk),
    .out_data(adc_0_delay_prescaler)
  );

  sync_data #(
    .NUM_OF_BITS (32),
    .ASYNC_CLK (1)
  ) sync_adc_1_delay_prescaler (
    .in_clk(up_clk),
    .in_data(up_adc_1_delay_prescaler),
    .out_clk(ext_clk),
    .out_data(adc_1_delay_prescaler)
  );

  sync_data #(
    .NUM_OF_BITS (32),
    .ASYNC_CLK (1)
  ) sync_adc_2_delay_prescaler (
    .in_clk(up_clk),
    .in_data(up_adc_2_delay_prescaler),
    .out_clk(ext_clk),
    .out_data(adc_2_delay_prescaler)
  );

  sync_data #(
    .NUM_OF_BITS (32),
    .ASYNC_CLK (1)
  ) sync_adc_3_delay_prescaler (
    .in_clk(up_clk),
    .in_data(up_adc_3_delay_prescaler),
    .out_clk(ext_clk),
    .out_data(adc_3_delay_prescaler)
  );

  sync_data #(
    .NUM_OF_BITS (1),
    .ASYNC_CLK (1)
  ) sync_dac_0_bypass_mux (
    .in_clk(up_clk),
    .in_data(up_dac_0_bypass_mux),
    .out_clk(ext_clk),
    .out_data(dac_0_bypass_mux)
  );

  sync_data #(
    .NUM_OF_BITS (1),
    .ASYNC_CLK (1)
  ) sync_dac_1_bypass_mux (
    .in_clk(up_clk),
    .in_data(up_dac_1_bypass_mux),
    .out_clk(ext_clk),
    .out_data(dac_1_bypass_mux)
  );

  sync_data #(
    .NUM_OF_BITS (1),
    .ASYNC_CLK (1)
  ) sync_dac_2_bypass_mux (
    .in_clk(up_clk),
    .in_data(up_dac_2_bypass_mux),
    .out_clk(ext_clk),
    .out_data(dac_2_bypass_mux)
  );

  sync_data #(
    .NUM_OF_BITS (1),
    .ASYNC_CLK (1)
  ) sync_dac_3_bypass_mux (
    .in_clk(up_clk),
    .in_data(up_dac_3_bypass_mux),
    .out_clk(ext_clk),
    .out_data(dac_3_bypass_mux)
  );

  sync_data #(
    .NUM_OF_BITS (32),
    .ASYNC_CLK (1)
  ) sync_dac_0_pulse_prescaler (
    .in_clk(up_clk),
    .in_data(up_dac_0_pulse_prescaler),
    .out_clk(ext_clk),
    .out_data(dac_0_pulse_prescaler)
  );

  sync_data #(
    .NUM_OF_BITS (32),
    .ASYNC_CLK (1)
  ) sync_dac_1_pulse_prescaler (
    .in_clk(up_clk),
    .in_data(up_dac_1_pulse_prescaler),
    .out_clk(ext_clk),
    .out_data(dac_1_pulse_prescaler)
  );

  sync_data #(
    .NUM_OF_BITS (32),
    .ASYNC_CLK (1)
  ) sync_dac_2_pulse_prescaler (
    .in_clk(up_clk),
    .in_data(up_dac_2_pulse_prescaler),
    .out_clk(ext_clk),
    .out_data(dac_2_pulse_prescaler)
  );
  
  sync_data #(
    .NUM_OF_BITS (32),
    .ASYNC_CLK (1)
  ) sync_dac_3_pulse_prescaler (
    .in_clk(up_clk),
    .in_data(up_dac_3_pulse_prescaler),
    .out_clk(ext_clk),
    .out_data(dac_3_pulse_prescaler)
  );

  ad_rst i_d_rst_reg (
      .rst_async (up_reset),
      .clk (ext_clk),
      .rstn (resetn),
      .rst ());

endmodule