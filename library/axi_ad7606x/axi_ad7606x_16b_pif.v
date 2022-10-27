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

module axi_ad7606x_16b_pif #(

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
  output  reg [ 7:0]      adc_status_0 = 'h0,
  output  reg [15:0]      adc_data_1,
  output  reg [ 7:0]      adc_status_1 = 'h0,
  output  reg [15:0]      adc_data_2,
  output  reg [ 7:0]      adc_status_2 = 'h0,
  output  reg [15:0]      adc_data_3,
  output  reg [ 7:0]      adc_status_3 = 'h0,
  output  reg [15:0]      adc_data_4,
  output  reg [ 7:0]      adc_status_4 = 'h0,
  output  reg [15:0]      adc_data_5,
  output  reg [ 7:0]      adc_status_5 = 'h0,
  output  reg [15:0]      adc_data_6,
  output  reg [ 7:0]      adc_status_6 = 'h0,
  output  reg [15:0]      adc_data_7,
  output  reg [ 7:0]      adc_status_7 = 'h0,
  output                  adc_status,
  output  reg [15:0]      adc_crc = 'h0,
  output  reg [15:0]      adc_crc_res = 'h0,
  output                  adc_crc_err,
  output  reg             adc_valid,

  // register access

  input                   clk,
  input                   rstn,
  input                   rd_req,
  input                   wr_req,
  input       [15:0]      wr_data,
  output  reg [15:0]      rd_data = 'hf,
  output  reg             rd_valid
);

  // state registers

  localparam  [ 2:0]  IDLE = 3'h0;
  localparam  [ 2:0]  CS_LOW = 3'h1;
  localparam  [ 2:0]  CNTRL_LOW = 3'h2;
  localparam  [ 2:0]  CNTRL_HIGH = 3'h3;
  localparam  [ 2:0]  CS_HIGH = 3'h4;
  localparam  [ 1:0]  SIMPLE = 0;
  localparam  [ 1:0]  STATUS_HEADER = 1;
  localparam  [ 1:0]  CRC_ENABLED = 2;

  // internal registers

  reg         [ 2:0]  transfer_state = 3'h0;
  reg         [ 2:0]  transfer_state_next = 3'h0;
  reg         [ 3:0]  width_counter = 4'h0;
  reg         [ 4:0]  channel_counter = 5'h0;
  reg         [ 4:0]  nr_rd_burst = 5'h0;

  reg                 wr_req_d = 1'h0;
  reg                 rd_req_d = 1'h0;
  reg                 rd_conv_d = 1'h0;

  reg                 rd_valid_d = 1'h0;
  reg                 first_data_d = 1'h0;
  reg                 cs_high_d = 1'h0;
  reg                 read_ch_data = 1'd0;

  reg         [ 7:0]  adc_status_er_ch_id = 8'h0;

  // internal wires

  wire                end_of_conv;
  wire                start_transfer_s;
  wire                rd_valid_s;
  wire                rd_new_data_s;

  wire                cs_high_s;
  wire                cs_high_edge_s;

  wire        [ 4:0]  adc_status_er_5b;
  wire                adc_status_er;

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
      channel_counter <= 5'h0;
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
        nr_rd_burst = 5'd8;
        if (first_data & ~cs_n) begin
          read_ch_data <= 1'b1;
        end else if (channel_counter == 5'd8 && transfer_state == IDLE) begin
          read_ch_data <= 1'b0;
        end
      end else if (ADC_READ_MODE == CRC_ENABLED) begin
        nr_rd_burst = 5'd9;
        if ((transfer_state == CNTRL_LOW) && ~(wr_req_d | rd_req_d)) begin
          read_ch_data <= 1'b1;
        end else if (channel_counter == 5'd9) begin
          read_ch_data <= 1'b0;
        end
      end else if (ADC_READ_MODE == STATUS_HEADER) begin
        nr_rd_burst <= 5'd16;
        if ((transfer_state == CNTRL_LOW) && ~(wr_req_d | rd_req_d)) begin
          read_ch_data <= 1'b1;
        end else if (channel_counter == 5'd16) begin
          read_ch_data <= 1'b0;
        end
      end else begin
        read_ch_data <= 1'b1;
      end
      if ((ADC_READ_MODE == SIMPLE) || (ADC_READ_MODE == CRC_ENABLED)) begin
        if (read_ch_data == 1'b1 && rd_new_data_s == 1'b1) begin
          case (channel_counter)
            5'd0 : begin
              adc_data_0 <= rd_data;
            end
            5'd1 : begin
              adc_data_1 <= rd_data;
            end
            5'd2 : begin
              adc_data_2 <= rd_data;
            end
            5'd3 : begin
              adc_data_3 <= rd_data;
            end
            5'd4 : begin
              adc_data_4 <= rd_data;
            end
            5'd5 : begin
              adc_data_5 <= rd_data;
            end
            5'd6 : begin
              adc_data_6 <= rd_data;
            end
            5'd7 : begin
              adc_data_7 <= rd_data;
            end
            5'd8 : begin
              adc_crc <= rd_data;
              adc_crc_res <= crc_128({adc_data_0,adc_data_1,adc_data_2,adc_data_3,adc_data_4,adc_data_5,adc_data_6,adc_data_7});
            end
          endcase
        end
        case (ADC_READ_MODE)
          SIMPLE: begin
            adc_valid <= (channel_counter == 5'd8) || (wr_req_d | rd_req_d) ? rd_valid_d : 1'b0;
          end
          CRC_ENABLED: begin
            adc_valid <= (channel_counter == 5'd9) || (wr_req_d | rd_req_d) ? rd_valid_d : 1'b0;
          end
        endcase
      end else if (ADC_READ_MODE == STATUS_HEADER) begin
        if (read_ch_data == 1'b1 && rd_new_data_s == 1'b1) begin
          case (channel_counter)
            5'd0: begin
              adc_data_0 <= rd_data;
            end
            5'd1: begin
              adc_status_0 <= rd_data[15:8];
            end
            5'd2: begin
              adc_data_1 <= rd_data;
            end
            5'd3: begin
              adc_status_1 <= rd_data[15:8];
            end
            5'd4: begin
              adc_data_2 <= rd_data;
            end
            5'd5: begin
              adc_status_2 <= rd_data[15:8];
            end
            5'd6: begin
              adc_data_3 <= rd_data;
            end
            5'd7: begin
              adc_status_3 <= rd_data[15:8];
            end
            5'd8: begin
              adc_data_4 <= rd_data;
            end
            5'd9: begin
              adc_status_4 <= rd_data[15:8];
            end
            5'd10: begin
              adc_data_5 <= rd_data;
            end
            5'd11: begin
              adc_status_5 <= rd_data[15:8];
            end
            5'd12: begin
              adc_data_6 <= rd_data;
            end
            5'd13: begin
              adc_status_6 <= rd_data[15:8];
            end
            5'd14: begin
              adc_data_7 <= rd_data;
            end
            5'd15: begin
              adc_status_7 <= rd_data[15:8];
            end
          endcase
        end
        adc_valid <= (channel_counter == 5'd16) || (wr_req_d | rd_req_d) ? rd_valid_d : 1'b0;
      end
    end
  end

  function [15:0] crc_128;
    input [127:0] d;
    begin
      crc_128[0] = d[0] ^ d[2] ^ d[3] ^ d[6] ^ d[7] ^ d[8] ^ d[9] ^ d[10] ^ d[13] ^ d[18] ^ d[19] ^ d[23] ^ d[24] ^ d[25] ^ d[26] ^ d[28] ^ d[29] ^ d[32] ^ d[35] ^ d[36] ^ d[38] ^ d[42] ^ d[46] ^ d[51] ^ d[52] ^ d[54] ^ d[55] ^ d[56] ^ d[60] ^ d[61] ^ d[62] ^ d[64] ^ d[69] ^ d[70] ^ d[75] ^ d[77] ^ d[78] ^ d[82] ^ d[83] ^ d[84] ^ d[86] ^ d[88] ^ d[89] ^ d[90] ^ d[91] ^ d[92] ^ d[95] ^ d[97] ^ d[98] ^ d[99] ^ d[104] ^ d[111] ^ d[112] ^ d[113] ^ d[114] ^ d[119] ^ d[120] ^ d[121] ^ d[123] ^ d[124] ^ d[125];
      crc_128[1] = d[0] ^ d[1] ^ d[2] ^ d[4] ^ d[6] ^ d[11] ^ d[13] ^ d[14] ^ d[18] ^ d[20] ^ d[23] ^ d[27] ^ d[28] ^ d[30] ^ d[32] ^ d[33] ^ d[35] ^ d[37] ^ d[38] ^ d[39] ^ d[42] ^ d[43] ^ d[46] ^ d[47] ^ d[51] ^ d[53] ^ d[54] ^ d[57] ^ d[60] ^ d[63] ^ d[64] ^ d[65] ^ d[69] ^ d[71] ^ d[75] ^ d[76] ^ d[77] ^ d[79] ^ d[82] ^ d[85] ^ d[86] ^ d[87] ^ d[88] ^ d[93] ^ d[95] ^ d[96] ^ d[97] ^ d[100] ^ d[104] ^ d[105] ^ d[111] ^ d[115] ^ d[119] ^ d[122] ^ d[123] ^ d[126];
      crc_128[2] = d[1] ^ d[2] ^ d[3] ^ d[5] ^ d[7] ^ d[12] ^ d[14] ^ d[15] ^ d[19] ^ d[21] ^ d[24] ^ d[28] ^ d[29] ^ d[31] ^ d[33] ^ d[34] ^ d[36] ^ d[38] ^ d[39] ^ d[40] ^ d[43] ^ d[44] ^ d[47] ^ d[48] ^ d[52] ^ d[54] ^ d[55] ^ d[58] ^ d[61] ^ d[64] ^ d[65] ^ d[66] ^ d[70] ^ d[72] ^ d[76] ^ d[77] ^ d[78] ^ d[80] ^ d[83] ^ d[86] ^ d[87] ^ d[88] ^ d[89] ^ d[94] ^ d[96] ^ d[97] ^ d[98] ^ d[101] ^ d[105] ^ d[106] ^ d[112] ^ d[116] ^ d[120] ^ d[123] ^ d[124] ^ d[127];
      crc_128[3] = d[0] ^ d[4] ^ d[7] ^ d[9] ^ d[10] ^ d[15] ^ d[16] ^ d[18] ^ d[19] ^ d[20] ^ d[22] ^ d[23] ^ d[24] ^ d[26] ^ d[28] ^ d[30] ^ d[34] ^ d[36] ^ d[37] ^ d[38] ^ d[39] ^ d[40] ^ d[41] ^ d[42] ^ d[44] ^ d[45] ^ d[46] ^ d[48] ^ d[49] ^ d[51] ^ d[52] ^ d[53] ^ d[54] ^ d[59] ^ d[60] ^ d[61] ^ d[64] ^ d[65] ^ d[66] ^ d[67] ^ d[69] ^ d[70] ^ d[71] ^ d[73] ^ d[75] ^ d[79] ^ d[81] ^ d[82] ^ d[83] ^ d[86] ^ d[87] ^ d[91] ^ d[92] ^ d[102] ^ d[104] ^ d[106] ^ d[107] ^ d[111] ^ d[112] ^ d[114] ^ d[117] ^ d[119] ^ d[120] ^ d[123];
      crc_128[4] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[5] ^ d[6] ^ d[7] ^ d[9] ^ d[11] ^ d[13] ^ d[16] ^ d[17] ^ d[18] ^ d[20] ^ d[21] ^ d[26] ^ d[27] ^ d[28] ^ d[31] ^ d[32] ^ d[36] ^ d[37] ^ d[39] ^ d[40] ^ d[41] ^ d[43] ^ d[45] ^ d[47] ^ d[49] ^ d[50] ^ d[51] ^ d[53] ^ d[56] ^ d[64] ^ d[65] ^ d[66] ^ d[67] ^ d[68] ^ d[69] ^ d[71] ^ d[72] ^ d[74] ^ d[75] ^ d[76] ^ d[77] ^ d[78] ^ d[80] ^ d[86] ^ d[87] ^ d[89] ^ d[90] ^ d[91] ^ d[93] ^ d[95] ^ d[97] ^ d[98] ^ d[99] ^ d[103] ^ d[104] ^ d[105] ^ d[107] ^ d[108] ^ d[111] ^ d[114] ^ d[115] ^ d[118] ^ d[119] ^ d[123] ^ d[125];
      crc_128[5] = d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[6] ^ d[7] ^ d[8] ^ d[10] ^ d[12] ^ d[14] ^ d[17] ^ d[18] ^ d[19] ^ d[21] ^ d[22] ^ d[27] ^ d[28] ^ d[29] ^ d[32] ^ d[33] ^ d[37] ^ d[38] ^ d[40] ^ d[41] ^ d[42] ^ d[44] ^ d[46] ^ d[48] ^ d[50] ^ d[51] ^ d[52] ^ d[54] ^ d[57] ^ d[65] ^ d[66] ^ d[67] ^ d[68] ^ d[69] ^ d[70] ^ d[72] ^ d[73] ^ d[75] ^ d[76] ^ d[77] ^ d[78] ^ d[79] ^ d[81] ^ d[87] ^ d[88] ^ d[90] ^ d[91] ^ d[92] ^ d[94] ^ d[96] ^ d[98] ^ d[99] ^ d[100] ^ d[104] ^ d[105] ^ d[106] ^ d[108] ^ d[109] ^ d[112] ^ d[115] ^ d[116] ^ d[119] ^ d[120] ^ d[124] ^ d[126];
      crc_128[6] = d[0] ^ d[4] ^ d[5] ^ d[6] ^ d[10] ^ d[11] ^ d[15] ^ d[20] ^ d[22] ^ d[24] ^ d[25] ^ d[26] ^ d[30] ^ d[32] ^ d[33] ^ d[34] ^ d[35] ^ d[36] ^ d[39] ^ d[41] ^ d[43] ^ d[45] ^ d[46] ^ d[47] ^ d[49] ^ d[53] ^ d[54] ^ d[56] ^ d[58] ^ d[60] ^ d[61] ^ d[62] ^ d[64] ^ d[66] ^ d[67] ^ d[68] ^ d[71] ^ d[73] ^ d[74] ^ d[75] ^ d[76] ^ d[79] ^ d[80] ^ d[83] ^ d[84] ^ d[86] ^ d[90] ^ d[93] ^ d[98] ^ d[100] ^ d[101] ^ d[104] ^ d[105] ^ d[106] ^ d[107] ^ d[109] ^ d[110] ^ d[111] ^ d[112] ^ d[114] ^ d[116] ^ d[117] ^ d[119] ^ d[123] ^ d[124] ^ d[127];
      crc_128[7] = d[1] ^ d[5] ^ d[6] ^ d[7] ^ d[11] ^ d[12] ^ d[16] ^ d[21] ^ d[23] ^ d[25] ^ d[26] ^ d[27] ^ d[31] ^ d[33] ^ d[34] ^ d[35] ^ d[36] ^ d[37] ^ d[40] ^ d[42] ^ d[44] ^ d[46] ^ d[47] ^ d[48] ^ d[50] ^ d[54] ^ d[55] ^ d[57] ^ d[59] ^ d[61] ^ d[62] ^ d[63] ^ d[65] ^ d[67] ^ d[68] ^ d[69] ^ d[72] ^ d[74] ^ d[75] ^ d[76] ^ d[77] ^ d[80] ^ d[81] ^ d[84] ^ d[85] ^ d[87] ^ d[91] ^ d[94] ^ d[99] ^ d[101] ^ d[102] ^ d[105] ^ d[106] ^ d[107] ^ d[108] ^ d[110] ^ d[111] ^ d[112] ^ d[113] ^ d[115] ^ d[117] ^ d[118] ^ d[120] ^ d[124] ^ d[125];
      crc_128[8] = d[0] ^ d[3] ^ d[9] ^ d[10] ^ d[12] ^ d[17] ^ d[18] ^ d[19] ^ d[22] ^ d[23] ^ d[25] ^ d[27] ^ d[29] ^ d[34] ^ d[37] ^ d[41] ^ d[42] ^ d[43] ^ d[45] ^ d[46] ^ d[47] ^ d[48] ^ d[49] ^ d[52] ^ d[54] ^ d[58] ^ d[61] ^ d[63] ^ d[66] ^ d[68] ^ d[73] ^ d[76] ^ d[81] ^ d[83] ^ d[84] ^ d[85] ^ d[89] ^ d[90] ^ d[91] ^ d[97] ^ d[98] ^ d[99] ^ d[100] ^ d[102] ^ d[103] ^ d[104] ^ d[106] ^ d[107] ^ d[108] ^ d[109] ^ d[116] ^ d[118] ^ d[120] ^ d[123] ^ d[124] ^ d[126];
      crc_128[9] = d[1] ^ d[4] ^ d[10] ^ d[11] ^ d[13] ^ d[18] ^ d[19] ^ d[20] ^ d[23] ^ d[24] ^ d[26] ^ d[28] ^ d[30] ^ d[35] ^ d[38] ^ d[42] ^ d[43] ^ d[44] ^ d[46] ^ d[47] ^ d[48] ^ d[49] ^ d[50] ^ d[53] ^ d[55] ^ d[59] ^ d[62] ^ d[64] ^ d[67] ^ d[69] ^ d[74] ^ d[77] ^ d[82] ^ d[84] ^ d[85] ^ d[86] ^ d[90] ^ d[91] ^ d[92] ^ d[98] ^ d[99] ^ d[100] ^ d[101] ^ d[103] ^ d[104] ^ d[105] ^ d[107] ^ d[108] ^ d[109] ^ d[110] ^ d[117] ^ d[119] ^ d[121] ^ d[124] ^ d[125] ^ d[127];
      crc_128[10] = d[0] ^ d[3] ^ d[5] ^ d[6] ^ d[7] ^ d[8] ^ d[9] ^ d[10] ^ d[11] ^ d[12] ^ d[13] ^ d[14] ^ d[18] ^ d[20] ^ d[21] ^ d[23] ^ d[26] ^ d[27] ^ d[28] ^ d[31] ^ d[32] ^ d[35] ^ d[38] ^ d[39] ^ d[42] ^ d[43] ^ d[44] ^ d[45] ^ d[46] ^ d[47] ^ d[48] ^ d[49] ^ d[50] ^ d[52] ^ d[55] ^ d[61] ^ d[62] ^ d[63] ^ d[64] ^ d[65] ^ d[68] ^ d[69] ^ d[77] ^ d[82] ^ d[84] ^ d[85] ^ d[87] ^ d[88] ^ d[89] ^ d[90] ^ d[93] ^ d[95] ^ d[97] ^ d[98] ^ d[100] ^ d[101] ^ d[102] ^ d[105] ^ d[106] ^ d[108] ^ d[109] ^ d[110] ^ d[112] ^ d[113] ^ d[114] ^ d[118] ^ d[119] ^ d[121] ^ d[122] ^ d[123] ^ d[124] ^ d[126];
      crc_128[11] = d[1] ^ d[4] ^ d[6] ^ d[7] ^ d[8] ^ d[9] ^ d[10] ^ d[11] ^ d[12] ^ d[13] ^ d[14] ^ d[15] ^ d[19] ^ d[21] ^ d[22] ^ d[24] ^ d[27] ^ d[28] ^ d[29] ^ d[32] ^ d[33] ^ d[36] ^ d[39] ^ d[40] ^ d[43] ^ d[44] ^ d[45] ^ d[46] ^ d[47] ^ d[48] ^ d[49] ^ d[50] ^ d[51] ^ d[53] ^ d[56] ^ d[62] ^ d[63] ^ d[64] ^ d[65] ^ d[66] ^ d[69] ^ d[70] ^ d[78] ^ d[83] ^ d[85] ^ d[86] ^ d[88] ^ d[89] ^ d[90] ^ d[91] ^ d[94] ^ d[96] ^ d[98] ^ d[99] ^ d[101] ^ d[102] ^ d[103] ^ d[106] ^ d[107] ^ d[109] ^ d[110] ^ d[111] ^ d[113] ^ d[114] ^ d[115] ^ d[119] ^ d[120] ^ d[122] ^ d[123] ^ d[124] ^ d[125] ^ d[127];
      crc_128[12] = d[0] ^ d[3] ^ d[5] ^ d[6] ^ d[11] ^ d[12] ^ d[14] ^ d[15] ^ d[16] ^ d[18] ^ d[19] ^ d[20] ^ d[22] ^ d[24] ^ d[26] ^ d[30] ^ d[32] ^ d[33] ^ d[34] ^ d[35] ^ d[36] ^ d[37] ^ d[38] ^ d[40] ^ d[41] ^ d[42] ^ d[44] ^ d[45] ^ d[47] ^ d[48] ^ d[49] ^ d[50] ^ d[55] ^ d[56] ^ d[57] ^ d[60] ^ d[61] ^ d[62] ^ d[63] ^ d[65] ^ d[66] ^ d[67] ^ d[69] ^ d[71] ^ d[75] ^ d[77] ^ d[78] ^ d[79] ^ d[82] ^ d[83] ^ d[87] ^ d[88] ^ d[98] ^ d[100] ^ d[102] ^ d[103] ^ d[107] ^ d[108] ^ d[110] ^ d[113] ^ d[115] ^ d[116] ^ d[119] ^ d[126];
      crc_128[13] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[8] ^ d[9] ^ d[10] ^ d[12] ^ d[15] ^ d[16] ^ d[17] ^ d[18] ^ d[20] ^ d[21] ^ d[24] ^ d[26] ^ d[27] ^ d[28] ^ d[29] ^ d[31] ^ d[32] ^ d[33] ^ d[34] ^ d[37] ^ d[39] ^ d[41] ^ d[43] ^ d[45] ^ d[48] ^ d[49] ^ d[50] ^ d[52] ^ d[54] ^ d[55] ^ d[57] ^ d[58] ^ d[60] ^ d[63] ^ d[66] ^ d[67] ^ d[68] ^ d[69] ^ d[72] ^ d[75] ^ d[76] ^ d[77] ^ d[79] ^ d[80] ^ d[82] ^ d[86] ^ d[90] ^ d[91] ^ d[92] ^ d[95] ^ d[97] ^ d[98] ^ d[101] ^ d[103] ^ d[108] ^ d[109] ^ d[112] ^ d[113] ^ d[116] ^ d[117] ^ d[119] ^ d[121] ^ d[123] ^ d[124] ^ d[125] ^ d[127];
      crc_128[14] = d[0] ^ d[1] ^ d[4] ^ d[5] ^ d[6] ^ d[7] ^ d[8] ^ d[11] ^ d[16] ^ d[17] ^ d[21] ^ d[22] ^ d[23] ^ d[24] ^ d[26] ^ d[27] ^ d[30] ^ d[33] ^ d[34] ^ d[36] ^ d[40] ^ d[44] ^ d[49] ^ d[50] ^ d[52] ^ d[53] ^ d[54] ^ d[58] ^ d[59] ^ d[60] ^ d[62] ^ d[67] ^ d[68] ^ d[73] ^ d[75] ^ d[76] ^ d[80] ^ d[81] ^ d[82] ^ d[84] ^ d[86] ^ d[87] ^ d[88] ^ d[89] ^ d[90] ^ d[93] ^ d[95] ^ d[96] ^ d[97] ^ d[102] ^ d[109] ^ d[110] ^ d[111] ^ d[112] ^ d[117] ^ d[118] ^ d[119] ^ d[121] ^ d[122] ^ d[123] ^ d[126];
      crc_128[15] = d[1] ^ d[2] ^ d[5] ^ d[6] ^ d[7] ^ d[8] ^ d[9] ^ d[12] ^ d[17] ^ d[18] ^ d[22] ^ d[23] ^ d[24] ^ d[25] ^ d[27] ^ d[28] ^ d[31] ^ d[34] ^ d[35] ^ d[37] ^ d[41] ^ d[45] ^ d[50] ^ d[51] ^ d[53] ^ d[54] ^ d[55] ^ d[59] ^ d[60] ^ d[61] ^ d[63] ^ d[68] ^ d[69] ^ d[74] ^ d[76] ^ d[77] ^ d[81] ^ d[82] ^ d[83] ^ d[85] ^ d[87] ^ d[88] ^ d[89] ^ d[90] ^ d[91] ^ d[94] ^ d[96] ^ d[97] ^ d[98] ^ d[103] ^ d[110] ^ d[111] ^ d[112] ^ d[113] ^ d[118] ^ d[119] ^ d[120] ^ d[122] ^ d[123] ^ d[124] ^ d[127];
    end
  endfunction

  assign adc_crc_err = (adc_crc == adc_crc_res) ? 1'b0 : 1'b1;

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

  assign adc_status_er_5b = adc_status_0[7:3] | adc_status_1[7:3] | adc_status_2[7:3] | adc_status_3[7:3] | adc_status_4[7:3] | adc_status_5[7:3] | adc_status_6[7:3] | adc_status_7[7:3];
  assign adc_status_er = adc_status_er_5b[0] | adc_status_er_5b[1] | adc_status_er_5b[2] | adc_status_er_5b[3] | adc_status_er_5b[4] | adc_status_er_5b[5] | adc_status_er_5b[6] | adc_status_er_5b[7];
  assign adc_status = (ADC_READ_MODE == STATUS_HEADER) ? (adc_status_er ? 1'b0 : 1'b1) : 1'b1;

  assign cs_n = (transfer_state == IDLE) ? 1'b1 : 1'b0;
  assign db_t = ~wr_req_d;
  assign rd_n = ((transfer_state == CNTRL_LOW) && ((rd_conv_d == 1'b1) || rd_req_d == 1'b1)) ? 1'b0 : 1'b1;
  assign wr_n = ((transfer_state == CNTRL_LOW) && (wr_req_d == 1'b1)) ? 1'b0 : 1'b1;

endmodule
