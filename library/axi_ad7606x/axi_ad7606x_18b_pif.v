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

module axi_ad7606x_18b_pif #(

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

  output  reg [17:0]      adc_data_0,
  output  reg [ 7:0]      adc_status_0 = 'h0,
  output  reg [17:0]      adc_data_1,
  output  reg [ 7:0]      adc_status_1 = 'h0,
  output  reg [17:0]      adc_data_2,
  output  reg [ 7:0]      adc_status_2 = 'h0,
  output  reg [17:0]      adc_data_3,
  output  reg [ 7:0]      adc_status_3 = 'h0,
  output  reg [17:0]      adc_data_4,
  output  reg [ 7:0]      adc_status_4 = 'h0,
  output  reg [17:0]      adc_data_5,
  output  reg [ 7:0]      adc_status_5 = 'h0,
  output  reg [17:0]      adc_data_6,
  output  reg [ 7:0]      adc_status_6 = 'h0,
  output  reg [17:0]      adc_data_7,
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
        nr_rd_burst = 5'd16;
        if (first_data & ~cs_n) begin
          read_ch_data <= 1'b1;
        end else if (channel_counter == 5'd8 && transfer_state == IDLE) begin
          read_ch_data <= 1'b0;
        end
      end else if (ADC_READ_MODE == CRC_ENABLED) begin
        nr_rd_burst = 5'd17;
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
              adc_data_0[17:16] <= rd_data[1:0];
              adc_data_0[15:2] <= rd_data[15:2];
            end
            5'd1 : begin
              adc_data_0[1:0] <= rd_data[1:0];
	      if (ADC_READ_MODE == STATUS_HEADER) begin
                adc_status_0 <= rd_data[9:2];
              end
            end
            5'd2 : begin
              adc_data_1[17:16] <= rd_data[1:0];
              adc_data_1[15:2] <= rd_data[15:2];
            end
            5'd3 : begin
              adc_data_1[1:0] <= rd_data[1:0];
              if (ADC_READ_MODE == STATUS_HEADER) begin
                adc_status_1 <= rd_data[9:2];
              end
            end
            5'd4 : begin
              adc_data_2[17:16] <= rd_data[1:0];
              adc_data_2[15:2] <= rd_data[15:2];
            end
            5'd5 : begin
              adc_data_2[1:0] <= rd_data[1:0];
              if (ADC_READ_MODE == STATUS_HEADER) begin
                adc_status_2 <= rd_data[9:2];
              end
            end
            5'd6 : begin
              adc_data_3[17:16] <= rd_data[1:0];
              adc_data_3[15:2] <= rd_data[15:2];
            end
            5'd7 : begin
              adc_data_3[1:0] <= rd_data[1:0];
              if (ADC_READ_MODE == STATUS_HEADER) begin
                adc_status_3 <= rd_data[9:2];
              end
            end
            5'd8 : begin
              adc_data_4[17:16] <= rd_data[1:0];
              adc_data_4[15:2] <= rd_data[15:2];
            end
            5'd9 : begin
              adc_data_4[1:0] <= rd_data[1:0];
              if (ADC_READ_MODE == STATUS_HEADER) begin
                adc_status_4 <= rd_data[9:2];
              end
            end
            5'd10 : begin
              adc_data_5[17:16] <= rd_data[1:0];
              adc_data_5[15:2] <= rd_data[15:2];
            end
            5'd11 : begin
              adc_data_5[1:0] <= rd_data[1:0];
              if (ADC_READ_MODE == STATUS_HEADER) begin
                adc_status_5 <= rd_data[9:2];
              end
            end
            5'd12 : begin
              adc_data_6[17:16] <= rd_data[1:0];
              adc_data_6[15:2] <= rd_data[15:2];
            end
            5'd13 : begin
              adc_data_6[1:0] <= rd_data[1:0];
              if (ADC_READ_MODE == STATUS_HEADER) begin
                adc_status_6 <= rd_data[9:2];
              end
            end
            5'd14 : begin
              adc_data_7[17:16] <= rd_data[1:0];
              adc_data_7[15:2] <= rd_data[15:2];
            end
            5'd15 : begin
              adc_data_7[1:0] <= rd_data[1:0];
              if (ADC_READ_MODE == STATUS_HEADER) begin
                adc_status_7 <= rd_data[9:2];
              end
            end
            5'd16 : begin
              adc_crc <= rd_data;
              adc_crc_res <= crc_256({adc_data_0,14'b0,adc_data_1,14'b0,adc_data_2,14'b0,adc_data_3,14'b0,adc_data_4,14'b0,adc_data_5,14'b0,adc_data_6,14'b0,adc_data_7,14'b0});
            end
          endcase
        end
        case (ADC_READ_MODE)
          SIMPLE: begin
            adc_valid <= (channel_counter == 5'd16) || (wr_req_d | rd_req_d) ? rd_valid_d : 1'b0;
          end
          STATUS_HEADER: begin
            adc_valid <= (channel_counter == 5'd16) || (wr_req_d | rd_req_d) ? rd_valid_d : 1'b0;
          end
          CRC_ENABLED: begin
            adc_valid <= (channel_counter == 5'd17) || (wr_req_d | rd_req_d) ? rd_valid_d : 1'b0;
          end
        endcase
      end
    end
  end

  function [15:0] crc_256;
    input [255:0] d;
    begin
      crc_256[0] = d[0] ^ d[2] ^ d[3] ^ d[6] ^ d[7] ^ d[8] ^ d[9] ^ d[10] ^ d[13] ^ d[18] ^ d[19] ^ d[23] ^ d[24] ^ d[25] ^ d[26] ^ d[28] ^ d[29] ^ d[32] ^ d[35] ^ d[36] ^ d[38] ^ d[42] ^ d[46] ^ d[51] ^ d[52] ^ d[54] ^ d[55] ^ d[56] ^ d[60] ^ d[61] ^ d[62] ^ d[64] ^ d[69] ^ d[70] ^ d[75] ^ d[77] ^ d[78] ^ d[82] ^ d[83] ^ d[84] ^ d[86] ^ d[88] ^ d[89] ^ d[90] ^ d[91] ^ d[92] ^ d[95] ^ d[97] ^ d[98] ^ d[99] ^ d[104] ^ d[111] ^ d[112] ^ d[113] ^ d[114] ^ d[119] ^ d[120] ^ d[121] ^ d[123] ^ d[124] ^ d[125] ^ d[128] ^ d[131] ^ d[133] ^ d[134] ^ d[136] ^ d[138] ^ d[139] ^ d[144] ^ d[150] ^ d[151] ^ d[153] ^ d[154] ^ d[155] ^ d[157] ^ d[158] ^ d[159] ^ d[160] ^ d[162] ^ d[163] ^ d[164] ^ d[165] ^ d[166] ^ d[169] ^ d[172] ^ d[175] ^ d[176] ^ d[177] ^ d[178] ^ d[179] ^ d[181] ^ d[184] ^ d[186] ^ d[189] ^ d[190] ^ d[192] ^ d[193] ^ d[194] ^ d[196] ^ d[197] ^ d[198] ^ d[200] ^ d[201] ^ d[203] ^ d[204] ^ d[205] ^ d[207] ^ d[208] ^ d[210] ^ d[211] ^ d[213] ^ d[216] ^ d[218] ^ d[220] ^ d[221] ^ d[222] ^ d[223] ^ d[224] ^ d[225] ^ d[226] ^ d[227] ^ d[229] ^ d[231] ^ d[235] ^ d[236] ^ d[241] ^ d[245] ^ d[248] ^ d[249] ^ d[252] ^ d[253] ^ d[254];
    crc_256[1] = d[0] ^ d[1] ^ d[2] ^ d[4] ^ d[6] ^ d[11] ^ d[13] ^ d[14] ^ d[18] ^ d[20] ^ d[23] ^ d[27] ^ d[28] ^ d[30] ^ d[32] ^ d[33] ^ d[35] ^ d[37] ^ d[38] ^ d[39] ^ d[42] ^ d[43] ^ d[46] ^ d[47] ^ d[51] ^ d[53] ^ d[54] ^ d[57] ^ d[60] ^ d[63] ^ d[64] ^ d[65] ^ d[69] ^ d[71] ^ d[75] ^ d[76] ^ d[77] ^ d[79] ^ d[82] ^ d[85] ^ d[86] ^ d[87] ^ d[88] ^ d[93] ^ d[95] ^ d[96] ^ d[97] ^ d[100] ^ d[104] ^ d[105] ^ d[111] ^ d[115] ^ d[119] ^ d[122] ^ d[123] ^ d[126] ^ d[128] ^ d[129] ^ d[131] ^ d[132] ^ d[133] ^ d[135] ^ d[136] ^ d[137] ^ d[138] ^ d[140] ^ d[144] ^ d[145] ^ d[150] ^ d[152] ^ d[153] ^ d[156] ^ d[157] ^ d[161] ^ d[162] ^ d[167] ^ d[169] ^ d[170] ^ d[172] ^ d[173] ^ d[175] ^ d[180] ^ d[181] ^ d[182] ^ d[184] ^ d[185] ^ d[186] ^ d[187] ^ d[189] ^ d[191] ^ d[192] ^ d[195] ^ d[196] ^ d[199] ^ d[200] ^ d[202] ^ d[203] ^ d[206] ^ d[207] ^ d[209] ^ d[210] ^ d[212] ^ d[213] ^ d[214] ^ d[216] ^ d[217] ^ d[218] ^ d[219] ^ d[220] ^ d[228] ^ d[229] ^ d[230] ^ d[231] ^ d[232] ^ d[235] ^ d[237] ^ d[241] ^ d[242] ^ d[245] ^ d[246] ^ d[248] ^ d[250] ^ d[252] ^ d[255];
    crc_256[2] = d[1] ^ d[2] ^ d[3] ^ d[5] ^ d[7] ^ d[12] ^ d[14] ^ d[15] ^ d[19] ^ d[21] ^ d[24] ^ d[28] ^ d[29] ^ d[31] ^ d[33] ^ d[34] ^ d[36] ^ d[38] ^ d[39] ^ d[40] ^ d[43] ^ d[44] ^ d[47] ^ d[48] ^ d[52] ^ d[54] ^ d[55] ^ d[58] ^ d[61] ^ d[64] ^ d[65] ^ d[66] ^ d[70] ^ d[72] ^ d[76] ^ d[77] ^ d[78] ^ d[80] ^ d[83] ^ d[86] ^ d[87] ^ d[88] ^ d[89] ^ d[94] ^ d[96] ^ d[97] ^ d[98] ^ d[101] ^ d[105] ^ d[106] ^ d[112] ^ d[116] ^ d[120] ^ d[123] ^ d[124] ^ d[127] ^ d[129] ^ d[130] ^ d[132] ^ d[133] ^ d[134] ^ d[136] ^ d[137] ^ d[138] ^ d[139] ^ d[141] ^ d[145] ^ d[146] ^ d[151] ^ d[153] ^ d[154] ^ d[157] ^ d[158] ^ d[162] ^ d[163] ^ d[168] ^ d[170] ^ d[171] ^ d[173] ^ d[174] ^ d[176] ^ d[181] ^ d[182] ^ d[183] ^ d[185] ^ d[186] ^ d[187] ^ d[188] ^ d[190] ^ d[192] ^ d[193] ^ d[196] ^ d[197] ^ d[200] ^ d[201] ^ d[203] ^ d[204] ^ d[207] ^ d[208] ^ d[210] ^ d[211] ^ d[213] ^ d[214] ^ d[215] ^ d[217] ^ d[218] ^ d[219] ^ d[220] ^ d[221] ^ d[229] ^ d[230] ^ d[231] ^ d[232] ^ d[233] ^ d[236] ^ d[238] ^ d[242] ^ d[243] ^ d[246] ^ d[247] ^ d[249] ^ d[251] ^ d[253];
    crc_256[3] = d[0] ^ d[4] ^ d[7] ^ d[9] ^ d[10] ^ d[15] ^ d[16] ^ d[18] ^ d[19] ^ d[20] ^ d[22] ^ d[23] ^ d[24] ^ d[26] ^ d[28] ^ d[30] ^ d[34] ^ d[36] ^ d[37] ^ d[38] ^ d[39] ^ d[40] ^ d[41] ^ d[42] ^ d[44] ^ d[45] ^ d[46] ^ d[48] ^ d[49] ^ d[51] ^ d[52] ^ d[53] ^ d[54] ^ d[59] ^ d[60] ^ d[61] ^ d[64] ^ d[65] ^ d[66] ^ d[67] ^ d[69] ^ d[70] ^ d[71] ^ d[73] ^ d[75] ^ d[79] ^ d[81] ^ d[82] ^ d[83] ^ d[86] ^ d[87] ^ d[91] ^ d[92] ^ d[102] ^ d[104] ^ d[106] ^ d[107] ^ d[111] ^ d[112] ^ d[114] ^ d[117] ^ d[119] ^ d[120] ^ d[123] ^ d[130] ^ d[135] ^ d[136] ^ d[137] ^ d[140] ^ d[142] ^ d[144] ^ d[146] ^ d[147] ^ d[150] ^ d[151] ^ d[152] ^ d[153] ^ d[157] ^ d[160] ^ d[162] ^ d[165] ^ d[166] ^ d[171] ^ d[174] ^ d[176] ^ d[178] ^ d[179] ^ d[181] ^ d[182] ^ d[183] ^ d[187] ^ d[188] ^ d[190] ^ d[191] ^ d[192] ^ d[196] ^ d[200] ^ d[202] ^ d[203] ^ d[207] ^ d[209] ^ d[210] ^ d[212] ^ d[213] ^ d[214] ^ d[215] ^ d[219] ^ d[223] ^ d[224] ^ d[225] ^ d[226] ^ d[227] ^ d[229] ^ d[230] ^ d[232] ^ d[233] ^ d[234] ^ d[235] ^ d[236] ^ d[237] ^ d[239] ^ d[241] ^ d[243] ^ d[244] ^ d[245] ^ d[247] ^ d[249] ^ d[250] ^ d[253];
    crc_256[4] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[5] ^ d[6] ^ d[7] ^ d[9] ^ d[11] ^ d[13] ^ d[16] ^ d[17] ^ d[18] ^ d[20] ^ d[21] ^ d[26] ^ d[27] ^ d[28] ^ d[31] ^ d[32] ^ d[36] ^ d[37] ^ d[39] ^ d[40] ^ d[41] ^ d[43] ^ d[45] ^ d[47] ^ d[49] ^ d[50] ^ d[51] ^ d[53] ^ d[56] ^ d[64] ^ d[65] ^ d[66] ^ d[67] ^ d[68] ^ d[69] ^ d[71] ^ d[72] ^ d[74] ^ d[75] ^ d[76] ^ d[77] ^ d[78] ^ d[80] ^ d[86] ^ d[87] ^ d[89] ^ d[90] ^ d[91] ^ d[93] ^ d[95] ^ d[97] ^ d[98] ^ d[99] ^ d[103] ^ d[104] ^ d[105] ^ d[107] ^ d[108] ^ d[111] ^ d[114] ^ d[115] ^ d[118] ^ d[119] ^ d[123] ^ d[125] ^ d[128] ^ d[133] ^ d[134] ^ d[137] ^ d[139] ^ d[141] ^ d[143] ^ d[144] ^ d[145] ^ d[147] ^ d[148] ^ d[150] ^ d[152] ^ d[155] ^ d[157] ^ d[159] ^ d[160] ^ d[161] ^ d[162] ^ d[164] ^ d[165] ^ d[167] ^ d[169] ^ d[176] ^ d[178] ^ d[180] ^ d[181] ^ d[182] ^ d[183] ^ d[186] ^ d[188] ^ d[190] ^ d[191] ^ d[194] ^ d[196] ^ d[198] ^ d[200] ^ d[205] ^ d[207] ^ d[214] ^ d[215] ^ d[218] ^ d[221] ^ d[222] ^ d[223] ^ d[228] ^ d[229] ^ d[230] ^ d[233] ^ d[234] ^ d[237] ^ d[238] ^ d[240] ^ d[241] ^ d[242] ^ d[244] ^ d[246] ^ d[249] ^ d[250] ^ d[251] ^ d[252] ^ d[253];
    crc_256[5] = d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[6] ^ d[7] ^ d[8] ^ d[10] ^ d[12] ^ d[14] ^ d[17] ^ d[18] ^ d[19] ^ d[21] ^ d[22] ^ d[27] ^ d[28] ^ d[29] ^ d[32] ^ d[33] ^ d[37] ^ d[38] ^ d[40] ^ d[41] ^ d[42] ^ d[44] ^ d[46] ^ d[48] ^ d[50] ^ d[51] ^ d[52] ^ d[54] ^ d[57] ^ d[65] ^ d[66] ^ d[67] ^ d[68] ^ d[69] ^ d[70] ^ d[72] ^ d[73] ^ d[75] ^ d[76] ^ d[77] ^ d[78] ^ d[79] ^ d[81] ^ d[87] ^ d[88] ^ d[90] ^ d[91] ^ d[92] ^ d[94] ^ d[96] ^ d[98] ^ d[99] ^ d[100] ^ d[104] ^ d[105] ^ d[106] ^ d[108] ^ d[109] ^ d[112] ^ d[115] ^ d[116] ^ d[119] ^ d[120] ^ d[124] ^ d[126] ^ d[129] ^ d[134] ^ d[135] ^ d[138] ^ d[140] ^ d[142] ^ d[144] ^ d[145] ^ d[146] ^ d[148] ^ d[149] ^ d[151] ^ d[153] ^ d[156] ^ d[158] ^ d[160] ^ d[161] ^ d[162] ^ d[163] ^ d[165] ^ d[166] ^ d[168] ^ d[170] ^ d[177] ^ d[179] ^ d[181] ^ d[182] ^ d[183] ^ d[184] ^ d[187] ^ d[189] ^ d[191] ^ d[192] ^ d[195] ^ d[197] ^ d[199] ^ d[201] ^ d[206] ^ d[208] ^ d[215] ^ d[216] ^ d[219] ^ d[222] ^ d[223] ^ d[224] ^ d[229] ^ d[230] ^ d[231] ^ d[234] ^ d[235] ^ d[238] ^ d[239] ^ d[241] ^ d[242] ^ d[243] ^ d[245] ^ d[247] ^ d[250] ^ d[251] ^ d[252] ^ d[253] ^ d[254];
    crc_256[6] = d[0] ^ d[4] ^ d[5] ^ d[6] ^ d[10] ^ d[11] ^ d[15] ^ d[20] ^ d[22] ^ d[24] ^ d[25] ^ d[26] ^ d[30] ^ d[32] ^ d[33] ^ d[34] ^ d[35] ^ d[36] ^ d[39] ^ d[41] ^ d[43] ^ d[45] ^ d[46] ^ d[47] ^ d[49] ^ d[53] ^ d[54] ^ d[56] ^ d[58] ^ d[60] ^ d[61] ^ d[62] ^ d[64] ^ d[66] ^ d[67] ^ d[68] ^ d[71] ^ d[73] ^ d[74] ^ d[75] ^ d[76] ^ d[79] ^ d[80] ^ d[83] ^ d[84] ^ d[86] ^ d[90] ^ d[93] ^ d[98] ^ d[100] ^ d[101] ^ d[104] ^ d[105] ^ d[106] ^ d[107] ^ d[109] ^ d[110] ^ d[111] ^ d[112] ^ d[114] ^ d[116] ^ d[117] ^ d[119] ^ d[123] ^ d[124] ^ d[127] ^ d[128] ^ d[130] ^ d[131] ^ d[133] ^ d[134] ^ d[135] ^ d[138] ^ d[141] ^ d[143] ^ d[144] ^ d[145] ^ d[146] ^ d[147] ^ d[149] ^ d[151] ^ d[152] ^ d[153] ^ d[155] ^ d[158] ^ d[160] ^ d[161] ^ d[165] ^ d[167] ^ d[171] ^ d[172] ^ d[175] ^ d[176] ^ d[177] ^ d[179] ^ d[180] ^ d[181] ^ d[182] ^ d[183] ^ d[185] ^ d[186] ^ d[188] ^ d[189] ^ d[194] ^ d[197] ^ d[201] ^ d[202] ^ d[203] ^ d[204] ^ d[205] ^ d[208] ^ d[209] ^ d[210] ^ d[211] ^ d[213] ^ d[217] ^ d[218] ^ d[221] ^ d[222] ^ d[226] ^ d[227] ^ d[229] ^ d[230] ^ d[232] ^ d[239] ^ d[240] ^ d[241] ^ d[242] ^ d[243] ^ d[244] ^ d[245] ^ d[246] ^ d[249] ^ d[251] ^ d[255];
    crc_256[7] = d[1] ^ d[5] ^ d[6] ^ d[7] ^ d[11] ^ d[12] ^ d[16] ^ d[21] ^ d[23] ^ d[25] ^ d[26] ^ d[27] ^ d[31] ^ d[33] ^ d[34] ^ d[35] ^ d[36] ^ d[37] ^ d[40] ^ d[42] ^ d[44] ^ d[46] ^ d[47] ^ d[48] ^ d[50] ^ d[54] ^ d[55] ^ d[57] ^ d[59] ^ d[61] ^ d[62] ^ d[63] ^ d[65] ^ d[67] ^ d[68] ^ d[69] ^ d[72] ^ d[74] ^ d[75] ^ d[76] ^ d[77] ^ d[80] ^ d[81] ^ d[84] ^ d[85] ^ d[87] ^ d[91] ^ d[94] ^ d[99] ^ d[101] ^ d[102] ^ d[105] ^ d[106] ^ d[107] ^ d[108] ^ d[110] ^ d[111] ^ d[112] ^ d[113] ^ d[115] ^ d[117] ^ d[118] ^ d[120] ^ d[124] ^ d[125] ^ d[128] ^ d[129] ^ d[131] ^ d[132] ^ d[134] ^ d[135] ^ d[136] ^ d[139] ^ d[142] ^ d[144] ^ d[145] ^ d[146] ^ d[147] ^ d[148] ^ d[150] ^ d[152] ^ d[153] ^ d[154] ^ d[156] ^ d[159] ^ d[161] ^ d[162] ^ d[166] ^ d[168] ^ d[172] ^ d[173] ^ d[176] ^ d[177] ^ d[178] ^ d[180] ^ d[181] ^ d[182] ^ d[183] ^ d[184] ^ d[186] ^ d[187] ^ d[189] ^ d[190] ^ d[195] ^ d[198] ^ d[202] ^ d[203] ^ d[204] ^ d[205] ^ d[206] ^ d[209] ^ d[210] ^ d[211] ^ d[212] ^ d[214] ^ d[218] ^ d[219] ^ d[222] ^ d[223] ^ d[227] ^ d[228] ^ d[230] ^ d[231] ^ d[233] ^ d[240] ^ d[241] ^ d[242] ^ d[243] ^ d[244] ^ d[245] ^ d[246] ^ d[247] ^ d[250] ^ d[252];
    crc_256[8] = d[0] ^ d[3] ^ d[9] ^ d[10] ^ d[12] ^ d[17] ^ d[18] ^ d[19] ^ d[22] ^ d[23] ^ d[25] ^ d[27] ^ d[29] ^ d[34] ^ d[37] ^ d[41] ^ d[42] ^ d[43] ^ d[45] ^ d[46] ^ d[47] ^ d[48] ^ d[49] ^ d[52] ^ d[54] ^ d[58] ^ d[61] ^ d[63] ^ d[66] ^ d[68] ^ d[73] ^ d[76] ^ d[81] ^ d[83] ^ d[84] ^ d[85] ^ d[89] ^ d[90] ^ d[91] ^ d[97] ^ d[98] ^ d[99] ^ d[100] ^ d[102] ^ d[103] ^ d[104] ^ d[106] ^ d[107] ^ d[108] ^ d[109] ^ d[116] ^ d[118] ^ d[120] ^ d[123] ^ d[124] ^ d[126] ^ d[128] ^ d[129] ^ d[130] ^ d[131] ^ d[132] ^ d[134] ^ d[135] ^ d[137] ^ d[138] ^ d[139] ^ d[140] ^ d[143] ^ d[144] ^ d[145] ^ d[146] ^ d[147] ^ d[148] ^ d[149] ^ d[150] ^ d[158] ^ d[159] ^ d[164] ^ d[165] ^ d[166] ^ d[167] ^ d[172] ^ d[173] ^ d[174] ^ d[175] ^ d[176] ^ d[182] ^ d[183] ^ d[185] ^ d[186] ^ d[187] ^ d[188] ^ d[189] ^ d[191] ^ d[192] ^ d[193] ^ d[194] ^ d[197] ^ d[198] ^ d[199] ^ d[200] ^ d[201] ^ d[206] ^ d[208] ^ d[212] ^ d[215] ^ d[216] ^ d[218] ^ d[219] ^ d[221] ^ d[222] ^ d[225] ^ d[226] ^ d[227] ^ d[228] ^ d[232] ^ d[234] ^ d[235] ^ d[236] ^ d[242] ^ d[243] ^ d[244] ^ d[246] ^ d[247] ^ d[249] ^ d[251] ^ d[252] ^ d[254];
    crc_256[9] = d[1] ^ d[4] ^ d[10] ^ d[11] ^ d[13] ^ d[18] ^ d[19] ^ d[20] ^ d[23] ^ d[24] ^ d[26] ^ d[28] ^ d[30] ^ d[35] ^ d[38] ^ d[42] ^ d[43] ^ d[44] ^ d[46] ^ d[47] ^ d[48] ^ d[49] ^ d[50] ^ d[53] ^ d[55] ^ d[59] ^ d[62] ^ d[64] ^ d[67] ^ d[69] ^ d[74] ^ d[77] ^ d[82] ^ d[84] ^ d[85] ^ d[86] ^ d[90] ^ d[91] ^ d[92] ^ d[98] ^ d[99] ^ d[100] ^ d[101] ^ d[103] ^ d[104] ^ d[105] ^ d[107] ^ d[108] ^ d[109] ^ d[110] ^ d[117] ^ d[119] ^ d[121] ^ d[124] ^ d[125] ^ d[127] ^ d[129] ^ d[130] ^ d[131] ^ d[132] ^ d[133] ^ d[135] ^ d[136] ^ d[138] ^ d[139] ^ d[140] ^ d[141] ^ d[144] ^ d[145] ^ d[146] ^ d[147] ^ d[148] ^ d[149] ^ d[150] ^ d[151] ^ d[159] ^ d[160] ^ d[165] ^ d[166] ^ d[167] ^ d[168] ^ d[173] ^ d[174] ^ d[175] ^ d[176] ^ d[177] ^ d[183] ^ d[184] ^ d[186] ^ d[187] ^ d[188] ^ d[189] ^ d[190] ^ d[192] ^ d[193] ^ d[194] ^ d[195] ^ d[198] ^ d[199] ^ d[200] ^ d[201] ^ d[202] ^ d[207] ^ d[209] ^ d[213] ^ d[216] ^ d[217] ^ d[219] ^ d[220] ^ d[222] ^ d[223] ^ d[226] ^ d[227] ^ d[228] ^ d[229] ^ d[233] ^ d[235] ^ d[236] ^ d[237] ^ d[243] ^ d[244] ^ d[245] ^ d[247] ^ d[248] ^ d[250] ^ d[252] ^ d[253] ^ d[255];
    crc_256[10] = d[0] ^ d[3] ^ d[5] ^ d[6] ^ d[7] ^ d[8] ^ d[9] ^ d[10] ^ d[11] ^ d[12] ^ d[13] ^ d[14] ^ d[18] ^ d[20] ^ d[21] ^ d[23] ^ d[26] ^ d[27] ^ d[28] ^ d[31] ^ d[32] ^ d[35] ^ d[38] ^ d[39] ^ d[42] ^ d[43] ^ d[44] ^ d[45] ^ d[46] ^ d[47] ^ d[48] ^ d[49] ^ d[50] ^ d[52] ^ d[55] ^ d[61] ^ d[62] ^ d[63] ^ d[64] ^ d[65] ^ d[68] ^ d[69] ^ d[77] ^ d[82] ^ d[84] ^ d[85] ^ d[87] ^ d[88] ^ d[89] ^ d[90] ^ d[93] ^ d[95] ^ d[97] ^ d[98] ^ d[100] ^ d[101] ^ d[102] ^ d[105] ^ d[106] ^ d[108] ^ d[109] ^ d[110] ^ d[112] ^ d[113] ^ d[114] ^ d[118] ^ d[119] ^ d[121] ^ d[122] ^ d[123] ^ d[124] ^ d[126] ^ d[130] ^ d[132] ^ d[137] ^ d[138] ^ d[140] ^ d[141] ^ d[142] ^ d[144] ^ d[145] ^ d[146] ^ d[147] ^ d[148] ^ d[149] ^ d[152] ^ d[153] ^ d[154] ^ d[155] ^ d[157] ^ d[158] ^ d[159] ^ d[161] ^ d[162] ^ d[163] ^ d[164] ^ d[165] ^ d[167] ^ d[168] ^ d[172] ^ d[174] ^ d[179] ^ d[181] ^ d[185] ^ d[186] ^ d[187] ^ d[188] ^ d[191] ^ d[192] ^ d[195] ^ d[197] ^ d[198] ^ d[199] ^ d[202] ^ d[204] ^ d[205] ^ d[207] ^ d[211] ^ d[213] ^ d[214] ^ d[216] ^ d[217] ^ d[222] ^ d[225] ^ d[226] ^ d[228] ^ d[230] ^ d[231] ^ d[234] ^ d[235] ^ d[237] ^ d[238] ^ d[241] ^ d[244] ^ d[246] ^ d[251] ^ d[252];
    crc_256[11] = d[1] ^ d[4] ^ d[6] ^ d[7] ^ d[8] ^ d[9] ^ d[10] ^ d[11] ^ d[12] ^ d[13] ^ d[14] ^ d[15] ^ d[19] ^ d[21] ^ d[22] ^ d[24] ^ d[27] ^ d[28] ^ d[29] ^ d[32] ^ d[33] ^ d[36] ^ d[39] ^ d[40] ^ d[43] ^ d[44] ^ d[45] ^ d[46] ^ d[47] ^ d[48] ^ d[49] ^ d[50] ^ d[51] ^ d[53] ^ d[56] ^ d[62] ^ d[63] ^ d[64] ^ d[65] ^ d[66] ^ d[69] ^ d[70] ^ d[78] ^ d[83] ^ d[85] ^ d[86] ^ d[88] ^ d[89] ^ d[90] ^ d[91] ^ d[94] ^ d[96] ^ d[98] ^ d[99] ^ d[101] ^ d[102] ^ d[103] ^ d[106] ^ d[107] ^ d[109] ^ d[110] ^ d[111] ^ d[113] ^ d[114] ^ d[115] ^ d[119] ^ d[120] ^ d[122] ^ d[123] ^ d[124] ^ d[125] ^ d[127] ^ d[131] ^ d[133] ^ d[138] ^ d[139] ^ d[141] ^ d[142] ^ d[143] ^ d[145] ^ d[146] ^ d[147] ^ d[148] ^ d[149] ^ d[150] ^ d[153] ^ d[154] ^ d[155] ^ d[156] ^ d[158] ^ d[159] ^ d[160] ^ d[162] ^ d[163] ^ d[164] ^ d[165] ^ d[166] ^ d[168] ^ d[169] ^ d[173] ^ d[175] ^ d[180] ^ d[182] ^ d[186] ^ d[187] ^ d[188] ^ d[189] ^ d[192] ^ d[193] ^ d[196] ^ d[198] ^ d[199] ^ d[200] ^ d[203] ^ d[205] ^ d[206] ^ d[208] ^ d[212] ^ d[214] ^ d[215] ^ d[217] ^ d[218] ^ d[223] ^ d[226] ^ d[227] ^ d[229] ^ d[231] ^ d[232] ^ d[235] ^ d[236] ^ d[238] ^ d[239] ^ d[242] ^ d[245] ^ d[247] ^ d[252] ^ d[253];
    crc_256[12] = d[0] ^ d[3] ^ d[5] ^ d[6] ^ d[11] ^ d[12] ^ d[14] ^ d[15] ^ d[16] ^ d[18] ^ d[19] ^ d[20] ^ d[22] ^ d[24] ^ d[26] ^ d[30] ^ d[32] ^ d[33] ^ d[34] ^ d[35] ^ d[36] ^ d[37] ^ d[38] ^ d[40] ^ d[41] ^ d[42] ^ d[44] ^ d[45] ^ d[47] ^ d[48] ^ d[49] ^ d[50] ^ d[55] ^ d[56] ^ d[57] ^ d[60] ^ d[61] ^ d[62] ^ d[63] ^ d[65] ^ d[66] ^ d[67] ^ d[69] ^ d[71] ^ d[75] ^ d[77] ^ d[78] ^ d[79] ^ d[82] ^ d[83] ^ d[87] ^ d[88] ^ d[98] ^ d[100] ^ d[102] ^ d[103] ^ d[107] ^ d[108] ^ d[110] ^ d[113] ^ d[115] ^ d[116] ^ d[119] ^ d[126] ^ d[131] ^ d[132] ^ d[133] ^ d[136] ^ d[138] ^ d[140] ^ d[142] ^ d[143] ^ d[146] ^ d[147] ^ d[148] ^ d[149] ^ d[153] ^ d[156] ^ d[158] ^ d[161] ^ d[162] ^ d[167] ^ d[170] ^ d[172] ^ d[174] ^ d[175] ^ d[177] ^ d[178] ^ d[179] ^ d[183] ^ d[184] ^ d[186] ^ d[187] ^ d[188] ^ d[192] ^ d[196] ^ d[198] ^ d[199] ^ d[203] ^ d[205] ^ d[206] ^ d[208] ^ d[209] ^ d[210] ^ d[211] ^ d[215] ^ d[219] ^ d[220] ^ d[221] ^ d[222] ^ d[223] ^ d[225] ^ d[226] ^ d[228] ^ d[229] ^ d[230] ^ d[231] ^ d[232] ^ d[233] ^ d[235] ^ d[237] ^ d[239] ^ d[240] ^ d[241] ^ d[243] ^ d[245] ^ d[246] ^ d[249] ^ d[252];
    crc_256[13] = d[0] ^ d[1] ^ d[2] ^ d[3] ^ d[4] ^ d[8] ^ d[9] ^ d[10] ^ d[12] ^ d[15] ^ d[16] ^ d[17] ^ d[18] ^ d[20] ^ d[21] ^ d[24] ^ d[26] ^ d[27] ^ d[28] ^ d[29] ^ d[31] ^ d[32] ^ d[33] ^ d[34] ^ d[37] ^ d[39] ^ d[41] ^ d[43] ^ d[45] ^ d[48] ^ d[49] ^ d[50] ^ d[52] ^ d[54] ^ d[55] ^ d[57] ^ d[58] ^ d[60] ^ d[63] ^ d[66] ^ d[67] ^ d[68] ^ d[69] ^ d[72] ^ d[75] ^ d[76] ^ d[77] ^ d[79] ^ d[80] ^ d[82] ^ d[86] ^ d[90] ^ d[91] ^ d[92] ^ d[95] ^ d[97] ^ d[98] ^ d[101] ^ d[103] ^ d[108] ^ d[109] ^ d[112] ^ d[113] ^ d[116] ^ d[117] ^ d[119] ^ d[121] ^ d[123] ^ d[124] ^ d[125] ^ d[127] ^ d[128] ^ d[131] ^ d[132] ^ d[136] ^ d[137] ^ d[138] ^ d[141] ^ d[143] ^ d[147] ^ d[148] ^ d[149] ^ d[151] ^ d[153] ^ d[155] ^ d[158] ^ d[160] ^ d[164] ^ d[165] ^ d[166] ^ d[168] ^ d[169] ^ d[171] ^ d[172] ^ d[173] ^ d[177] ^ d[180] ^ d[181] ^ d[185] ^ d[186] ^ d[187] ^ d[188] ^ d[190] ^ d[192] ^ d[194] ^ d[196] ^ d[198] ^ d[199] ^ d[201] ^ d[203] ^ d[205] ^ d[206] ^ d[208] ^ d[209] ^ d[212] ^ d[213] ^ d[218] ^ d[225] ^ d[230] ^ d[232] ^ d[233] ^ d[234] ^ d[235] ^ d[238] ^ d[240] ^ d[242] ^ d[244] ^ d[245] ^ d[246] ^ d[247] ^ d[248] ^ d[249] ^ d[250] ^ d[252] ^ d[254];
    crc_256[14] = d[0] ^ d[1] ^ d[4] ^ d[5] ^ d[6] ^ d[7] ^ d[8] ^ d[11] ^ d[16] ^ d[17] ^ d[21] ^ d[22] ^ d[23] ^ d[24] ^ d[26] ^ d[27] ^ d[30] ^ d[33] ^ d[34] ^ d[36] ^ d[40] ^ d[44] ^ d[49] ^ d[50] ^ d[52] ^ d[53] ^ d[54] ^ d[58] ^ d[59] ^ d[60] ^ d[62] ^ d[67] ^ d[68] ^ d[73] ^ d[75] ^ d[76] ^ d[80] ^ d[81] ^ d[82] ^ d[84] ^ d[86] ^ d[87] ^ d[88] ^ d[89] ^ d[90] ^ d[93] ^ d[95] ^ d[96] ^ d[97] ^ d[102] ^ d[109] ^ d[110] ^ d[111] ^ d[112] ^ d[117] ^ d[118] ^ d[119] ^ d[121] ^ d[122] ^ d[123] ^ d[126] ^ d[129] ^ d[131] ^ d[132] ^ d[134] ^ d[136] ^ d[137] ^ d[142] ^ d[148] ^ d[149] ^ d[151] ^ d[152] ^ d[153] ^ d[155] ^ d[156] ^ d[157] ^ d[158] ^ d[160] ^ d[161] ^ d[162] ^ d[163] ^ d[164] ^ d[167] ^ d[170] ^ d[173] ^ d[174] ^ d[175] ^ d[176] ^ d[177] ^ d[179] ^ d[182] ^ d[184] ^ d[187] ^ d[188] ^ d[190] ^ d[191] ^ d[192] ^ d[194] ^ d[195] ^ d[196] ^ d[198] ^ d[199] ^ d[201] ^ d[202] ^ d[203] ^ d[205] ^ d[206] ^ d[208] ^ d[209] ^ d[211] ^ d[214] ^ d[216] ^ d[218] ^ d[219] ^ d[220] ^ d[221] ^ d[222] ^ d[223] ^ d[224] ^ d[225] ^ d[227] ^ d[229] ^ d[233] ^ d[234] ^ d[239] ^ d[243] ^ d[246] ^ d[247] ^ d[250] ^ d[251] ^ d[252] ^ d[254] ^ d[255];
    crc_256[15] = d[1] ^ d[2] ^ d[5] ^ d[6] ^ d[7] ^ d[8] ^ d[9] ^ d[12] ^ d[17] ^ d[18] ^ d[22] ^ d[23] ^ d[24] ^ d[25] ^ d[27] ^ d[28] ^ d[31] ^ d[34] ^ d[35] ^ d[37] ^ d[41] ^ d[45] ^ d[50] ^ d[51] ^ d[53] ^ d[54] ^ d[55] ^ d[59] ^ d[60] ^ d[61] ^ d[63] ^ d[68] ^ d[69] ^ d[74] ^ d[76] ^ d[77] ^ d[81] ^ d[82] ^ d[83] ^ d[85] ^ d[87] ^ d[88] ^ d[89] ^ d[90] ^ d[91] ^ d[94] ^ d[96] ^ d[97] ^ d[98] ^ d[103] ^ d[110] ^ d[111] ^ d[112] ^ d[113] ^ d[118] ^ d[119] ^ d[120] ^ d[122] ^ d[123] ^ d[124] ^ d[127] ^ d[130] ^ d[132] ^ d[133] ^ d[135] ^ d[137] ^ d[138] ^ d[143] ^ d[149] ^ d[150] ^ d[152] ^ d[153] ^ d[154] ^ d[156] ^ d[157] ^ d[158] ^ d[159] ^ d[161] ^ d[162] ^ d[163] ^ d[164] ^ d[165] ^ d[168] ^ d[171] ^ d[174] ^ d[175] ^ d[176] ^ d[177] ^ d[178] ^ d[180] ^ d[183] ^ d[185] ^ d[188] ^ d[189] ^ d[191] ^ d[192] ^ d[193] ^ d[195] ^ d[196] ^ d[197] ^ d[199] ^ d[200] ^ d[202] ^ d[203] ^ d[204] ^ d[206] ^ d[207] ^ d[209] ^ d[210] ^ d[212] ^ d[215] ^ d[217] ^ d[219] ^ d[220] ^ d[221] ^ d[222] ^ d[223] ^ d[224] ^ d[225] ^ d[226] ^ d[228] ^ d[230] ^ d[234] ^ d[235] ^ d[240] ^ d[244] ^ d[247] ^ d[248] ^ d[251] ^ d[252] ^ d[253] ^ d[255];
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
