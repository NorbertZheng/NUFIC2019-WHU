module BlueToothInitializer #(
	parameter		// granularity
					REQUEST_FIFO_DATA_WIDTH				=	8,		// the bit width of data we stored in the FIFO
					REQUEST_FIFO_DATA_DEPTH_INDEX		=	5,		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
					RESPONSE_FIFO_DATA_WIDTH			=	8,		// the bit width of data we stored in the FIFO
					RESPONSE_FIFO_DATA_DEPTH_INDEX		=	5		// the index_width of data unit(reg [DATA_WIDTH - 1:0])
) (
	input												clk									,
	input												rst_n								,

	output	reg											BlueToothInitializer_init_flag		,	// complete initialization, and back to Normal mode

	// BlueTooth mode set signals
	output	reg											BlueToothInitializer_Key								,
	output	reg											BlueToothInitializer_Vcc								,
	output												BlueToothInitializer_Gnd								,

	// BlueTooth request FIFO signals
	output	reg	[REQUEST_FIFO_DATA_WIDTH - 1:0]			BlueToothInitializer_BlueTooth_request_FIFO_data_i		,
	output	reg											BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld	,
	input												BlueToothInitializer_BlueTooth_request_FIFO_data_i_rdy	,
	// for debug
	input												BlueToothInitializer_BlueTooth_request_FIFO_full		,
	input												BlueToothInitializer_BlueTooth_request_FIFO_empty		,
	input		[REQUEST_FIFO_DATA_DEPTH_INDEX - 1:0]	BlueToothInitializer_BlueTooth_request_FIFO_surplus		,

	// BlueTooth response FIFO signals
	output	reg											BlueToothInitializer_BlueTooth_response_FIFO_r_en		,
	input		[RESPONSE_FIFO_DATA_WIDTH - 1:0]		BlueToothInitializer_BlueTooth_response_FIFO_data_o		,
	input												BlueToothInitializer_BlueTooth_response_FIFO_data_o_vld	,
	// for debug
	input												BlueToothInitializer_BlueTooth_response_FIFO_full		,
	input												BlueToothInitializer_BlueTooth_response_FIFO_empty		,
	input		[RESPONSE_FIFO_DATA_DEPTH_INDEX - 1:0]	BlueToothInitializer_BlueTooth_response_FIFO_surplus	
);

	localparam		BlueToothInitializer_IDLE				=	2'b00,		// idle
					BlueToothInitializer_PreAT				=	2'b01,		// before AT mode, charge BlueTooth
					BlueToothInitializer_AT					=	2'b10,		// enter AT mode, (Vcc ->1, Key -> 0 then Key -> 1), send cmd & check response
					BlueToothInitializer_BakNor				=	2'b11,		// set Vcc -> 0, then Vcc -> 1, Key -> 0, Normal
					BlueToothInitializer_cmd_ATCMODE		=	2'b00,		// AT+CMODE=1 (len = 12)
					BlueToothInitializer_cmd_ATCMODE_len	=	6'b001100,	
					BlueToothInitializer_cmd_ATPSWD			=	2'b01,		// AT+PSWD=1234 (len = 14)
					BlueToothInitializer_cmd_ATPSWD_len		=	6'b001110,
					BlueToothInitializer_cmd_ATUART			=	2'b10,		// AT+UART=9600,0,0 (len = 18)
					BlueToothInitializer_cmd_ATUART_len		=	6'b010010,
					BlueToothInitializer_cmd_ATROLE			=	2'b11,		// AT+ROLE=1 (len = 11)
					BlueToothInitializer_cmd_ATROLE_len		=	6'b001011;	

	reg BlueToothInitializer_rec_flag;										// is receiving response
	reg [1:0] BlueToothInitializer_state;
	reg [5:0] BlueToothInitializer_cnt;
	reg [1:0] BlueToothInitializer_cmd_num;
	reg [31:0] BlueToothInitializer_res_buffer;
	reg [143:0] BlueToothInitializer_cmd_buffer;
	// Initial Commands
	reg [143:0] BlueToothInitializer_cmd_ATCMODE_buffer;
	reg [143:0] BlueToothInitializer_cmd_ATPSWD_buffer;
	reg [143:0] BlueToothInitializer_cmd_ATUART_buffer;
	reg [143:0] BlueToothInitializer_cmd_ATROLE_buffer;
	// Expecting Response
	reg [31:0] BlueToothInitializer_exp_res_buffer;
	always@ (posedge clk)
		begin
		if (!rst_n)
			begin
			// state
			BlueToothInitializer_state <= BlueToothInitializer_IDLE;
			// inner signals
			BlueToothInitializer_cnt <= 6'b0;
			BlueToothInitializer_cmd_num <= BlueToothInitializer_cmd_ATCMODE;
			BlueToothInitializer_res_buffer <= 32'b0;
			BlueToothInitializer_cmd_buffer <= 144'b0;
			BlueToothInitializer_cmd_ATCMODE_buffer <=	144'h41_54_2b_43_4d_4f_44_45_3d_31_0d_0a_00_00_00_00_00_00;
			BlueToothInitializer_cmd_ATPSWD_buffer <=	144'h41_54_2b_50_53_57_44_3d_31_32_33_34_00_00_00_00_00_00;
			BlueToothInitializer_cmd_ATUART_buffer <=	144'h41_54_2b_55_41_52_54_3d_39_36_30_30_2c_30_2c_30_0d_0a;
			BlueToothInitializer_cmd_ATROLE_buffer <=	144'h41_54_2b_52_4f_4c_45_3d_31_0d_0a_00_00_00_00_00_00_00;
			BlueToothInitializer_exp_res_buffer <= 32'h4f_4b_0d_0a;
			BlueToothInitializer_rec_flag <= 1'b0;
			// output
			BlueToothInitializer_init_flag <= 1'b0;
			BlueToothInitializer_Key <= 1'b0;
			BlueToothInitializer_Vcc <= 1'b1;
			BlueToothInitializer_BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
			BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b0;
			BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
			end
		else
			begin
			case (BlueToothInitializer_state)
				BlueToothInitializer_IDLE:
					begin
					// state
					BlueToothInitializer_state <= BlueToothInitializer_PreAT;
					// inner signals
					BlueToothInitializer_cnt <= 6'b0;
					BlueToothInitializer_cmd_num <= BlueToothInitializer_cmd_ATCMODE;
					BlueToothInitializer_res_buffer <= 32'b0;
					BlueToothInitializer_cmd_buffer <= 144'b0;
					BlueToothInitializer_cmd_ATCMODE_buffer <=	144'h41_54_2b_43_4d_4f_44_45_3d_31_0d_0a_00_00_00_00_00_00;
					BlueToothInitializer_cmd_ATPSWD_buffer <=	144'h41_54_2b_50_53_57_44_3d_31_32_33_34_00_00_00_00_00_00;
					BlueToothInitializer_cmd_ATUART_buffer <=	144'h41_54_2b_55_41_52_54_3d_39_36_30_30_2c_30_2c_30_0d_0a;
					BlueToothInitializer_cmd_ATROLE_buffer <=	144'h41_54_2b_52_4f_4c_45_3d_31_0d_0a_00_00_00_00_00_00_00;
					BlueToothInitializer_exp_res_buffer <= 32'h4f_4b_0d_0a;
					// output
					BlueToothInitializer_init_flag <= 1'b0;
					BlueToothInitializer_Key <= 1'b0;
					BlueToothInitializer_Vcc <= 1'b1;
					BlueToothInitializer_BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
					BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b0;
					BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
					end
				BlueToothInitializer_PreAT:
					begin
					// inner signals
					BlueToothInitializer_cnt <= BlueToothInitializer_cnt + 1'b1;
					if (BlueToothInitializer_cnt == 6'b11_1111)
						begin
						// state
						BlueToothInitializer_state <= BlueToothInitializer_AT;
						// inner signals
						BlueToothInitializer_cnt <= 6'b0;
						BlueToothInitializer_rec_flag <= 1'b0;
						BlueToothInitializer_cmd_buffer <= BlueToothInitializer_cmd_ATCMODE_buffer;		// prepare ahead 1 period
						// output
						BlueToothInitializer_init_flag <= 1'b0;
						BlueToothInitializer_Key <= 1'b1;
						BlueToothInitializer_BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
						BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b0;
						BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
						end
					end
				BlueToothInitializer_AT:
					begin
					case (BlueToothInitializer_cmd_num)
						BlueToothInitializer_cmd_ATCMODE:
							begin
							if (BlueToothInitializer_rec_flag)								// is receiving response
								begin
								if (!BlueToothInitializer_BlueTooth_response_FIFO_empty)	// have response
									begin
									BlueToothInitializer_cnt <= BlueToothInitializer_cnt + 1'b1;
									// generate 4 period r_en
									if (BlueToothInitializer_cnt < 6'b000100)
										begin
										BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b1;
										end
									else
										begin
										BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
										end
									// when data is valid, read it into buffer
									if (BlueToothInitializer_BlueTooth_response_FIFO_data_o_vld)
										begin
										BlueToothInitializer_res_buffer <= {BlueToothInitializer_res_buffer[23:0], BlueToothInitializer_BlueTooth_response_FIFO_data_o};
										end
									// when all is ready, check it
									if (BlueToothInitializer_cnt > 6'b000101)
										begin
										if (BlueToothInitializer_res_buffer == BlueToothInitializer_exp_res_buffer)
											begin
											// BlueToothInitializer_cmd_num
											BlueToothInitializer_cmd_num <= BlueToothInitializer_cmd_ATPSWD;
											// inner signals
											BlueToothInitializer_cnt <= 6'b0;
											BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
											BlueToothInitializer_res_buffer <= 32'b0;
											BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
											BlueToothInitializer_cmd_buffer <= BlueToothInitializer_cmd_ATPSWD_buffer;		// prepare ahead 1 period
											end
										else														// resend cmd
											begin
											// inner signals
											BlueToothInitializer_cnt <= 6'b0;
											BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
											BlueToothInitializer_res_buffer <= 32'b0;
											BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
											BlueToothInitializer_cmd_buffer <= BlueToothInitializer_cmd_ATCMODE_buffer;		// prepare ahead 1 period
											end
										end
									end
								else
									begin
									// do nothing, just wait
									end
								end
							else															// is sending cmd
								begin
								if (BlueToothInitializer_BlueTooth_request_FIFO_surplus >= BlueToothInitializer_cmd_ATCMODE_len)
									begin
									BlueToothInitializer_cnt <= BlueToothInitializer_cnt + 1'b1;
									if (BlueToothInitializer_cnt < BlueToothInitializer_cmd_ATCMODE_len)
										begin
										// inner signals
										BlueToothInitializer_cmd_buffer <= {BlueToothInitializer_cmd_buffer[135:0], 8'b0};
										// output
										BlueToothInitializer_BlueTooth_request_FIFO_data_i <= BlueToothInitializer_cmd_buffer[143:136];
										BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b1;
										end
									else
										begin
										// inner signals
										BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
										// output
										BlueToothInitializer_BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
										BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b0;
										end
									end
								else
									begin
									// do nothing, just wait
									end
								end
							end
						BlueToothInitializer_cmd_ATPSWD:
							begin
							if (BlueToothInitializer_rec_flag)								// is receiving response
								begin
								if (!BlueToothInitializer_BlueTooth_response_FIFO_empty)	// have response
									begin
									BlueToothInitializer_cnt <= BlueToothInitializer_cnt + 1'b1;
									// generate 4 period r_en
									if (BlueToothInitializer_cnt < 6'b000100)
										begin
										BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b1;
										end
									else
										begin
										BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
										end
									// when data is valid, read it into buffer
									if (BlueToothInitializer_BlueTooth_response_FIFO_data_o_vld)
										begin
										BlueToothInitializer_res_buffer <= {BlueToothInitializer_res_buffer[23:0], BlueToothInitializer_BlueTooth_response_FIFO_data_o};
										end
									// when all is ready, check it
									if (BlueToothInitializer_cnt > 6'b000101)
										begin
										if (BlueToothInitializer_res_buffer == BlueToothInitializer_exp_res_buffer)
											begin
											// BlueToothInitializer_cmd_num
											BlueToothInitializer_cmd_num <= BlueToothInitializer_cmd_ATUART;
											// inner signals
											BlueToothInitializer_cnt <= 6'b0;
											BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
											BlueToothInitializer_res_buffer <= 32'b0;
											BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
											BlueToothInitializer_cmd_buffer <= BlueToothInitializer_cmd_ATUART_buffer;		// prepare ahead 1 period
											end
										else														// resend cmd
											begin
											// inner signals
											BlueToothInitializer_cnt <= 6'b0;
											BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
											BlueToothInitializer_res_buffer <= 32'b0;
											BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
											BlueToothInitializer_cmd_buffer <= BlueToothInitializer_cmd_ATPSWD_buffer;		// prepare ahead 1 period
											end
										end
									end
								else
									begin
									// do nothing, just wait
									end
								end
							else															// is sending cmd
								begin
								if (BlueToothInitializer_BlueTooth_request_FIFO_surplus >= BlueToothInitializer_cmd_ATPSWD_len)
									begin
									BlueToothInitializer_cnt <= BlueToothInitializer_cnt + 1'b1;
									if (BlueToothInitializer_cnt < BlueToothInitializer_cmd_ATPSWD_len)
										begin
										// inner signals
										BlueToothInitializer_cmd_buffer <= {BlueToothInitializer_cmd_buffer[135:0], 8'b0};
										// output
										BlueToothInitializer_BlueTooth_request_FIFO_data_i <= BlueToothInitializer_cmd_buffer[143:136];
										BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b1;
										end
									else
										begin
										// inner signals
										BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
										// output
										BlueToothInitializer_BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
										BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b0;
										end
									end
								else
									begin
									// do nothing, just wait
									end
								end
							end
						BlueToothInitializer_cmd_ATUART:
							begin
							if (BlueToothInitializer_rec_flag)								// is receiving response
								begin
								if (!BlueToothInitializer_BlueTooth_response_FIFO_empty)	// have response
									begin
									BlueToothInitializer_cnt <= BlueToothInitializer_cnt + 1'b1;
									// generate 4 period r_en
									if (BlueToothInitializer_cnt < 6'b000100)
										begin
										BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b1;
										end
									else
										begin
										BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
										end
									// when data is valid, read it into buffer
									if (BlueToothInitializer_BlueTooth_response_FIFO_data_o_vld)
										begin
										BlueToothInitializer_res_buffer <= {BlueToothInitializer_res_buffer[23:0], BlueToothInitializer_BlueTooth_response_FIFO_data_o};
										end
									// when all is ready, check it
									if (BlueToothInitializer_cnt > 6'b000101)
										begin
										if (BlueToothInitializer_res_buffer == BlueToothInitializer_exp_res_buffer)
											begin
											// BlueToothInitializer_cmd_num
											BlueToothInitializer_cmd_num <= BlueToothInitializer_cmd_ATROLE;
											// inner signals
											BlueToothInitializer_cnt <= 6'b0;
											BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
											BlueToothInitializer_res_buffer <= 32'b0;
											BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
											BlueToothInitializer_cmd_buffer <= BlueToothInitializer_cmd_ATROLE_buffer;		// prepare ahead 1 period
											end
										else														// resend cmd
											begin
											// inner signals
											BlueToothInitializer_cnt <= 6'b0;
											BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
											BlueToothInitializer_res_buffer <= 32'b0;
											BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
											BlueToothInitializer_cmd_buffer <= BlueToothInitializer_cmd_ATUART_buffer;		// prepare ahead 1 period
											end
										end
									end
								else
									begin
									// do nothing, just wait
									end
								end
							else															// is sending cmd
								begin
								if (BlueToothInitializer_BlueTooth_request_FIFO_surplus >= BlueToothInitializer_cmd_ATUART_len)
									begin
									BlueToothInitializer_cnt <= BlueToothInitializer_cnt + 1'b1;
									if (BlueToothInitializer_cnt < BlueToothInitializer_cmd_ATUART_len)
										begin
										// inner signals
										BlueToothInitializer_cmd_buffer <= {BlueToothInitializer_cmd_buffer[135:0], 8'b0};
										// output
										BlueToothInitializer_BlueTooth_request_FIFO_data_i <= BlueToothInitializer_cmd_buffer[143:136];
										BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b1;
										end
									else
										begin
										// inner signals
										BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
										// output
										BlueToothInitializer_BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
										BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b0;
										end
									end
								else
									begin
									// do nothing, just wait
									end
								end
							end
						BlueToothInitializer_cmd_ATROLE:
							begin
							if (BlueToothInitializer_rec_flag)								// is receiving response
								begin
								if (!BlueToothInitializer_BlueTooth_response_FIFO_empty)	// have response
									begin
									BlueToothInitializer_cnt <= BlueToothInitializer_cnt + 1'b1;
									// generate 4 period r_en
									if (BlueToothInitializer_cnt < 6'b000100)
										begin
										BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b1;
										end
									else
										begin
										BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
										end
									// when data is valid, read it into buffer
									if (BlueToothInitializer_BlueTooth_response_FIFO_data_o_vld)
										begin
										BlueToothInitializer_res_buffer <= {BlueToothInitializer_res_buffer[23:0], BlueToothInitializer_BlueTooth_response_FIFO_data_o};
										end
									// when all is ready, check it
									if (BlueToothInitializer_cnt > 6'b000101)
										begin
										if (BlueToothInitializer_res_buffer == BlueToothInitializer_exp_res_buffer)
											begin
											// state
											BlueToothInitializer_state <= BlueToothInitializer_BakNor;						// back to normal
											// BlueToothInitializer_cmd_num
											BlueToothInitializer_cmd_num <= BlueToothInitializer_cmd_ATCMODE;
											// inner signals
											BlueToothInitializer_cnt <= 6'b0;
											BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
											BlueToothInitializer_res_buffer <= 32'b0;
											BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
											BlueToothInitializer_cmd_buffer <= BlueToothInitializer_cmd_ATCMODE_buffer;		// prepare ahead 1 period
											end
										else														// resend cmd
											begin
											// inner signals
											BlueToothInitializer_cnt <= 6'b0;
											BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
											BlueToothInitializer_res_buffer <= 32'b0;
											BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
											BlueToothInitializer_cmd_buffer <= BlueToothInitializer_cmd_ATROLE_buffer;		// prepare ahead 1 period
											end
										end
									end
								else
									begin
									// do nothing, just wait
									end
								end
							else															// is sending cmd
								begin
								if (BlueToothInitializer_BlueTooth_request_FIFO_surplus >= BlueToothInitializer_cmd_ATROLE_len)
									begin
									BlueToothInitializer_cnt <= BlueToothInitializer_cnt + 1'b1;
									if (BlueToothInitializer_cnt < BlueToothInitializer_cmd_ATROLE_len)
										begin
										// inner signals
										BlueToothInitializer_cmd_buffer <= {BlueToothInitializer_cmd_buffer[135:0], 8'b0};
										// output
										BlueToothInitializer_BlueTooth_request_FIFO_data_i <= BlueToothInitializer_cmd_buffer[143:136];
										BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b1;
										end
									else
										begin
										// inner signals
										BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
										// output
										BlueToothInitializer_BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
										BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b0;
										end
									end
								else
									begin
									// do nothing, just wait
									end
								end
							end
						default:
							begin
							// BlueToothInitializer_cmd_num
							BlueToothInitializer_cmd_num <= BlueToothInitializer_cmd_ATCMODE;
							// inner signals
							BlueToothInitializer_cnt <= 6'b0;
							BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
							BlueToothInitializer_res_buffer <= 32'b0;
							BlueToothInitializer_rec_flag <= ~BlueToothInitializer_rec_flag;
							BlueToothInitializer_cmd_buffer <= BlueToothInitializer_cmd_ATCMODE_buffer;		// prepare ahead 1 period
							end
					endcase
					end
				BlueToothInitializer_BakNor:
					begin
					// inner signals
					BlueToothInitializer_cnt <= BlueToothInitializer_cnt + 1'b1;
					if (BlueToothInitializer_cnt == 6'b11_1111 && BlueToothInitializer_init_flag == 1'b0)
						begin
						// output
						BlueToothInitializer_init_flag <= 1'b1;
						BlueToothInitializer_Vcc <= 1'b1;
						BlueToothInitializer_Key <= 1'b0;
						end
					else if (BlueToothInitializer_cnt < 6'b11_1111 && BlueToothInitializer_init_flag == 1'b0)
						begin
						// output
						BlueToothInitializer_init_flag <= 1'b0;
						BlueToothInitializer_Vcc <= 1'b0;
						BlueToothInitializer_Key <= 1'b0;
						end
					else
						begin
						// do nothing
						end
					end
				default:
					begin
					// state
					BlueToothInitializer_state <= BlueToothInitializer_IDLE;
					// inner signals
					BlueToothInitializer_cnt <= 6'b0;
					BlueToothInitializer_cmd_num <= BlueToothInitializer_cmd_ATCMODE;
					BlueToothInitializer_res_buffer <= 32'b0;
					BlueToothInitializer_cmd_buffer <= 144'b0;
					BlueToothInitializer_cmd_ATCMODE_buffer <=	144'h41_54_2b_43_4d_4f_44_45_3d_31_0d_0a_00_00_00_00_00_00;
					BlueToothInitializer_cmd_ATPSWD_buffer <=	144'h41_54_2b_50_53_57_44_3d_31_32_33_34_00_00_00_00_00_00;
					BlueToothInitializer_cmd_ATUART_buffer <=	144'h41_54_2b_55_41_52_54_3d_39_36_30_30_2c_30_2c_30_0d_0a;
					BlueToothInitializer_cmd_ATROLE_buffer <=	144'h41_54_2b_52_4f_4c_45_3d_31_0d_0a_00_00_00_00_00_00_00;
					BlueToothInitializer_exp_res_buffer <= 32'h4f_4b_0d_0a;
					BlueToothInitializer_rec_flag <= 1'b0;
					// output
					BlueToothInitializer_init_flag <= 1'b0;
					BlueToothInitializer_Key <= 1'b0;
					BlueToothInitializer_Vcc <= 1'b1;
					BlueToothInitializer_BlueTooth_request_FIFO_data_i <= {REQUEST_FIFO_DATA_WIDTH{1'b0}};
					BlueToothInitializer_BlueTooth_request_FIFO_data_i_vld <= 1'b0;
					BlueToothInitializer_BlueTooth_response_FIFO_r_en <= 1'b0;
					end
			endcase
			end
		end

	assign BlueToothInitializer_Gnd = 1'b0;

endmodule
