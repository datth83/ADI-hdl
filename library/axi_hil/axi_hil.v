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
`timescale 1ns / 1ps

module axi_hil #(
  parameter     ID = 0
) (  
  output      [31:0]                  dac_1_0_data,
  output      [31:0]                  dac_3_2_data,
  input                               sampling_clk,
  input       [15:0]                  adc_0_data,
  input                               adc_0_valid,
  input       [15:0]                  adc_1_data,
  input                               adc_1_valid,
  input       [15:0]                  adc_2_data,
  input                               adc_2_valid,
  input       [15:0]                  adc_3_data,
  input                               adc_3_valid,

  //axi interface
  input                               s_axi_aclk,
  input                               s_axi_aresetn,
  input                               s_axi_awvalid,
  input       [ 9:0]                  s_axi_awaddr,
  input       [ 2:0]                  s_axi_awprot,
  output                              s_axi_awready,
  input                               s_axi_wvalid,
  input       [31:0]                  s_axi_wdata,
  input       [ 3:0]                  s_axi_wstrb,
  output                              s_axi_wready,
  output                              s_axi_bvalid,
  output      [ 1:0]                  s_axi_bresp,
  input                               s_axi_bready,
  input                               s_axi_arvalid,
  input       [ 9:0]                  s_axi_araddr,
  input       [ 2:0]                  s_axi_arprot,
  output                              s_axi_arready,
  output                              s_axi_rvalid,
  output      [ 1:0]                  s_axi_rresp,
  output      [31:0]                  s_axi_rdata,
  input                               s_axi_rready
);

  //local parameters
  localparam [31:0] CORE_VERSION            = {16'h0001,     /* MAJOR */
                                                8'h00,       /* MINOR */
                                                8'h00};      /* PATCH */ // 0.0.0
  localparam [31:0] CORE_MAGIC              = 32'h48494C43;    // HILC

  wire up_clk;
  wire up_rstn;

  assign up_clk = s_axi_aclk;
  assign up_rstn = s_axi_aresetn;

  reg           up_wack = 'd0;
  reg   [31:0]  up_rdata = 'd0;
  reg           up_rack = 'd0;
  reg           up_resetn = 1'b0;
  reg   [31:0]  up_scratch = 'd0;

  wire          up_rreq_s;
  wire  [7:0]   up_raddr_s;
  wire          up_wreq_s;
  wire  [7:0]   up_waddr_s;
  wire  [31:0]  up_wdata_s;

  reg   [15:0]  dac_0_data;
  reg   [15:0]  dac_1_data;
  reg   [15:0]  dac_2_data;
  reg   [15:0]  dac_3_data;

  // reg   [15:0]  axi_adc_0_threshold;
  // reg   [31:0]  axi_adc_0_delay_prescaler;
  // reg   [31:0]  axi_adc_0_delay_cnt;
  // reg           axi_adc_0_delay_cnt_en;
  // reg   [15:0]  axi_dac_0_min_value;
  // reg   [15:0]  axi_dac_0_max_value;

  // reg   [15:0]  axi_adc_1_threshold;
  // reg   [31:0]  axi_adc_1_delay_prescaler;
  // reg   [31:0]  axi_adc_1_delay_cnt;
  // reg           axi_adc_1_delay_cnt_en;
  // reg   [15:0]  axi_dac_1_min_value;
  // reg   [15:0]  axi_dac_1_max_value;

  // reg   [15:0]  axi_adc_2_threshold;
  // reg   [31:0]  axi_adc_2_delay_prescaler;
  // reg   [31:0]  axi_adc_2_delay_cnt;
  // reg           axi_adc_2_delay_cnt_en;
  // reg   [15:0]  axi_dac_2_min_value; 
  // reg   [15:0]  axi_dac_2_max_value;

  // reg   [15:0]  axi_adc_3_threshold;
  // reg   [31:0]  axi_adc_3_delay_prescaler;
  // reg   [31:0]  axi_adc_3_delay_cnt;
  // reg           axi_adc_3_delay_cnt_en;
  // reg   [15:0]  axi_dac_3_min_value;
  // reg   [15:0]  axi_dac_3_max_value;

  wire           resetn;

  wire   [15:0]  adc_0_threshold;
  wire   [31:0]  adc_0_delay_prescaler;
  reg    [31:0]  adc_0_delay_cnt;
  reg            adc_0_delay_cnt_en;
  wire   [15:0]  dac_0_min_value;
  wire   [15:0]  dac_0_max_value;

  wire   [15:0]  adc_1_threshold;
  wire   [31:0]  adc_1_delay_prescaler;
  reg    [31:0]  adc_1_delay_cnt;
  reg            adc_1_delay_cnt_en;
  wire   [15:0]  dac_1_min_value;
  wire   [15:0]  dac_1_max_value;

  wire   [15:0]  adc_2_threshold;
  wire   [31:0]  adc_2_delay_prescaler;
  reg    [31:0]  adc_2_delay_cnt;
  reg            adc_2_delay_cnt_en;
  wire   [15:0]  dac_2_min_value; 
  wire   [15:0]  dac_2_max_value;

  wire   [15:0]  adc_3_threshold;
  wire   [31:0]  adc_3_delay_prescaler;
  reg    [31:0]  adc_3_delay_cnt;
  reg            adc_3_delay_cnt_en;
  wire   [15:0]  dac_3_min_value;
  wire   [15:0]  dac_3_max_value;

  reg   [15:0]  delay_dac_0_data;
  reg   [15:0]  delay_dac_1_data;
  reg   [15:0]  delay_dac_2_data;
  reg   [15:0]  delay_dac_3_data;

  reg           adc_0_input_change;
  reg           prev_adc_0_input_change;

  reg           adc_1_input_change;
  reg           prev_adc_1_input_change;

  reg           adc_2_input_change;
  reg           prev_adc_2_input_change;

  reg           adc_3_input_change;
  reg           prev_adc_3_input_change;
  
  wire          adc_0_threshold_passed;
  wire          adc_1_threshold_passed;
  wire          adc_2_threshold_passed;
  wire          adc_3_threshold_passed;

  up_axi #(
    .AXI_ADDRESS_WIDTH (10)
  ) i_up_axi (
    .up_rstn (up_resetn),
    .up_clk (up_clk),
    .up_axi_awvalid (s_axi_awvalid),
    .up_axi_awaddr (s_axi_awaddr),
    .up_axi_awready (s_axi_awready),
    .up_axi_wvalid (s_axi_wvalid),
    .up_axi_wdata (s_axi_wdata),
    .up_axi_wstrb (s_axi_wstrb),
    .up_axi_wready (s_axi_wready),
    .up_axi_bvalid (s_axi_bvalid),
    .up_axi_bresp (s_axi_bresp),
    .up_axi_bready (s_axi_bready),
    .up_axi_arvalid (s_axi_arvalid),
    .up_axi_araddr (s_axi_araddr),
    .up_axi_arready (s_axi_arready),
    .up_axi_rvalid (s_axi_rvalid),
    .up_axi_rresp (s_axi_rresp),
    .up_axi_rdata (s_axi_rdata),
    .up_axi_rready (s_axi_rready),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata),
    .up_rack (up_rack));

  axi_hil_regmap #(
    .ID (ID),
    .CORE_MAGIC (CORE_MAGIC),
    .CORE_VERSION (CORE_VERSION),
    .ADC_0_THRESHOLD (0),
    .ADC_1_THRESHOLD (0),
    .ADC_2_THRESHOLD (0),
    .ADC_3_THRESHOLD (0),
    .ADC_0_DELAY_PRESCALER (0),
    .ADC_1_DELAY_PRESCALER (0),
    .ADC_2_DELAY_PRESCALER (0),
    .ADC_3_DELAY_PRESCALER (0),
    .DAC_0_MIN_VALUE (0),
    .DAC_1_MIN_VALUE (0),
    .DAC_2_MIN_VALUE (0),
    .DAC_3_MIN_VALUE (0),
    .DAC_0_MAX_VALUE (0),
    .DAC_1_MAX_VALUE (0),
    .DAC_2_MAX_VALUE (0),
    .DAC_3_MAX_VALUE (0)
  ) i_regmap (
    .ext_clk (sampling_clk),
    .resetn (resetn),
    .adc_0_threshold (adc_0_threshold),
    .adc_1_threshold (adc_1_threshold),
    .adc_2_threshold (adc_2_threshold),
    .adc_3_threshold (adc_3_threshold),
    .adc_0_delay_prescaler (adc_0_delay_prescaler),
    .adc_1_delay_prescaler (adc_1_delay_prescaler),
    .adc_2_delay_prescaler (adc_2_delay_prescaler),
    .adc_3_delay_prescaler (adc_3_delay_prescaler),
    .dac_0_min_value (dac_0_min_value),
    .dac_1_min_value (dac_1_min_value),
    .dac_2_min_value (dac_2_min_value),
    .dac_3_min_value (dac_3_min_value),
    .dac_0_max_value (dac_0_max_value),
    .dac_1_max_value (dac_1_max_value),
    .dac_2_max_value (dac_2_max_value),
    .dac_3_max_value (dac_3_max_value),
    .up_rstn (up_resetn),
    .up_clk (up_clk),
    .up_wreq (up_wreq_s),
    .up_waddr (up_waddr_s),
    .up_wdata (up_wdata_s),
    .up_wack (up_wack_s),
    .up_rreq (up_rreq_s),
    .up_raddr (up_raddr_s),
    .up_rdata (up_rdata),
    .up_rack (up_rack));

  // //axi registers write
  // always @(posedge s_axi_aclk) begin
  //   if (up_resetn == 1'b0) begin
  //       up_scratch <= 'd0;
  //   end else begin
  //     if (up_wreq_s == 1'b1) begin
  //       case (up_waddr_s)
  //         8'h02: up_scratch <= up_wdata_s;
          
  //         8'h30: axi_adc_0_threshold <= up_wdata_s[15:0];
  //         8'h31: axi_adc_1_threshold <= up_wdata_s[15:0];
  //         8'h32: axi_adc_2_threshold <= up_wdata_s[15:0];
  //         8'h33: axi_adc_3_threshold <= up_wdata_s[15:0];
          
  //         8'h40: axi_dac_0_min_value <= up_wdata_s[15:0];
  //         8'h41: axi_dac_1_min_value <= up_wdata_s[15:0];
  //         8'h42: axi_dac_2_min_value <= up_wdata_s[15:0];
  //         8'h43: axi_dac_3_min_value <= up_wdata_s[15:0];

  //         8'h50: axi_dac_0_max_value <= up_wdata_s[15:0];
  //         8'h51: axi_dac_1_max_value <= up_wdata_s[15:0];
  //         8'h52: axi_dac_2_max_value <= up_wdata_s[15:0];
  //         8'h53: axi_dac_3_max_value <= up_wdata_s[15:0];

  //         8'h60: axi_adc_0_delay_prescaler <= up_wdata_s;
  //         8'h61: axi_adc_1_delay_prescaler <= up_wdata_s;
  //         8'h62: axi_adc_2_delay_prescaler <= up_wdata_s;
  //         8'h63: axi_adc_3_delay_prescaler <= up_wdata_s;

  //         default:; // nothing
  //       endcase
  //     end
  //   end
  // end

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_adc_0_threshold (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_adc_0_threshold),
  //   .out_clk(sampling_clk),
  //   .out_data(adc_0_threshold)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_adc_1_threshold (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_adc_1_threshold),
  //   .out_clk(sampling_clk),
  //   .out_data(adc_1_threshold)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_adc_2_threshold (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_adc_2_threshold),
  //   .out_clk(sampling_clk),
  //   .out_data(adc_2_threshold)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_adc_3_threshold (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_adc_3_threshold),
  //   .out_clk(sampling_clk),
  //   .out_data(adc_3_threshold)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_dac_0_min_value (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_dac_0_min_value),
  //   .out_clk(sampling_clk),
  //   .out_data(dac_0_min_value)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_dac_1_min_value (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_dac_1_min_value),
  //   .out_clk(sampling_clk),
  //   .out_data(dac_1_min_value)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_dac_2_min_value (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_dac_2_min_value),
  //   .out_clk(sampling_clk),
  //   .out_data(dac_2_min_value)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_dac_3_min_value (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_dac_3_min_value),
  //   .out_clk(sampling_clk),
  //   .out_data(dac_3_min_value)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_dac_0_max_value (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_dac_0_max_value),
  //   .out_clk(sampling_clk),
  //   .out_data(dac_0_max_value)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_dac_1_max_value (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_dac_1_max_value),
  //   .out_clk(sampling_clk),
  //   .out_data(dac_1_max_value)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_dac_2_max_value (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_dac_2_max_value),
  //   .out_clk(sampling_clk),
  //   .out_data(dac_2_max_value)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (16)
  // ) sync_dac_3_max_value (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_dac_3_max_value),
  //   .out_clk(sampling_clk),
  //   .out_data(dac_3_max_value)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (32)
  // ) sync_adc_0_delay_prescaler (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_adc_0_delay_prescaler),
  //   .out_clk(sampling_clk),
  //   .out_data(adc_0_delay_prescaler)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (32)
  // ) sync_adc_1_delay_prescaler (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_adc_1_delay_prescaler),
  //   .out_clk(sampling_clk),
  //   .out_data(adc_1_delay_prescaler)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (32)
  // ) sync_adc_2_delay_prescaler (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_adc_2_delay_prescaler),
  //   .out_clk(sampling_clk),
  //   .out_data(adc_2_delay_prescaler)
  // );

  // sync_data #(
  //   .NUM_OF_BITS (32)
  // ) sync_adc_3_delay_prescaler (
  //   .in_clk(s_axi_aclk),
  //   .in_data(axi_adc_3_delay_prescaler),
  //   .out_clk(sampling_clk),
  //   .out_data(adc_3_delay_prescaler)
  // );

  // ad_rst i_d_rst_reg (
  //     .rst_async (up_resetn),
  //     .clk (sampling_clk),
  //     .rstn (rstn),
  //     .rst ());

  // //writing reset
  // always @(posedge s_axi_aclk) begin
  //   if (s_axi_aresetn == 1'b0) begin
  //     up_wack <= 'd0;
  //     up_resetn <= 1'd0;
  //   end else begin
  //     up_wack <= up_wreq_s;
  //     if ((up_wreq_s == 1'b1) && (up_waddr_s == 8'h20)) begin
  //       up_resetn <= up_wdata_s[0];
  //     end else begin
  //       up_resetn <= 1'd1;
  //     end
  //   end
  // end

  // //axi registers read
  // always @(posedge s_axi_aclk) begin
  //   if (s_axi_aresetn == 1'b0) begin
  //     up_rack <= 'd0;
  //     up_rdata <= 'd0;
  //   end else begin
  //     up_rack <= up_rreq_s;
  //     if (up_rreq_s == 1'b1) begin
  //       case (up_raddr_s)
  //         8'h00: up_rdata <= CORE_VERSION;
  //         8'h01: up_rdata <= ID;
  //         8'h02: up_rdata <= up_scratch;
  //         8'h03: up_rdata <= CORE_MAGIC;
  //         8'h20: up_rdata <= up_resetn;

  //         8'h30: up_rdata <= axi_adc_0_threshold;
  //         8'h31: up_rdata <= axi_adc_1_threshold;
  //         8'h32: up_rdata <= axi_adc_2_threshold;
  //         8'h33: up_rdata <= axi_adc_3_threshold; 

  //         8'h40: up_rdata <= axi_dac_0_min_value;
  //         8'h41: up_rdata <= axi_dac_1_min_value;
  //         8'h42: up_rdata <= axi_dac_2_min_value;
  //         8'h43: up_rdata <= axi_dac_3_min_value;

  //         8'h50: up_rdata <= axi_dac_0_max_value;
  //         8'h51: up_rdata <= axi_dac_1_max_value;
  //         8'h52: up_rdata <= axi_dac_2_max_value;
  //         8'h53: up_rdata <= axi_dac_3_max_value;

  //         8'h60: up_rdata <= axi_adc_0_delay_prescaler;
  //         8'h61: up_rdata <= axi_adc_1_delay_prescaler;
  //         8'h62: up_rdata <= axi_adc_2_delay_prescaler;
  //         8'h63: up_rdata <= axi_adc_3_delay_prescaler;

  //         default: up_rdata <= 0;
  //       endcase
  //     end else begin
  //       up_rdata <= 32'd0;
  //     end
  //   end
  // end

  assign adc_0_threshold_passed = !prev_adc_0_input_change && adc_0_input_change;
  assign adc_1_threshold_passed = !prev_adc_1_input_change && adc_1_input_change;
  assign adc_2_threshold_passed = !prev_adc_2_input_change && adc_2_input_change;
  assign adc_3_threshold_passed = !prev_adc_3_input_change && adc_3_input_change;

  // starts/stops the delay prescaler
  always @(posedge sampling_clk) begin
    if (resetn == 1'b0) begin
      adc_0_delay_cnt_en <= 1'b0;
      adc_1_delay_cnt_en <= 1'b0;
      adc_2_delay_cnt_en <= 1'b0;
      adc_3_delay_cnt_en <= 1'b0;
    end else begin
      if (!adc_0_delay_cnt_en && adc_0_threshold_passed) begin
        adc_0_delay_cnt_en <= 1'b1;
      end
      if (!adc_1_delay_cnt_en && adc_1_threshold_passed) begin
        adc_1_delay_cnt_en <= 1'b1;
      end
      if (!adc_2_delay_cnt_en && adc_2_threshold_passed) begin
        adc_2_delay_cnt_en <= 1'b1;
      end
      if (!adc_3_delay_cnt_en && adc_3_threshold_passed) begin
        adc_3_delay_cnt_en <= 1'b1;
      end

      if (adc_0_delay_cnt == adc_0_delay_prescaler) begin
        adc_0_delay_cnt_en <= 1'b0;
      end
      if (adc_1_delay_cnt == adc_1_delay_prescaler) begin
        adc_1_delay_cnt_en <= 1'b0;
      end
      if (adc_2_delay_cnt == adc_2_delay_prescaler) begin
        adc_2_delay_cnt_en <= 1'b0;
      end
      if (adc_3_delay_cnt == adc_3_delay_prescaler) begin
        adc_3_delay_cnt_en <= 1'b0;
      end
    end
  end

  //sets the delay before generating the result on the DAC
  always @(posedge sampling_clk) begin
    if (resetn == 1'b0) begin
        adc_0_delay_cnt <= 32'h0;
        adc_1_delay_cnt <= 32'h0;
        adc_2_delay_cnt <= 32'h0;
        adc_3_delay_cnt <= 32'h0;
    end else begin
      if (adc_0_delay_cnt_en) begin
        if (adc_0_delay_cnt == adc_0_delay_prescaler) begin
          adc_0_delay_cnt <= 32'h0;
        end else begin
          adc_0_delay_cnt <= adc_0_delay_cnt + 1'b1;
        end
      end
      if (adc_1_delay_cnt_en) begin
        if (adc_1_delay_cnt == adc_1_delay_prescaler) begin
          adc_1_delay_cnt <= 32'h0;
        end else begin
          adc_1_delay_cnt <= adc_1_delay_cnt + 1'b1;
        end
      end
      if (adc_2_delay_cnt_en) begin
        if (adc_2_delay_cnt == adc_2_delay_prescaler) begin
          adc_2_delay_cnt <= 32'h0;
        end else begin
          adc_2_delay_cnt <= adc_2_delay_cnt + 1'b1;
        end
      end
      if (adc_3_delay_cnt_en) begin
        if (adc_3_delay_cnt == adc_3_delay_prescaler) begin
          adc_3_delay_cnt <= 32'h0;
        end else begin
          adc_3_delay_cnt <= adc_3_delay_cnt + 1'b1;
        end
      end
    end
  end

  //comparator logic
  always @(posedge sampling_clk) begin
    if (resetn == 1'b0) begin
      adc_0_input_change <= 1'b0;
      adc_1_input_change <= 1'b0;
      adc_2_input_change <= 1'b0;
      adc_3_input_change <= 1'b0;
      prev_adc_0_input_change <= 1'b0;
      prev_adc_1_input_change <= 1'b0;
      prev_adc_2_input_change <= 1'b0;
      prev_adc_3_input_change <= 1'b0;
    end else begin
      if (adc_0_valid) begin
        if (adc_0_data < adc_0_threshold) begin
          adc_0_input_change <= 1'b0;
          delay_dac_0_data <= dac_0_min_value;
        end else begin
          adc_0_input_change <= 1'b1;
          delay_dac_0_data <= dac_0_max_value;
        end
      end
      if (adc_1_valid) begin
        if (adc_1_data < adc_0_threshold) begin
          adc_1_input_change <= 1'b0;
          delay_dac_1_data <= dac_1_min_value;
        end else begin
          adc_1_input_change <= 1'b1;
          delay_dac_1_data <= dac_1_max_value;
        end
      end
      if (adc_2_valid) begin
        if (adc_2_data < adc_2_threshold) begin
          adc_2_input_change <= 1'b0;
          delay_dac_2_data <= dac_2_min_value;
        end else begin
          adc_2_input_change <= 1'b1;
          delay_dac_2_data <= dac_2_max_value;
        end
      end
      if (adc_3_valid) begin
        if (adc_3_data < adc_3_threshold) begin
          adc_3_input_change <= 1'b0;
          delay_dac_3_data <= dac_3_min_value;
        end else begin
          adc_3_input_change <= 1'b1;
          delay_dac_3_data <= dac_3_max_value;
        end
      end
    end
  end

  wire change_dac_0_data;
  wire change_dac_1_data;
  wire change_dac_2_data;
  wire change_dac_3_data;

  assign change_dac_0_data = (adc_0_delay_cnt == adc_0_delay_prescaler);
  assign change_dac_1_data = (adc_1_delay_cnt == adc_1_delay_prescaler);
  assign change_dac_2_data = (adc_2_delay_cnt == adc_2_delay_prescaler);
  assign change_dac_3_data = (adc_3_delay_cnt == adc_3_delay_prescaler);

  //assign outputs to DAC after the delay has passed
  always @(posedge sampling_clk) begin
    if (resetn == 1'b0) begin
      dac_0_data <= 'h0;
      dac_1_data <= 'h0;
      dac_2_data <= 'h0;
      dac_3_data <= 'h0;
    end else begin
      if (change_dac_0_data) begin
        dac_0_data <= {~delay_dac_0_data[15], delay_dac_0_data[14:0]};
      end
      if (change_dac_1_data) begin
        dac_1_data <= {~delay_dac_1_data[15], delay_dac_1_data[14:0]};
      end
      if (change_dac_2_data) begin
        dac_2_data <= {~delay_dac_2_data[15], delay_dac_2_data[14:0]};
      end
      if (change_dac_3_data) begin
        dac_3_data <= {~delay_dac_3_data[15], delay_dac_3_data[14:0]};
      end
    end
  end

  assign dac_1_0_data = {dac_1_data, dac_0_data};
  assign dac_3_2_data = {dac_3_data, dac_2_data};

endmodule
