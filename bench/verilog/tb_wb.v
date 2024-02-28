////////////////////////////////////////////////////////////////////////////////
//
// Filename:	bench/verilog/tb_wb.v
// {{{
// Project:	SDIO SD-Card controller
//
// Purpose:	
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2016-2024, Gisselquist Technology, LLC
// {{{
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
`default_nettype none
`timescale 1ns / 1ps
// }}}
module	tb_wb;
	// Local declarations
	// {{{
	parameter	[1:0]	OPT_SERDES = 1'b1;
	parameter	[1:0]	OPT_DDR = 1'b1;
	parameter	[0:0]	OPT_DMA = 1'b0;
	parameter	[0:0]	OPT_VCD = 1'b0;
	parameter		DW = 64;
	localparam		BFM_DW=32;
	localparam		VCD_FILE = "trace.vcd";
	parameter		LGMEMSZ = 16;	// 64kB
	localparam		ADDRESS_WIDTH = LGMEMSZ + 1;

	localparam	WBLSB = $clog2(DW/8);
	localparam	AW = ADDRESS_WIDTH-WBLSB,
			BFM_AW = ADDRESS_WIDTH-$clog2(BFM_DW/8);

	parameter [ADDRESS_WIDTH-1:0]
			MEM_ADDR  = { 1'b1,  {(AW-1){1'b0}}, {(WBLSB){1'b0}} },
			SDIO_ADDR = { 3'b001,{(AW-3){1'b0}}, {(WBLSB){1'b0}} },
			EMMC_ADDR = { 3'b010,{(AW-3){1'b0}}, {(WBLSB){1'b0}} };
	//
	parameter [ADDRESS_WIDTH-1:0]
			MEM_MASK  = { 1'b1,  {(AW-1){1'b0}}, {(WBLSB){1'b0}} },
			SDIO_MASK = { 3'b111,{(AW-3){1'b0}}, {(WBLSB){1'b0}} },
			EMMC_MASK = { 3'b111,{(AW-3){1'b0}}, {(WBLSB){1'b0}} };

	reg	[2:0]		ckcounter;
	wire			clk, hsclk;
	reg			reset;

	// BFM definitions
	// {{{
	wire			bfm_cyc, bfm_stb, bfm_we,
				bfm_stall, bfm_ack, bfm_err;
	wire	[BFM_AW-1:0]	bfm_addr;
	wire	[BFM_DW-1:0]	bfm_data, bfm_idata;
	wire	[BFM_DW/8-1:0]	bfm_sel;

	wire			bfmw_cyc, bfmw_stb, bfmw_we,
				bfmw_stall, bfmw_ack, bfmw_err;
	wire	[AW-1:0]	bfmw_addr;
	wire	[DW-1:0]	bfmw_data, bfmw_idata;
	wire	[DW/8-1:0]	bfmw_sel;
	// }}}

	wire			sdiow_cyc, sdiow_stb, sdiow_we,
				sdiow_stall, sdiow_ack, sdiow_err;
	wire	[AW-1:0]	sdiow_addr;
	wire	[DW-1:0]	sdiow_data, sdiow_idata;
	wire	[DW/8-1:0]	sdiow_sel;

	wire			sdio_dma_cyc, sdio_dma_stb, sdio_dma_we,
				sdio_dma_stall, sdio_dma_ack, sdio_dma_err;
	wire	[AW-1:0]	sdio_dma_addr;
	wire	[DW-1:0]	sdio_dma_data, sdio_dma_idata;
	wire	[DW/8-1:0]	sdio_dma_sel;

	wire			sdio_cyc, sdio_stb, sdio_we,
				sdio_stall, sdio_ack, sdio_err;
	wire	[BFM_AW-1:0]	sdio_addr;
	wire	[BFM_DW-1:0]	sdio_data, sdio_idata;
	wire	[BFM_DW/8-1:0]	sdio_sel;

	wire			emmcw_cyc, emmcw_stb, emmcw_we,
				emmcw_stall, emmcw_ack, emmcw_err;
	wire	[AW-1:0]	emmcw_addr;
	wire	[DW-1:0]	emmcw_data, emmcw_idata;
	wire	[DW/8-1:0]	emmcw_sel;

	wire			emmc_dma_cyc, emmc_dma_stb, emmc_dma_we,
				emmc_dma_stall, emmc_dma_ack, emmc_dma_err;
	wire	[AW-1:0]	emmc_dma_addr;
	wire	[DW-1:0]	emmc_dma_data, emmc_dma_idata;
	wire	[DW/8-1:0]	emmc_dma_sel;

	wire			emmc_cyc, emmc_stb, emmc_we,
				emmc_stall, emmc_ack, emmc_err;
	wire	[BFM_AW-1:0]	emmc_addr;
	wire	[BFM_DW-1:0]	emmc_data, emmc_idata;
	wire	[BFM_DW/8-1:0]	emmc_sel;

	// RAM WB declarations
	// {{{
	wire			mem_cyc, mem_stb, mem_we,
				mem_stall, mem_ack, mem_err;
	wire	[AW-1:0]	mem_addr;
	wire	[DW-1:0]	mem_data, mem_idata;
	wire	[DW/8-1:0]	mem_sel;
	// }}}

	wire			sd_cmd, sd_ck;
	wire	[3:0]		sd_dat;
	wire			emmc_cmd, emmc_ck, emmc_ds;
	wire	[7:0]		emmc_dat;
	wire			sdio_interrupt, emmc_interrupt;
	wire	[31:0]		sdio_debug, emmc_debug;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Clock/reset generation
	// {{{
	localparam	realtime CLK_PERIOD = 10.0;	// 100MHz

	initial	begin
		ckcounter = 0;
		forever
			#(CLK_PERIOD/8) ckcounter = ckcounter + 1;
	end

	assign	hsclk = ckcounter[0];
	assign	clk   = ckcounter[2];

	initial	reset <= 1;
	initial	begin
		@(posedge clk);
		@(posedge clk)
			reset <= 0;
	end

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-Lite / Wishbone bus functional model
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	wb_bfm #(
		.AW(BFM_AW), .DW(BFM_DW), .LGFIFO(4)
	) u_bfm (
		// {{{
		.i_clk(clk), .i_reset(reset),
		//
		.o_wb_cyc(bfm_cyc), .o_wb_stb(bfm_stb), .o_wb_we(bfm_we),
		.o_wb_addr(bfm_addr), .o_wb_data(bfm_data), .o_wb_sel(bfm_sel),
		.i_wb_stall(bfm_stall), .i_wb_ack(bfm_ack),
			.i_wb_data(bfm_idata), .i_wb_err(bfm_err)
		// }}}
	);

	// Now upsize to the full bus width
	wbupsz #(
		.ADDRESS_WIDTH(ADDRESS_WIDTH),
		.WIDE_DW(DW), .SMALL_DW(BFM_DW)
	) u_bfm_upsz (
		// {{{
		.i_clk(clk), .i_reset(reset),
		//
		.i_scyc(bfm_cyc), .i_sstb(bfm_stb), .i_swe(bfm_we),
		.i_saddr(bfm_addr), .i_sdata(bfm_data), .i_ssel(bfm_sel),
		.o_sstall(bfm_stall), .o_sack(bfm_ack), .o_sdata(bfm_idata),
			.o_serr(bfm_err),
		//
		.o_wcyc(bfmw_cyc), .o_wstb(bfmw_stb), .o_wwe(bfmw_we),
		.o_waddr(bfmw_addr), .o_wdata(bfmw_data), .o_wsel(bfmw_sel),
		.i_wstall(bfmw_stall), .i_wack(bfmw_ack), .i_wdata(bfmw_idata),
			.i_werr(bfmw_err)
		// }}}
	);

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Crossbar
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	wbxbar #(
		.NM(3), .NS(3),
		.AW(AW), .DW(DW),
		.SLAVE_ADDR({
			MEM_ADDR[AW+WBLSB-1:WBLSB],
			EMMC_ADDR[AW+WBLSB-1:WBLSB],
			SDIO_ADDR[AW+WBLSB-1:WBLSB]}),
		.SLAVE_MASK({
			MEM_MASK[AW+WBLSB-1:WBLSB],
			EMMC_MASK[AW+WBLSB-1:WBLSB],
			SDIO_MASK[AW+WBLSB-1:WBLSB]})
	) u_xbar (
		// {{{
		.i_clk(clk), .i_reset(reset),
		//
		.i_mcyc({   emmc_dma_cyc,   sdio_dma_cyc,   bfmw_cyc   }),
		.i_mstb({   emmc_dma_stb,   sdio_dma_stb,   bfmw_stb   }),
		.i_mwe({    emmc_dma_we,    sdio_dma_we,    bfmw_we    }),
		.i_maddr({  emmc_dma_addr,  sdio_dma_addr,  bfmw_addr  }),
		.i_mdata({  emmc_dma_data,  sdio_dma_data,  bfmw_data  }),
		.i_msel({   emmc_dma_sel,   sdio_dma_sel,   bfmw_sel   }),
		.o_mstall({ emmc_dma_stall, sdio_dma_stall, bfmw_stall }),
		.o_mack({   emmc_dma_ack,   sdio_dma_ack,   bfmw_ack   }),
		.o_mdata({  emmc_dma_idata, sdio_dma_idata, bfmw_idata }),
		.o_merr({   emmc_dma_err,   sdio_dma_err,   bfmw_err   }),
		//
		.o_scyc({   mem_cyc,   emmcw_cyc,   sdiow_cyc   }),
		.o_sstb({   mem_stb,   emmcw_stb,   sdiow_stb   }),
		.o_swe({    mem_we,    emmcw_we,    sdiow_we    }),
		.o_saddr({  mem_addr,  emmcw_addr,  sdiow_addr  }),
		.o_sdata({  mem_data,  emmcw_data,  sdiow_data  }),
		.o_ssel({   mem_sel,   emmcw_sel,   sdiow_sel   }),
		.i_sstall({ mem_stall, emmcw_stall, sdiow_stall }),
		.i_sack({   mem_ack,   emmcw_ack,   sdiow_ack   }),
		.i_sdata({  mem_idata, emmcw_idata, sdiow_idata }),
		.i_serr({   mem_err,   emmcw_err,   sdiow_err   })
		// }}}
	);

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// RAM model
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	memdev #(
		.LGMEMSZ(LGMEMSZ), .DW(DW)
	) u_mem (
		.i_clk(clk), .i_reset(reset),
		.i_wb_cyc(mem_cyc), .i_wb_stb(mem_stb), .i_wb_we(mem_we),
		.i_wb_addr(mem_addr[LGMEMSZ-$clog2(DW/8)-1:0]),
		.i_wb_data(mem_data), .i_wb_sel(mem_sel),
		.o_wb_stall(mem_stall), .o_wb_ack(mem_ack),
			.o_wb_data(mem_idata)
	);

	assign	mem_err = 1'b0;

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Unit under test
	// {{{

	// Downsize
	// {{{
	wbdown #(
		.ADDRESS_WIDTH(ADDRESS_WIDTH),
		.WIDE_DW(DW), .SMALL_DW(32)
	) u_sdio_downsz (
		// {{{
		.i_clk(clk), .i_reset(reset),
		//
		.i_wcyc(sdiow_cyc), .i_wstb(sdiow_stb), .i_wwe(sdiow_we), 
		.i_waddr(sdiow_addr), .i_wdata(sdiow_data), 
			.i_wsel(sdiow_sel), 
		.o_wstall(sdiow_stall),
		.o_wack(sdiow_ack), .o_wdata(sdiow_idata), 
			.o_werr(sdiow_err), 
		//
		.o_cyc(sdio_cyc), .o_stb(sdio_stb), .o_we(sdio_we), 
		.o_addr(sdio_addr), .o_data(sdio_data), 
			.o_sel(sdio_sel), 
		.i_stall(sdio_stall), .i_ack(sdio_ack), .i_data(sdio_idata), 
			.i_err(sdio_err)
		// }}}
	);

	wbdown #(
		.ADDRESS_WIDTH(ADDRESS_WIDTH),
		.WIDE_DW(DW), .SMALL_DW(32)
	) u_emmc_downsz (
		// {{{
		.i_clk(clk), .i_reset(reset),
		//
		.i_wcyc(emmcw_cyc), .i_wstb(emmcw_stb), .i_wwe(emmcw_we), 
		.i_waddr(emmcw_addr), .i_wdata(emmcw_data), 
			.i_wsel(emmcw_sel), 
		.o_wstall(emmcw_stall),
		.o_wack(emmcw_ack), .o_wdata(emmcw_idata), 
			.o_werr(emmcw_err), 
		//
		.o_cyc(emmc_cyc), .o_stb(emmc_stb), .o_we(emmc_we), 
		.o_addr(emmc_addr), .o_data(emmc_data), 
			.o_sel(emmc_sel), 
		.i_stall(emmc_stall), .i_ack(emmc_ack), .i_data(emmc_idata), 
			.i_err(emmc_err)
		// }}}
	);
	// }}}

	sdio_top #(
		// {{{
		.LGFIFO(12), .NUMIO(4),
		.ADDRESS_WIDTH(ADDRESS_WIDTH),
		.OPT_SERDES(OPT_SERDES), .OPT_DDR(OPT_DDR),
		.OPT_CARD_DETECT(0), .LGTIMEOUT(10),
		.OPT_DMA(OPT_DMA), .OPT_EMMC(1'b0)
		// }}}
	) u_sdio (
		// {{{
		.i_clk(clk), .i_reset(reset), .i_hsclk(hsclk),
		//
		// WB Control/data interface
		// {{{
		.i_wb_cyc(sdio_cyc),    .i_wb_stb(sdio_stb),  .i_wb_we(sdio_we),
		.i_wb_addr(sdio_addr[2:0]), .i_wb_data(sdio_data),
			.i_wb_sel(sdio_sel),
		.o_wb_stall(sdio_stall),.o_wb_ack(sdio_ack),.o_wb_data(sdio_idata),
		// }}}
		// DMA interface
		// {{{
		.o_dma_cyc(sdio_dma_cyc), .o_dma_stb(sdio_dma_stb),
			.o_dma_we(sdio_dma_we),
		.o_dma_addr(sdio_dma_addr),.o_dma_data(sdio_dma_data),
			.o_dma_sel(sdio_dma_sel),
		.i_dma_stall(sdio_dma_stall),
		.i_dma_ack(sdio_dma_ack), .i_dma_data(sdio_dma_idata),
		.i_dma_err(sdio_dma_err),
		// }}}
		//
		.o_ck(sd_ck), .i_ds(1'b0), .io_cmd(sd_cmd), .io_dat(sd_dat),
		.i_card_detect(1'b1), .o_int(sdio_interrupt),
		.o_debug(sdio_debug)
		// }}}
	);

	assign	sdio_err = 1'b0;	// Wishbone error return

	sdio_top #(
		// {{{
		.LGFIFO(12), .NUMIO(8),
		.ADDRESS_WIDTH(ADDRESS_WIDTH),
		.OPT_SERDES(OPT_SERDES), .OPT_DDR(OPT_DDR),
		.OPT_CARD_DETECT(0), .LGTIMEOUT(10),
		.OPT_DMA(OPT_DMA), .OPT_EMMC(1'b1)
		// }}}
	) u_emmc (
		// {{{
		.i_clk(clk), .i_reset(reset), .i_hsclk(hsclk),
		//
		// WB Control/data interface
		// {{{
		.i_wb_cyc(emmc_cyc),    .i_wb_stb(emmc_stb),  .i_wb_we(emmc_we),
		.i_wb_addr(emmc_addr[2:0]), .i_wb_data(emmc_data),
			.i_wb_sel(emmc_sel),
		.o_wb_stall(emmc_stall),.o_wb_ack(emmc_ack),.o_wb_data(emmc_idata),
		// }}}
		// DMA interface
		// {{{
		.o_dma_cyc(emmc_dma_cyc), .o_dma_stb(emmc_dma_stb),
			.o_dma_we(emmc_dma_we),
		.o_dma_addr(emmc_dma_addr),.o_dma_data(emmc_dma_data),
			.o_dma_sel(emmc_dma_sel),
		.i_dma_stall(emmc_dma_stall),
		.i_dma_ack(emmc_dma_ack), .i_dma_data(emmc_dma_idata),
		.i_dma_err(emmc_dma_err),
		// }}}
		//
		.o_ck(emmc_ck),
			.io_cmd(emmc_cmd), .io_dat(emmc_dat), .i_ds(emmc_ds),
		.i_card_detect(1'b1), .o_int(emmc_interrupt),
		.o_debug(emmc_debug)
		// }}}
	);

	assign	emmc_err = 1'b0;	// Wishbone error return

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// eMMC Device model
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	mdl_emmc #(
		.LGMEMSZ(20),
		.OPT_HIGH_CAPACITY(1'b1)
	) u_mcchip (
		.rst_n(!reset),
		.sd_clk(emmc_ck), .sd_cmd(emmc_cmd), .sd_dat(emmc_dat),
			.sd_ds(emmc_ds)
	);

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// SDIO Device model
	// {{{

	mdl_sdio #(
		.LGMEMSZ(16),
		.OPT_HIGH_CAPACITY(1'b1)
	) u_sdcard (
		// .rst_n(1'b1),
		.sd_clk(sd_ck), .sd_cmd(sd_cmd), .sd_dat(sd_dat)
	);

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// VCD generation
	// {{{

	initial if (OPT_VCD && VCD_FILE != 0)
	begin
		$dumpfile(VCD_FILE);
		$dumpvars(0, tb_wb);
	end

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Test script
	// {{{
	reg	error_flag;
`include	`SCRIPT

	initial begin
		error_flag = 1'b0;
		@(posedge clk);
		wait(!reset);
		@(posedge clk);
		testscript;

		if (error_flag)
		begin
			$display("TEST FAIL!");
		end else begin
			$display("Test pass");
		end

		$finish;
	end

	always @(posedge error_flag)
	if (!reset)
	begin
		$display("ERROR-FLAG DETECTED");
		repeat(200)
			@(posedge clk);
		$display("TEST-FAIL/ERROR FLAG");
		$finish;
	end
	// }}}
endmodule