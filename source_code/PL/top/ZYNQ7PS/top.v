`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/11/07 12:50:10
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top #(
	parameter		AXIS_DATA_WIDTH		=	256		,
					AXIS_DATA_KEEP		=	32		,
					AXIS_DATA_DEPTH		=	400		
) (
	inout			[14:0]		DDR_addr				,
	inout			[2:0]		DDR_ba					,
	inout						DDR_cas_n				,
	inout						DDR_ck_n				,
	inout						DDR_ck_p				,
	inout						DDR_cke					,
	inout						DDR_cs_n				,
	inout			[3:0]		DDR_dm					,
	inout			[31:0]		DDR_dq					,
	inout			[3:0]		DDR_dqs_n				,
	inout			[3:0]		DDR_dqs_p				,
	inout						DDR_odt					,
	inout						DDR_ras_n				,
	inout						DDR_reset_n				,
	inout						DDR_we_n				,
	inout						FIXED_IO_ddr_vrn		,
	inout						FIXED_IO_ddr_vrp		,
	inout			[53:0]		FIXED_IO_mio			,
	inout						FIXED_IO_ps_clk			,
	inout						FIXED_IO_ps_porb		,
	inout						FIXED_IO_ps_srstb		
	// input			[255:0]		S_AXIS_0_tdata			,
	// input			[31:0]		S_AXIS_0_tkeep			,
	// input						S_AXIS_0_tlast			,
	// output						S_AXIS_0_tready			,
	// input						S_AXIS_0_tvalid			,
	// output						clk_50M_0				,
	// output						locked_0				
);

	// system_wrapper signals
	// clock wizid signals
	wire clk_50M_0, locked_0;
	// S_AXIS signals
	wire S_AXIS_0_tlast, S_AXIS_0_tready, S_AXIS_0_tvalid;
	wire [31:0] S_AXIS_0_tkeep;
	wire [255:0] S_AXIS_0_tdata;

	// AXIS_data_generator signals
	wire AXIS_data_generator_clk, AXIS_data_generator_rst_n;
	wire [AXIS_DATA_WIDTH - 1:0] AXIS_data_generator_AXIS_tdata;
	wire [AXIS_DATA_KEEP - 1:0] AXIS_data_generator_AXIS_tkeep;
	wire AXIS_data_generator_AXIS_tlast, AXIS_data_generator_AXIS_tready, AXIS_data_generator_AXIS_tvalid;
	(* mark_debug = "true" *)wire [AXIS_DATA_WIDTH - 1:0] debug_AXIS_data_generator_AXIS_tdata = AXIS_data_generator_AXIS_tdata;
	(* mark_debug = "true" *)wire [AXIS_DATA_KEEP - 1:0] debug_AXIS_data_generator_AXIS_tkeep = AXIS_data_generator_AXIS_tkeep;
	(* mark_debug = "true" *)wire debug_AXIS_data_generator_AXIS_tlast = AXIS_data_generator_AXIS_tlast;
	(* mark_debug = "true" *)wire debug_AXIS_data_generator_AXIS_tready = AXIS_data_generator_AXIS_tready;
	(* mark_debug = "true" *)wire debug_AXIS_data_generator_AXIS_tvalid = AXIS_data_generator_AXIS_tvalid;

	// AXIS_data_generator
	AXIS_data_generator #(
		.AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
		.AXIS_DATA_KEEP(AXIS_DATA_KEEP),
		.AXIS_DATA_DEPTH(AXIS_DATA_DEPTH)
	) m_AXIS_data_generator (
		.clk									(AXIS_data_generator_clk		),
		.rst_n									(AXIS_data_generator_rst_n		),

		.AXIS_data_generator_AXIS_tdata			(AXIS_data_generator_AXIS_tdata	),
		.AXIS_data_generator_AXIS_tkeep			(AXIS_data_generator_AXIS_tkeep	),
		.AXIS_data_generator_AXIS_tlast			(AXIS_data_generator_AXIS_tlast	),
		.AXIS_data_generator_AXIS_tready		(AXIS_data_generator_AXIS_tready),
		.AXIS_data_generator_AXIS_tvalid		(AXIS_data_generator_AXIS_tvalid)
	);

	// system_wrapper
	system_wrapper m_system_wrapper(.DDR_addr(DDR_addr),
		.DDR_ba(DDR_ba),		
		.DDR_cas_n(DDR_cas_n),
		.DDR_ck_n(DDR_ck_n),
		.DDR_ck_p(DDR_ck_p),
		.DDR_cke(DDR_cke),
		.DDR_cs_n(DDR_cs_n),
		.DDR_dm(DDR_dm),
		.DDR_dq(DDR_dq),
		.DDR_dqs_n(DDR_dqs_n),
		.DDR_dqs_p(DDR_dqs_p),
		.DDR_odt(DDR_odt),
		.DDR_ras_n(DDR_ras_n),
		.DDR_reset_n(DDR_reset_n),
		.DDR_we_n(DDR_we_n),
		.FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
		.FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
		.FIXED_IO_mio(FIXED_IO_mio),
		.FIXED_IO_ps_clk(FIXED_IO_ps_clk),
		.FIXED_IO_ps_porb(FIXED_IO_ps_porb),
		.FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
		.S_AXIS_0_tdata(S_AXIS_0_tdata),
		.S_AXIS_0_tkeep(S_AXIS_0_tkeep),
		.S_AXIS_0_tlast(S_AXIS_0_tlast),
		.S_AXIS_0_tready(S_AXIS_0_tready),
		.S_AXIS_0_tvalid(S_AXIS_0_tvalid),
		.clk_50M_0(clk_50M_0),
		.locked_0(locked_0)
	);
	assign AXIS_data_generator_clk = clk_50M_0;
	assign AXIS_data_generator_rst_n = locked_0;
	assign AXIS_data_generator_AXIS_tready = S_AXIS_0_tready;
	assign S_AXIS_0_tdata = AXIS_data_generator_AXIS_tdata;
	assign S_AXIS_0_tkeep = AXIS_data_generator_AXIS_tkeep;
	assign S_AXIS_0_tlast = AXIS_data_generator_AXIS_tlast;
	assign S_AXIS_0_tvalid = AXIS_data_generator_AXIS_tvalid;

endmodule
