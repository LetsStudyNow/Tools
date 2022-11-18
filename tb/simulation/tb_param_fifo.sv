module tb_param_fifo ();

// ==== DUT ====

	localparam int WIDTH_DATA = 8 ;
	localparam int NUMWORDS   = 16;
	localparam bit REG_OUT    = 0 ;

	logic clk;
	logic rst;
	logic wr_en;
	logic [WIDTH_DATA-1:0] wr_data;
	logic rd_en;
	logic [WIDTH_DATA-1:0] rd_data;
	logic full;
	logic empty;
	logic [$clog2(NUMWORDS+1)-1:0] usedw;

	param_fifo #(.WIDTH_DATA(WIDTH_DATA), .NUMWORDS(NUMWORDS), .REG_OUT(REG_OUT)) i_param_fifo (
		.clk    (clk    ),
		.rst    (rst    ),
		.wr_en  (wr_en  ),
		.wr_data(wr_data),
		.rd_en  (rd_en  ),
		.rd_data(rd_data),
		.full   (full   ),
		.empty  (empty  ),
		.usedw  (usedw  )
	);


// ==== ENV ====

	localparam TB_PHASES = 5;
	localparam TB_TICKS_PER_PHASE = 5000;

	enum int {
		ST_HW_HR,
		ST_RW_RR,
		ST_FW_RR,
		ST_RW_FR,
		ST_FW_FR
	} states; 	// states for visual representation of tb phases

	int error_cnt [TB_PHASES];

	logic [WIDTH_DATA-1:0] data_q [$];

	int wr_proc  , rd_proc  ,
		wr_chance, rd_chance;

	initial
		begin: clk_gen
			clk = '0;
			forever #10 clk = ~clk;
		end

	initial
		begin: wr_gen
			forever
				begin
					@ (posedge clk);
						begin
							wr_proc <= $urandom_range(0, 99);
							if (rst)
								wr_en <= '0;
							else if (wr_proc < wr_chance && !full)
								wr_en <= '1;
							else
								wr_en <= '0;
						end
				end
		end

	initial
		begin: rd_gen
			forever
				begin
					@ (posedge clk);
						begin
							rd_proc <= $urandom_range(0, 99);
							if (rst)
								rd_en <= '0;
							else if (rd_proc < rd_chance && !empty)
								rd_en <= '1;
							else
								rd_en <= '0;
						end
				end
		end

	initial
		begin: data_gen
			forever
				begin
					@ (posedge clk);
						begin
							wr_data <= $random();
						end
				end
		end

	task automatic wr_q (input int prob, ref bit break_point);
		wr_chance = prob;
		forever
			begin
				@(posedge clk);
					begin
						if (rst)
							data_q.delete();
						else if (wr_en && !full)
							data_q.push_back(wr_data);

						if (break_point)
							break;
					end
			end
	endtask

	task automatic rd_q (input int prob, ref bit break_point, output int err_cnt);
		logic [REG_OUT:0][WIDTH_DATA-1:0] data_written;
		logic [REG_OUT:0]                 rd_valid;
		rd_chance = prob;
		err_cnt = '0;
		data_written = '0;
		rd_valid = '0;
		forever
			begin
				@(posedge clk);
					begin
						rd_valid[0] = rd_en && !empty && !rst;

						if (rd_en && !empty && !rst)
							data_written[0] = data_q.pop_front();
								
						data_written[REG_OUT] = #1 data_written[0];
						rd_valid    [REG_OUT] = #1 rd_valid    [0];

						if (rd_valid[REG_OUT])
							begin assert (data_written[REG_OUT] == rd_data) else begin err_cnt++; $stop(); end end

						if (break_point)
							break;
					end
			end
	endtask

	task automatic verification (input int wr_prob, input int rd_prob, input int ticks_proc, output int err_cnt);
		bit break_point = '0;

		if (wr_prob < 0 || wr_prob > 100)
			begin $error("Invalid wr_prob, the value should be between 0 and 100, currrent value: %d", wr_prob); $stop(); end
			
		if (rd_prob < 0 || rd_prob > 100)
			begin $error("Invalid rd_prob, the value should be between 0 and 100, currrent value: %d", rd_prob); $stop(); end	

		fork
			begin: rst_phase
				rst = 1'b1;
				# 5000 rst = 1'b0;
			end

			wr_q(wr_prob, break_point);

			rd_q(rd_prob, break_point, err_cnt);

			begin: test_stop
				repeat (ticks_proc) @(posedge clk);
				break_point = '1;
			end
		join
	endtask

	task automatic score_check (input int phase_num, input int err_cnt);
		if (err_cnt != 0)
			$error("Phase %1d failed, total errors: %1d.", phase_num+1, err_cnt);
		else
			$display("Phase %1d succesfully passed.", phase_num+1);
	endtask

	initial
		begin
			// ====

				$display("==== Phase 1 - half write / half read ====");
	
				states = ST_HW_HR;
	
				verification(50, 50, TB_TICKS_PER_PHASE, error_cnt[0]);
			
			// ====

				$display("==== Phase 2 - random write / random read ====");
	
				states = ST_RW_RR;
	
				verification($urandom_range(0,100), $urandom_range(0,100), TB_TICKS_PER_PHASE, error_cnt[1]);

			// ====

				$display("==== Phase 3 - full write / random read ====");
	
				states = ST_FW_RR;
	
				verification(100, $urandom_range(0,100), TB_TICKS_PER_PHASE, error_cnt[2]);

			// ====

				$display("==== Phase 4 - random write / full read ====");
	
				states = ST_RW_FR;
	
				verification($urandom_range(0,100), 100, TB_TICKS_PER_PHASE, error_cnt[3]);

			// ====

				$display("==== Phase 5 - full write / full read ====");

				states = ST_FW_FR;

				verification(100, 100, TB_TICKS_PER_PHASE, error_cnt[4]);

			// ====

				$display("Phases completed, checking score:");
	
				foreach (error_cnt[i])
					score_check(i, error_cnt[i]);
	
				$stop();
		end	

endmodule
