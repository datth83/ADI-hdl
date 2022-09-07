// ***************************************************************************
// ***************************************************************************
// Copyright 2022 (c) Analog Devices, Inc. All rights reserved.
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

module axi_ad7606b_pif #(

  // adc read modes are  1=Simple, 2=status_header() 3=crc_enabled
  parameter ADC_READ_MODE = 1,
  parameter NEG_EDGE = 1
) (

  // physical interface

  output                  cs_n,
  output      [15:0]      db_o,
  input       [15:0]      db_i,
  output                  db_t,
  output                  rd_n,
  output                  wr_n,
  input                   busy,
  input                   first_data,

  // FIFO interface

  output  reg [15:0]      adc_data_0,
  output  reg [15:0]      adc_data_1,
  output  reg [15:0]      adc_data_2,
  output  reg [15:0]      adc_data_3,
  output  reg [15:0]      adc_data_4,
  output  reg [15:0]      adc_data_5,
  output  reg [15:0]      adc_data_6,
  output  reg [15:0]      adc_data_7,
  output  reg             adc_valid,

  // register access

  input                   clk,
  input                   rstn,
  input                   rd_req,
  input                   wr_req,
  input       [15:0]      wr_data,
  output  reg [15:0]      rd_data ='hf,
  output  reg             rd_valid
);

  // state registers

  localparam  [ 2:0]  IDLE = 3'h0;
  localparam  [ 2:0]  CS_LOW = 3'h1;
  localparam  [ 2:0]  CNTRL_LOW = 3'h2;
  localparam  [ 2:0]  CNTRL_HIGH = 3'h3;
  localparam  [ 2:0]  CS_HIGH = 3'h4;
  localparam          SIMPLE = 1;
  localparam          STATUS_HEADER = 2;
  localparam          CRC_ENABLED = 3;

  // internal registers

  reg         [15:0]  crc_data = 16'b0;

  reg         [ 2:0]  transfer_state = 3'h0;
  reg         [ 2:0]  transfer_state_next = 3'h0;
  reg         [ 3:0]  width_counter = 4'h0;
  reg         [ 3:0]  channel_counter = 4'h0;
  reg         [ 3:0]  nr_rd_burst = 4'h0;

  reg                 wr_req_d = 1'h0;
  reg                 rd_req_d = 1'h0;
  reg                 rd_conv_d = 1'h0;

  reg                 rd_valid_d = 1'h0;
  reg                 first_data_d = 1'd0;
  reg                 cs_high_d = 1'd0;
  reg                 read_ch_data = 1'd0;

  // internal wires

  wire                end_of_conv;
  wire                start_transfer_s;
  wire                rd_valid_s;
  wire                rd_new_data_s;

  wire                cs_high_s;
  wire                cs_high_edge_s;

  // instantiations

  ad_edge_detect #(
    .EDGE(NEG_EDGE)
  ) i_ad_edge_detect (
    .clk (clk),
    .rst (~rstn),
    .signal_in (busy),
    .signal_out (end_of_conv));

  // counters to control the RD_N and WR_N lines

  assign start_transfer_s = end_of_conv | rd_req | wr_req;

  always @(negedge clk) begin
    if (transfer_state == IDLE) begin
      wr_req_d <= wr_req;
      rd_req_d <= rd_req;
      rd_conv_d <= end_of_conv;
    end
  end

  always @(posedge clk) begin
    if (rstn == 1'b0) begin
      width_counter <= 4'h0;
    end else begin
      if((transfer_state == CNTRL_LOW) || (transfer_state == CNTRL_HIGH)) begin
        width_counter <= width_counter + 1;
      end else begin
        width_counter <= 4'h0;
      end
    end
  end

  always @(posedge clk) begin
    if (rstn == 1'b0) begin
      channel_counter <= 2'h0;
    end else begin
      if (rd_new_data_s == 1'b1 && read_ch_data == 1'b1) begin
        channel_counter <= channel_counter + 1;
      end else if (transfer_state == IDLE) begin
        channel_counter <= 5'h0;
      end
    end
    cs_high_d <= cs_high_s;
  end

  assign cs_high_edge_s = (!cs_high_d & cs_high_s) ? 1 : 0;
  assign cs_high_s = (transfer_state_next == CS_HIGH) ? 1 : 0;

  // first data changes on it's on or it changes when rd_n is deaserted
  always @(posedge clk) begin
    if (rstn == 1'b0) begin
      first_data_d <=  1'b0;
    end else begin
      if (ADC_READ_MODE == SIMPLE) begin
        first_data_d <= first_data;
        nr_rd_burst = 4'd8;
        if (first_data & ~cs_n) begin
          read_ch_data <= 1'b1;
        end else if (channel_counter == 4'd8 && transfer_state == IDLE) begin
          read_ch_data <= 1'b0;
        end
      end else if (ADC_READ_MODE == CRC_ENABLED) begin
        nr_rd_burst = 4'd9;
        if ((transfer_state == CNTRL_LOW) && ~(wr_req_d | rd_req_d)) begin
          read_ch_data <= 1'b1;
        end else if (channel_counter == 4'd9) begin
          read_ch_data <= 1'b0;
        end
      end else begin
        read_ch_data <= 1'b1;
      end

      if (read_ch_data == 1'b1 && rd_new_data_s == 1'b1) begin
        case (channel_counter)
          4'd0 : begin
            adc_data_0 <= rd_data;
          end
          4'd1 : begin
            adc_data_1 <= rd_data;
          end
          4'd2 : begin
            adc_data_2 <= rd_data;
          end
          4'd3 : begin
            adc_data_3 <= rd_data;
          end
          4'd4 : begin
            adc_data_4 <= rd_data;
          end
          4'd5 : begin
            adc_data_5 <= rd_data;
          end
          4'd6 : begin
            adc_data_6 <= rd_data;
          end
          4'd7 : begin
            adc_data_7 <= rd_data;
          end
          4'd8 : begin
            crc_data <= rd_data;
          end
        endcase
      end
      adc_valid <= (channel_counter == 4'd8) || (wr_req_d | rd_req_d) ? rd_valid_d : 1'b0 ;
    end
  end

  // FSM state register

  always @(posedge clk) begin
    if (rstn == 1'b0) begin
      transfer_state <= 3'h0;
    end else begin
      transfer_state <= transfer_state_next;
    end
  end

  // FSM next state logic

  always @(*) begin
    case (transfer_state)
      IDLE : begin
        transfer_state_next <= (start_transfer_s == 1'b1) ? CS_LOW : IDLE;
      end
      CS_LOW : begin
        transfer_state_next <= CNTRL_LOW;
      end
      CNTRL_LOW : begin
        transfer_state_next <= (width_counter == 4'd8) ? CNTRL_HIGH : CNTRL_LOW;
      end
      CNTRL_HIGH : begin
        transfer_state_next <= (width_counter == 4'd8) &&
          (wr_req_d | rd_req_d  | rd_conv_d) ? CS_HIGH : CNTRL_HIGH;
      end
      CS_HIGH : begin
        transfer_state_next <= (channel_counter == nr_rd_burst) || (wr_req_d | rd_req_d) ? IDLE : CNTRL_LOW;
      end
      default : begin
        transfer_state_next <= IDLE;
      end
    endcase
  end

  // data valid for the register access

  assign rd_valid_s = ((transfer_state == CNTRL_HIGH) &&
                       ((rd_req_d == 1'b1) || (rd_conv_d == 1'b1))) ? 1'b1 : 1'b0;

  // FSM output logic

  assign db_o = wr_data;

  assign rd_new_data_s = rd_valid_s & ~rd_valid_d;

  always @(posedge clk) begin
    rd_data <= ~rd_n ? db_i : rd_data;
    rd_valid <= rd_new_data_s;
    rd_valid_d <= rd_valid_s;
  end

  assign cs_n = (transfer_state == IDLE) ? 1'b1 : 1'b0;
  assign db_t = ~wr_req_d;
  assign rd_n = ((transfer_state == CNTRL_LOW) && ((rd_conv_d == 1'b1) || rd_req_d == 1'b1)) ? 1'b0 : 1'b1;
  assign wr_n = ((transfer_state == CNTRL_LOW) && (wr_req_d == 1'b1)) ? 1'b0 : 1'b1;

endmodule
