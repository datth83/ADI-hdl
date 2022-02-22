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

module util_hbm #(
  parameter SRC_DATA_WIDTH = 512,
  parameter DST_DATA_WIDTH = 128,

  parameter LENGTH_WIDTH = 32,

  parameter AXI_DATA_WIDTH = 256,
  parameter AXI_ADDR_WIDTH = 32,

  parameter AXI_ID_WIDTH = 6,

  parameter ASYNC_CLK_SAXIS_UP = 1,
  parameter ASYNC_CLK_MAXIS_UP = 1,

  parameter AXI_SLICE_DEST = 0,
  parameter AXI_SLICE_SRC = 0,

  // This will size the storage per master where each segment is 256MB
  parameter HBM_SEGMENTS_PER_MASTER = 4,

  // <TODO> This should depend on sample rate too
  parameter NUM_M = SRC_DATA_WIDTH <= AXI_DATA_WIDTH ? 1 :
                   (SRC_DATA_WIDTH / AXI_DATA_WIDTH)
) (

  input                                    up_clk,
  input                                    up_reset,

  input                                    up_src_request_enable,
  input                                    up_src_request_valid,
  output                                   up_src_request_ready,
  input   [LENGTH_WIDTH-1:0]               up_src_request_length,
  output                                   up_src_request_eot,

  input                                    up_dst_request_enable,
  input                                    up_dst_request_valid,
  output                                   up_dst_request_ready,
  input   [LENGTH_WIDTH-1:0]               up_dst_request_length,
  output                                   up_dst_request_eot,

  // Slave streaming AXI interface
  input                                    s_axis_aclk,
  output                                   s_axis_ready,
  input                                    s_axis_valid,
  input  [SRC_DATA_WIDTH-1:0]              s_axis_data,
  input  [SRC_DATA_WIDTH/8-1:0]            s_axis_strb,
  input  [SRC_DATA_WIDTH/8-1:0]            s_axis_keep,
  input  [0:0]                             s_axis_user,
  input                                    s_axis_last,

  // Master streaming AXI interface
  input                                    m_axis_aclk,
  input                                    m_axis_ready,
  output                                   m_axis_valid,
  output [DST_DATA_WIDTH-1:0]              m_axis_data,
  output [DST_DATA_WIDTH/8-1:0]            m_axis_strb,
  output [DST_DATA_WIDTH/8-1:0]            m_axis_keep,
  output [0:0]                             m_axis_user,
  output                                   m_axis_last,

  // Master AXI3 interface
  input                                    m_axi_aclk,
  input                                    m_axi_aresetn,

  // Write address
  output [NUM_M*AXI_ADDR_WIDTH-1:0]        m_axi_awaddr,
  output [NUM_M*4-1:0]                     m_axi_awlen,
  output [NUM_M*3-1:0]                     m_axi_awsize,
  output [NUM_M*2-1:0]                     m_axi_awburst,
  output [NUM_M-1:0]                       m_axi_awvalid,
  input  [NUM_M-1:0]                       m_axi_awready,
  output [NUM_M*AXI_ID_WIDTH-1:0]          m_axi_awid,

  // Write data
  output [NUM_M*AXI_DATA_WIDTH-1:0]        m_axi_wdata,
  output [NUM_M*(AXI_DATA_WIDTH/8)-1:0]    m_axi_wstrb,
  input  [NUM_M-1:0]                       m_axi_wready,
  output [NUM_M-1:0]                       m_axi_wvalid,
  output [NUM_M-1:0]                       m_axi_wlast,
  output [NUM_M*AXI_ID_WIDTH-1:0]          m_axi_wid,

  // Write response
  input  [NUM_M-1:0]                       m_axi_bvalid,
  input  [NUM_M*2-1:0]                     m_axi_bresp,
  output [NUM_M-1:0]                       m_axi_bready,
  input  [NUM_M*AXI_ID_WIDTH-1:0]          m_axi_bid,

  // Read address
  input  [NUM_M-1:0]                       m_axi_arready,
  output [NUM_M-1:0]                       m_axi_arvalid,
  output [NUM_M*AXI_ADDR_WIDTH-1:0]        m_axi_araddr,
  output [NUM_M*4-1:0]                     m_axi_arlen,
  output [NUM_M*3-1:0]                     m_axi_arsize,
  output [NUM_M*2-1:0]                     m_axi_arburst,
  output [NUM_M*AXI_ID_WIDTH-1:0]          m_axi_arid,

  // Read data and response
  input  [NUM_M*AXI_DATA_WIDTH-1:0]        m_axi_rdata,
  output [NUM_M-1:0]                       m_axi_rready,
  input  [NUM_M-1:0]                       m_axi_rvalid,
  input  [NUM_M*2-1:0]                     m_axi_rresp,
  input  [NUM_M*AXI_ID_WIDTH-1:0]          m_axi_rid,
  input  [NUM_M-1:0]                       m_axi_rlast

);

localparam DMA_TYPE_AXI_MM = 0;
localparam DMA_TYPE_AXI_STREAM = 1;
localparam DMA_TYPE_FIFO = 2;

localparam SRC_DATA_WIDTH_PER_M = SRC_DATA_WIDTH / NUM_M;
localparam DST_DATA_WIDTH_PER_M = DST_DATA_WIDTH / NUM_M;

localparam AXI_BYTES_PER_BEAT_WIDTH = $clog2(AXI_DATA_WIDTH);
localparam SRC_BYTES_PER_BEAT_WIDTH = $clog2(SRC_DATA_WIDTH_PER_M);
localparam DST_BYTES_PER_BEAT_WIDTH = $clog2(DST_DATA_WIDTH_PER_M);

// AXI 3  1 burst is 16 beats
localparam MAX_BYTES_PER_BURST = 16 * AXI_DATA_WIDTH/8;
localparam BYTES_PER_BURST_WIDTH = $clog2(MAX_BYTES_PER_BURST);

parameter FIFO_SIZE = 8; // In bursts

genvar i;

wire [NUM_M-1:0] up_src_request_ready_loc;
wire [NUM_M-1:0] up_dst_request_ready_loc;
wire [NUM_M-1:0] up_src_request_eot_loc;
wire [NUM_M-1:0] up_dst_request_eot_loc;

assign up_src_request_ready = &up_src_request_ready_loc;
assign up_dst_request_ready = &up_dst_request_ready_loc;

// Aggregate end of transfer from all masters
reg [NUM_M-1:0] up_src_eot_pending;
reg [NUM_M-1:0] up_dst_eot_pending;

assign up_src_request_eot = &up_src_request_eot_loc;
assign up_dst_request_eot = &up_dst_request_eot_loc;

wire [NUM_M-1:0] s_axis_ready_loc;
assign s_axis_ready = &s_axis_ready_loc;


wire [NUM_M-1:0] m_axis_last_loc;
assign m_axis_last = &m_axis_last_loc;

wire [NUM_M-1:0] m_axis_valid_loc;
assign m_axis_valid = &m_axis_valid_loc;

generate
for (i = 0; i < NUM_M; i=i+1) begin

  // 2Gb (256MB) per segment
  localparam ADDR_OFFSET = i * HBM_SEGMENTS_PER_MASTER * 256 * 1024 * 1024;

  always @(posedge up_clk) begin
    if (up_src_request_eot) begin
      up_src_eot_pending[i] <= 1'b0;
    end else if (up_src_request_eot_loc[i]) begin
      up_src_eot_pending[i] <= 1'b1;
    end
  end

  // AXIS to AXI3
  axi_dmac_transfer #(
    .DMA_DATA_WIDTH_SRC(SRC_DATA_WIDTH_PER_M),
    .DMA_DATA_WIDTH_DEST(AXI_DATA_WIDTH),
    .DMA_LENGTH_WIDTH(LENGTH_WIDTH),
    .DMA_LENGTH_ALIGN(SRC_BYTES_PER_BEAT_WIDTH),
    .BYTES_PER_BEAT_WIDTH_DEST(AXI_BYTES_PER_BEAT_WIDTH),
    .BYTES_PER_BEAT_WIDTH_SRC(SRC_BYTES_PER_BEAT_WIDTH),
    .BYTES_PER_BURST_WIDTH(BYTES_PER_BURST_WIDTH),
    .DMA_TYPE_DEST(DMA_TYPE_AXI_MM),
    .DMA_TYPE_SRC(DMA_TYPE_AXI_STREAM),
    .DMA_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .DMA_2D_TRANSFER(1'b0),
    .ASYNC_CLK_REQ_SRC(ASYNC_CLK_SAXIS_UP),
    .ASYNC_CLK_SRC_DEST(1),
    .ASYNC_CLK_DEST_REQ(1),
    .AXI_SLICE_DEST(1),
    .AXI_SLICE_SRC(1),
    .MAX_BYTES_PER_BURST(MAX_BYTES_PER_BURST),
    .FIFO_SIZE(FIFO_SIZE),
    .ID_WIDTH(AXI_ID_WIDTH),
    .AXI_LENGTH_WIDTH_SRC(8),
    .AXI_LENGTH_WIDTH_DEST(8),
    .ENABLE_DIAGNOSTICS_IF(0),
    .ALLOW_ASYM_MEM(1)
  ) i_src_transfer (
    .ctrl_clk(up_clk),
    .ctrl_resetn(~up_reset),

     // Control interface
    .ctrl_enable(up_src_request_enable),
    .ctrl_pause(1'b0),

    .req_valid(up_src_request_valid),
    .req_ready(up_src_request_ready_loc[i]),
    .req_dest_address(ADDR_OFFSET[AXI_ADDR_WIDTH-1:AXI_BYTES_PER_BEAT_WIDTH]),
    .req_src_address('h0),
    .req_x_length(up_src_request_length),
    .req_y_length(0),
    .req_dest_stride(0),
    .req_src_stride(0),
    .req_sync_transfer_start(1'b0),
    .req_last(1'b1),

    .req_eot(up_src_request_eot_loc[i]),
    .req_measured_burst_length(),
    .req_response_partial(),
    .req_response_valid(),
    .req_response_ready(1'b1),

    .m_dest_axi_aclk(m_axi_aclk),
    .m_dest_axi_aresetn(m_axi_aresetn),
    .m_src_axi_aclk(1'b0),
    .m_src_axi_aresetn(1'b0),

    .m_axi_awaddr(m_axi_awaddr[AXI_ADDR_WIDTH*i+:AXI_ADDR_WIDTH]),
    .m_axi_awlen(m_axi_awlen[4*i+:4]),
    .m_axi_awsize(m_axi_awsize[3*i+:3]),
    .m_axi_awburst(m_axi_awburst[2*i+:2]),
    .m_axi_awprot(),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awvalid(m_axi_awvalid[i]),
    .m_axi_awready(m_axi_awready[i]),

    .m_axi_wdata(m_axi_wdata[AXI_DATA_WIDTH*i+:AXI_DATA_WIDTH]),
    .m_axi_wstrb(m_axi_wstrb[(AXI_DATA_WIDTH/8)*i+:(AXI_DATA_WIDTH/8)]),
    .m_axi_wready(m_axi_wready[i]),
    .m_axi_wvalid(m_axi_wvalid[i]),
    .m_axi_wlast(m_axi_wlast[i]),

    .m_axi_bvalid(m_axi_bvalid[i]),
    .m_axi_bresp(m_axi_bresp[2*i+:2]),
    .m_axi_bready(m_axi_bready[i]),

    .m_axi_arready(),
    .m_axi_arvalid(),
    .m_axi_araddr(),
    .m_axi_arlen(),
    .m_axi_arsize(),
    .m_axi_arburst(),
    .m_axi_arprot(),
    .m_axi_arcache(),

    .m_axi_rdata(),
    .m_axi_rready(),
    .m_axi_rvalid(),
    .m_axi_rlast(),
    .m_axi_rresp(),

    .s_axis_aclk(s_axis_aclk),
    .s_axis_ready(s_axis_ready_loc[i]),
    .s_axis_valid(s_axis_valid),
    .s_axis_data(s_axis_data[SRC_DATA_WIDTH_PER_M*i+:SRC_DATA_WIDTH_PER_M]),
    .s_axis_user(s_axis_user),
    .s_axis_last(s_axis_last),
    .s_axis_xfer_req(),

    .m_axis_aclk(1'b0),
    .m_axis_ready(1'b1),
    .m_axis_valid(),
    .m_axis_data(),
    .m_axis_last(),
    .m_axis_xfer_req(),

    .fifo_wr_clk(1'b0),
    .fifo_wr_en(1'b0),
    .fifo_wr_din('b0),
    .fifo_wr_overflow(),
    .fifo_wr_sync(),
    .fifo_wr_xfer_req(),

    .fifo_rd_clk(1'b0),
    .fifo_rd_en(1'b0),
    .fifo_rd_valid(),
    .fifo_rd_dout(),
    .fifo_rd_underflow(),
    .fifo_rd_xfer_req(),

    // DBG
    .dbg_dest_request_id(),
    .dbg_dest_address_id(),
    .dbg_dest_data_id(),
    .dbg_dest_response_id(),
    .dbg_src_request_id(),
    .dbg_src_address_id(),
    .dbg_src_data_id(),
    .dbg_src_response_id(),
    .dbg_status(),

    .dest_diag_level_bursts()
  );

  always @(posedge up_clk) begin
    if (up_dst_request_eot) begin
      up_dst_eot_pending[i] <= 1'b0;
    end else if (up_dst_request_eot_loc[i]) begin
      up_dst_eot_pending[i] <= 1'b1;
    end
  end

  // AXI3 to MAXIS
  axi_dmac_transfer #(
    .DMA_DATA_WIDTH_SRC(AXI_DATA_WIDTH),
    .DMA_DATA_WIDTH_DEST(DST_DATA_WIDTH_PER_M),
    .DMA_LENGTH_WIDTH(LENGTH_WIDTH),
    .DMA_LENGTH_ALIGN(DST_BYTES_PER_BEAT_WIDTH),
    .BYTES_PER_BEAT_WIDTH_DEST(DST_BYTES_PER_BEAT_WIDTH),
    .BYTES_PER_BEAT_WIDTH_SRC(AXI_BYTES_PER_BEAT_WIDTH),
    .BYTES_PER_BURST_WIDTH(BYTES_PER_BURST_WIDTH),
    .DMA_TYPE_DEST(DMA_TYPE_AXI_STREAM),
    .DMA_TYPE_SRC(DMA_TYPE_AXI_MM),
    .DMA_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .DMA_2D_TRANSFER(1'b0),
    .ASYNC_CLK_REQ_SRC(1),
    .ASYNC_CLK_SRC_DEST(1),
    .ASYNC_CLK_DEST_REQ(ASYNC_CLK_MAXIS_UP),
    .AXI_SLICE_DEST(1),
    .AXI_SLICE_SRC(1),
    .MAX_BYTES_PER_BURST(MAX_BYTES_PER_BURST),
    .FIFO_SIZE(FIFO_SIZE),
    .ID_WIDTH(AXI_ID_WIDTH),
    .AXI_LENGTH_WIDTH_SRC(8),
    .AXI_LENGTH_WIDTH_DEST(8),
    .ENABLE_DIAGNOSTICS_IF(0),
    .ALLOW_ASYM_MEM(1)
  ) i_dst_transfer (
    .ctrl_clk(up_clk),
    .ctrl_resetn(~up_reset),

     // Control interface
    .ctrl_enable(up_dst_request_enable),
    .ctrl_pause(1'b0),

    .req_valid(up_dst_request_valid),
    .req_ready(up_dst_request_ready_loc[i]),
    .req_dest_address(0),
    .req_src_address(ADDR_OFFSET[AXI_ADDR_WIDTH-1:AXI_BYTES_PER_BEAT_WIDTH]),
    .req_x_length(up_dst_request_length),
    .req_y_length(0),
    .req_dest_stride(0),
    .req_src_stride(0),
    .req_sync_transfer_start(1'b0),
    .req_last(1'b1),

    .req_eot(up_dst_request_eot_loc[i]),
    .req_measured_burst_length(),
    .req_response_partial(),
    .req_response_valid(),
    .req_response_ready(1'b1),

    .m_dest_axi_aclk(1'b0),
    .m_dest_axi_aresetn(1'b0),
    .m_src_axi_aclk(m_axi_aclk),
    .m_src_axi_aresetn(m_axi_aresetn),

    .m_axi_awaddr(),
    .m_axi_awlen(),
    .m_axi_awsize(),
    .m_axi_awburst(),
    .m_axi_awprot(),
    .m_axi_awcache(),
    .m_axi_awvalid(),
    .m_axi_awready(1'b1),

    .m_axi_wdata(),
    .m_axi_wstrb(),
    .m_axi_wready(1'b1),
    .m_axi_wvalid(),
    .m_axi_wlast(),

    .m_axi_bvalid(1'b0),
    .m_axi_bresp(),
    .m_axi_bready(),

    .m_axi_arready(m_axi_arready[i]),
    .m_axi_arvalid(m_axi_arvalid[i]),
    .m_axi_araddr(m_axi_araddr[AXI_ADDR_WIDTH*i+:AXI_ADDR_WIDTH]),
    .m_axi_arlen(m_axi_arlen[4*i+:4]),
    .m_axi_arsize(m_axi_arsize[3*i+:3]),
    .m_axi_arburst(m_axi_arburst[2*i+:2]),
    .m_axi_arprot(),
    .m_axi_arcache(),

    .m_axi_rdata(m_axi_rdata[AXI_DATA_WIDTH*i+:AXI_DATA_WIDTH]),
    .m_axi_rready(m_axi_rready[i]),
    .m_axi_rvalid(m_axi_rvalid[i]),
    .m_axi_rlast(m_axi_rlast[i]),
    .m_axi_rresp(m_axi_rresp[2*i+:2]),

    .s_axis_aclk(1'b0),
    .s_axis_ready(),
    .s_axis_valid(1'b0),
    .s_axis_data(),
    .s_axis_user(),
    .s_axis_last(),
    .s_axis_xfer_req(),

    .m_axis_aclk(m_axis_aclk),
    .m_axis_ready(m_axis_ready & m_axis_valid),
    .m_axis_valid(m_axis_valid_loc[i]),
    .m_axis_data(m_axis_data[DST_DATA_WIDTH_PER_M*i+:DST_DATA_WIDTH_PER_M]),
    .m_axis_last(m_axis_last_loc[i]),
    .m_axis_xfer_req(),

    .fifo_wr_clk(1'b0),
    .fifo_wr_en(1'b0),
    .fifo_wr_din('b0),
    .fifo_wr_overflow(),
    .fifo_wr_sync(),
    .fifo_wr_xfer_req(),

    .fifo_rd_clk(1'b0),
    .fifo_rd_en(1'b0),
    .fifo_rd_valid(),
    .fifo_rd_dout(),
    .fifo_rd_underflow(),
    .fifo_rd_xfer_req(),

    // DBG
    .dbg_dest_request_id(),
    .dbg_dest_address_id(),
    .dbg_dest_data_id(),
    .dbg_dest_response_id(),
    .dbg_src_request_id(),
    .dbg_src_address_id(),
    .dbg_src_data_id(),
    .dbg_src_response_id(),
    .dbg_status(),

    .dest_diag_level_bursts()
  );

end
endgenerate

endmodule


