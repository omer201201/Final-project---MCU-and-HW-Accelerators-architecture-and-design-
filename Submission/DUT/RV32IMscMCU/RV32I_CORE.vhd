--============================================================================
-- Copyright 2026 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Top Level Structural Model for Single-Cycle RISC-V Core
--============================================================================ 
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;
USE work.cond_compilation_package.all;
USE work.aux_package.all;
USE work.const_package.all;					-- for ALU_DIV / ALU_REM op-codes


ENTITY RV32I_CORE IS
	generic( 
			WORD_GRANULARITY 	: boolean 	:= G_WORD_GRANULARITY;
	    MODELSIM 					: integer 	:= G_MODELSIM;
			DATA_BUS_WIDTH 		: integer 	:= 32;
			ITCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			DTCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			PC_WIDTH 					: integer 	:= G_PC_WIDTH;
			MA_WIDTH 					: integer 	:= G_MA_WIDTH;
			DATA_WORDS_NUM 		: integer 	:= G_DATA_WORDSNUM;
			CLK_CNT_WIDTH 		: integer 	:= 16
	);
	PORT(	
		--Inputs
		rst_i		 					:IN	STD_LOGIC;
		clk_i							:IN	STD_LOGIC;
		
		--Outputs (used also for Signal-Tap auxiliary pins)
		pc_o							:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		instruction_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		RegWrite_ctrl_o		:OUT 	STD_LOGIC;
		MemWrite_ctrl_o		:OUT 	STD_LOGIC;
		Branch_ctrl_o			:OUT 	STD_LOGIC;
		
		read_data1_o 			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_o 			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		write_data_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		alu_res_o 				:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);															
		brTaken_o					:OUT 	STD_LOGIC; 
		
		dtcm_addr_o				:OUT 	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
		dtcm_data_wr_o		:OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		dtcm_data_rd_o		:OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		
		mclk_cnt_o				:OUT	STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);

		-- GPIO board I/O (P3, MMIO)
		SW_i							:IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
		PB_i							:IN	STD_LOGIC_VECTOR(2 DOWNTO 0);
		LEDR_o						:OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
		HEX0_o						:OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX1_o						:OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX2_o						:OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX3_o						:OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX4_o						:OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);
		HEX5_o						:OUT	STD_LOGIC_VECTOR(6 DOWNTO 0);

		-- Basic Timer (P4a)
		pwm_o						:OUT	STD_LOGIC;
		btifg_o						:OUT	STD_LOGIC;
		intr_o						:OUT	STD_LOGIC
	);		
END RV32I_CORE;
--============================================================================
ARCHITECTURE structure OF RV32I_CORE IS
	-- declare signals used to connect VHDL components
	SIGNAL pc_w 					: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_plus4_w 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL read_data1_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL read_data2_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL sign_extend_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL addr_gen_w 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL alu_res_w 			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL dtcm_data_rd_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	-- P3 MMIO bus
	SIGNAL mem_rdata_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL dtcm_we_w		: STD_LOGIC;
	SIGNAL dtcm_addr_w 		: STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL alu_src_w 			: STD_LOGIC;
	SIGNAL branch_w 			: STD_LOGIC;
	SIGNAL Jal_ctrl_w 		: STD_LOGIC;
	SIGNAL Jalr_ctrl_w 		: STD_LOGIC;
	SIGNAL reg_write_w 		: STD_LOGIC;
	SIGNAL reg_dst_w 			: STD_LOGIC;
	SIGNAL brTaken_w 			: STD_LOGIC;
	SIGNAL mem_write_w 		: STD_LOGIC;
	SIGNAL MemtoReg_w 		: STD_LOGIC;
	SIGNAL mem_read_w 		: STD_LOGIC;
	SIGNAL upper_im_w			: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL alu_op_w 			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL instruction_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL mclk_w 				: STD_LOGIC;
	SIGNAL mclk_cnt_q			: STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);
	-- divider accelerator integration
	SIGNAL div_instr_w		: STD_LOGIC;
	SIGNAL divena_w				: STD_LOGIC;
	SIGNAL divbusy_w			: STD_LOGIC;
	SIGNAL stall_w				: STD_LOGIC;
	SIGNAL quotient_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL residue_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL reg_write_gated_w	: STD_LOGIC;
	SIGNAL exe_result_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	-- P4b: CPU-side interrupt service (2-cycle FSM + datapath overrides)
	SIGNAL intr_w					: STD_LOGIC;										-- INTR from the controller (via bus_interface)
	SIGNAL inta_w					: STD_LOGIC;										-- INTA to the controller (SVC1)
	SIGNAL svc_active_w		: STD_LOGIC;
	SIGNAL capture_w			: STD_LOGIC;
	SIGNAL clr_gie_w			: STD_LOGIC;
	SIGNAL vec_load_w			: STD_LOGIC;
	SIGNAL set_pc_w				: STD_LOGIC;
	SIGNAL write_tp_w			: STD_LOGIC;
	SIGNAL can_take_w			: STD_LOGIC;
	SIGNAL gp_w						: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- x3 (GIE = gp_w(0))
	SIGNAL type_captured_q	: STD_LOGIC_VECTOR(7 DOWNTO 0);				-- latched TYPE (SVC1)
	SIGNAL return_pc_q		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);	-- latched return address (SVC1)
	SIGNAL intr_we_w			: STD_LOGIC;										-- RF write override enable
	SIGNAL intr_rd_w			: STD_LOGIC_VECTOR(4 DOWNTO 0);				-- RF write override destination
	SIGNAL intr_wdata_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);	-- RF write override data
	SIGNAL reti_w					: STD_LOGIC;										-- decode of reti = jalr x0,0(tp)
	SIGNAL pc_freeze_w			: STD_LOGIC;										-- SVC1 PC freeze
	SIGNAL ifetch_pc_hold_w	: STD_LOGIC;										-- stall OR SVC1 freeze -> IFETCH.pc_hold
	SIGNAL mem_write_gated_w	: STD_LOGIC;									-- MemWrite suppressed during service
	SIGNAL dtcm_addr_normal_w	: STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL vec_addr_w			: STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);	-- DTCM word addr = TYPE/4
	SIGNAL rst_w				: STD_LOGIC;										-- internal active-HIGH reset

	-- P2b: accelerator clock domain (DIVCLK) and its Figure-10b crossings
	SIGNAL divclk_w				: STD_LOGIC;										-- fast accelerator clock
	SIGNAL div_ain_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);		-- rs1 synchronised into DIVCLK
	SIGNAL div_bin_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);		-- rs2 synchronised into DIVCLK
	SIGNAL divena_sync_w		: STD_LOGIC_VECTOR(0 DOWNTO 0);						-- start pulse, in DIVCLK
	SIGNAL divena_slv_w			: STD_LOGIC_VECTOR(0 DOWNTO 0);
	SIGNAL divbusy_raw_w		: STD_LOGIC;										-- busy, in DIVCLK
	SIGNAL divbusy_slv_w		: STD_LOGIC_VECTOR(0 DOWNTO 0);
	SIGNAL divbusy_sync_w		: STD_LOGIC_VECTOR(0 DOWNTO 0);						-- busy, back in MCLK

BEGIN

	--=======================================
	-- PLL module connection
	--=======================================
	G0:
	if (MODELSIM = 0) generate
	  MCLK: PLL
		PORT MAP (
			inclk0 	=> clk_i,
			c0 		=> mclk_w,			-- 25 MHz  CPU / peripherals
			c1 		=> divclk_w			-- 150 MHz accelerator domain
		);
	else generate
		-- Simulation: no PLL model is bound, so MCLK is the incoming clock and
		-- DIVCLK is generated locally. It must be FASTER than MCLK or the
		-- accelerator's clock crossing is never exercised. This declarative
		-- region only exists when MODELSIM=1, so nothing here reaches Quartus.
		constant SIM_DIVCLK_PERIOD : time := 1667 ps;	-- ~6x a 10 ns MCLK
	begin
		mclk_w <= clk_i;
		SIM_DIVCLK : process
		begin
			divclk_w <= '0';
			wait for SIM_DIVCLK_PERIOD/2;
			divclk_w <= '1';
			wait for SIM_DIVCLK_PERIOD/2;
		end process;
	end generate;
	--=======================================
	-- Reset polarity
	--   Board (MODELSIM=0): rst_i is KEY0 on PIN_M23. The DE2-115 pushbuttons
	--     have a pull-up to VCC3P3 and switch to GND, so KEY0 reads '1' when it
	--     is NOT pressed. The whole design uses an active-HIGH reset, so without
	--     this inversion the MCU sits permanently in reset and only runs while
	--     the button is held down.
	--   ModelSim (MODELSIM=1): the testbenches drive rst_i active-high directly,
	--     so it passes straight through and no testbench needs changing.
	--   MODELSIM is a generic, so this choice is made at compile time and costs
	--     no hardware: the tools fold it to either a wire or one inverter.
	--=======================================
	rst_w	<=	(not rst_i)	WHEN	(MODELSIM = 0)	ELSE	-- board: KEY0 is active-low
					rst_i;															-- ModelSim: TB drives active-high
	--===========================================
	-- IFETCH (including ITCM) module connection
	--===========================================
	IFE : Ifetch
	generic map(
		WORD_GRANULARITY	=> 	WORD_GRANULARITY,
		DATA_BUS_WIDTH		=> 	DATA_BUS_WIDTH, 
		PC_WIDTH					=>	PC_WIDTH,
		ITCM_ADDR_WIDTH		=>	ITCM_ADDR_WIDTH,
		WORDS_NUM					=>	DATA_WORDS_NUM
	)
	PORT MAP (
		--Inputs
		clk_i 					=> mclk_w,
		rst_i 					=> rst_w,
		pc_hold					=> ifetch_pc_hold_w,	-- freeze PC: divider stall OR interrupt SVC1
		addr_gen_i 			=> addr_gen_w,
		Branch_ctrl_i 	=> branch_w,
		brTaken_i				=> brTaken_w,
		Jal_ctrl_i 			=> Jal_ctrl_w,
		Jalr_ctrl_i			=> Jalr_ctrl_w,
		alu_res_i				=> alu_res_w,
		set_pc_i				=> set_pc_w,				-- interrupt vector jump (SVC2)
		intr_vec_i			=> dtcm_data_rd_w(PC_WIDTH-1 DOWNTO 0),	-- Mem[TYPE] = ISR address

		--Outputs
		pc_o 						=> pc_w,
		pc_plus4_o	 		=> pc_plus4_w,
		instruction_o 	=> instruction_w    
	);
	--=======================================
	-- IDECODE module connection
	--=======================================
	ID : Idecode
  generic map(
		PC_WIDTH				=>	PC_WIDTH,
		DATA_BUS_WIDTH	=>  DATA_BUS_WIDTH
	)
	PORT MAP (	
		--Inputs
		clk_i 					=> mclk_w,  
		rst_i 					=> rst_w,
		pc_plus4_i	 		=> pc_plus4_w,
    instruction_i 	=> instruction_w,
    dtcm_data_rd_i 	=> mem_rdata_w,
		alu_res_i 			=> exe_result_w,			-- ALU / mul / quotient / remainder
		RegDst_ctrl_i		=> reg_dst_w,
		RegWrite_ctrl_i => reg_write_gated_w,	-- suppressed while stalled / during service
		MemtoReg_ctrl_i => MemtoReg_w,
		intr_we_i				=> intr_we_w,			-- P4b RF write override
		intr_rd_i				=> intr_rd_w,
		intr_wdata_i		=> intr_wdata_w,

		--Outputs
		read_data1_o 		=> read_data1_w,
    read_data2_o 		=> read_data2_w,
		gp_o						=> gp_w,					-- x3 -> GIE = gp_w(0)
		SignExt_o 			=> sign_extend_w
	);
	--=======================================
	-- CONTROL module connection
	--=======================================
	CTL:   control
	PORT MAP ( 	
		--Inputs
		instruction_i 		=> instruction_w,
		
		--Outputs
		RegDst_ctrl_o			=> reg_dst_w,
		ALUSrc_ctrl_o 		=> alu_src_w,
		MemtoReg_ctrl_o 	=> MemtoReg_w,
		RegWrite_ctrl_o 	=> reg_write_w,
		MemRead_ctrl_o 		=> mem_read_w,
		MemWrite_ctrl_o 	=> mem_write_w,
		Branch_ctrl_o 		=> branch_w,
		Jal_ctrl_o 				=> Jal_ctrl_w,
		Jalr_ctrl_o				=> Jalr_ctrl_w,
		UpperIm_ctrl_o 		=> upper_im_w,
		ALUOp_ctrl_o 			=> alu_op_w
	);
	--=======================================
	-- EXECUTE module connection
	--=======================================
	EXE:  Execute
  generic map(
		DATA_BUS_WIDTH 	=> 	DATA_BUS_WIDTH,
		PC_WIDTH 				=>	PC_WIDTH
	)
	PORT MAP (	
		--Inputs
		read_data1_i 		=> read_data1_w,
    read_data2_i 		=> read_data2_w,
		sign_extend_i 	=> sign_extend_w,
		UpperIm_ctrl_i 	=> upper_im_w,
		ALUOp_ctrl_i 		=> alu_op_w,
		ALUSrc_ctrl_i 	=> alu_src_w,
		pc_i						=> pc_w,
		
		--Outputs
		brTaken_o 			=> brTaken_w,
    alu_res_o				=> alu_res_w,
		addr_gen_o 			=> addr_gen_w			
	);
	--=======================================
	-- DTCM module connection
	--=======================================
	G1:
	if (WORD_GRANULARITY = True) generate -- i.e. each WORD has a unike address
		dtcm_addr_normal_w	<= alu_res_w(MA_WIDTH-1 DOWNTO 2); -- increment memory address by 4;
		-- vector fetch: DTCM word = TYPE/4  (drop the low 2 bits of the byte offset)
		vec_addr_w	<= CONV_STD_LOGIC_VECTOR(0, DTCM_ADDR_WIDTH-6) & type_captured_q(7 DOWNTO 2);
	elsif (WORD_GRANULARITY = False) generate -- i.e. each BYTE has a unike address
		dtcm_addr_normal_w	<= alu_res_w(MA_WIDTH-1 DOWNTO 0);
		vec_addr_w	<= CONV_STD_LOGIC_VECTOR(0, DTCM_ADDR_WIDTH-8) & type_captured_q;
	end generate;
	-- SVC2: the CPU (bus master) drives the DTCM address with the captured TYPE
	dtcm_addr_w	<= vec_addr_w WHEN vec_load_w = '1' ELSE dtcm_addr_normal_w;
	
	MEM:  dmemory
	generic map(
		DATA_BUS_WIDTH		=> 	DATA_BUS_WIDTH, 
		DTCM_ADDR_WIDTH		=> 	DTCM_ADDR_WIDTH,
		WORDS_NUM					=>	DATA_WORDS_NUM
	)
	PORT MAP (	
		--Inputs
		clk_i 						=> mclk_w,  
		rst_i 						=> rst_w,
		dtcm_addr_i 			=> dtcm_addr_w,
		dtcm_data_wr_i 		=> read_data2_w,
		MemRead_ctrl_i 		=> mem_read_w, 
		MemWrite_ctrl_i 	=> dtcm_we_w,
				
		--Outputs
		dtcm_data_rd_o 		=> dtcm_data_rd_w
	);

	--=======================================
	-- P3: MMIO bus interface (address decode + GPIO)
	--=======================================
	BUSIF: entity work.bus_interface
	generic map (
		DATA_WIDTH => DATA_BUS_WIDTH
	)
	PORT MAP (
		clk_i				=> mclk_w,
		rst_i				=> rst_w,
		addr_i			=> alu_res_w,
		wdata_i			=> read_data2_w,
		mem_write_i	=> mem_write_gated_w,	-- suppressed during interrupt service
		dtcm_rdata_i	=> dtcm_data_rd_w,
		dtcm_we_o		=> dtcm_we_w,
		rdata_o			=> mem_rdata_w,
		SW_i				=> SW_i,
		PB_i				=> PB_i,
		LEDR_o			=> LEDR_o,
		HEX0_o			=> HEX0_o,
		HEX1_o			=> HEX1_o,
		HEX2_o			=> HEX2_o,
		HEX3_o			=> HEX3_o,
		HEX4_o			=> HEX4_o,
		HEX5_o			=> HEX5_o,
		pwm_o			=> pwm_o,
		btifg_o			=> btifg_o,
		intr_o			=> intr_w,				-- INTR -> interrupt FSM (and top observe)
		inta_i			=> inta_w				-- INTA from the interrupt FSM (SVC1)
	);
	intr_o <= intr_w;

	--=======================================
	-- Divider accelerator + stall controller
	--=======================================
	-- a div/rem instruction is currently in execute
	div_instr_w	<=	'1' WHEN (alu_op_w = ALU_DIV) or (alu_op_w = ALU_REM) ELSE '0';

	--=======================================
	-- P2b: MCLK -> DIVCLK crossing  (project definition Figure 3 "Sync" box,
	-- built as Figure 10b). Operands and the start pulse are re-registered in
	-- the accelerator's own domain before the divider sees them.
	--=======================================
	SYNC_A : cdc_sync
		generic map ( W => DATA_BUS_WIDTH )
		PORT MAP ( clk_i => divclk_w, rst_i => rst_w,
		           d_i => read_data1_w, q_o => div_ain_w );

	SYNC_B : cdc_sync
		generic map ( W => DATA_BUS_WIDTH )
		PORT MAP ( clk_i => divclk_w, rst_i => rst_w,
		           d_i => read_data2_w, q_o => div_bin_w );

	divena_slv_w(0) <= divena_w;
	SYNC_ENA : cdc_sync
		generic map ( W => 1 )
		PORT MAP ( clk_i => divclk_w, rst_i => rst_w,
		           d_i => divena_slv_w, q_o => divena_sync_w );

	DIV: entity work.divider
	generic map (
		N	=> DATA_BUS_WIDTH
	)
	PORT MAP (
		DIVCLK			=> divclk_w,			-- fast accelerator domain
		DIVRST			=> rst_w,
		DIVENA			=> divena_sync_w(0),	-- start pulse, synchronised
		read_data1	=> div_ain_w,			-- rs1 = dividend (Ain)
		read_data2	=> div_bin_w,			-- rs2 = divisor  (Bin)
		Quotient		=> quotient_w,
		Residue			=> residue_w,
		DIVBUSY			=> divbusy_raw_w
	);

	--=======================================
	-- P2b: DIVCLK -> MCLK crossing. div_stall_ctrl lives in the CPU domain and
	-- its own header requires this ("add a 2-FF sync on the divider's DIVBUSY
	-- when MCLK and DIVCLK differ").
	--=======================================
	divbusy_slv_w(0) <= divbusy_raw_w;
	SYNC_BUSY : cdc_sync
		generic map ( W => 1 )
		PORT MAP ( clk_i => mclk_w, rst_i => rst_w,
		           d_i => divbusy_slv_w, q_o => divbusy_sync_w );

	divbusy_w <= divbusy_sync_w(0);

	DSTALL: entity work.div_stall_ctrl
	PORT MAP (
		clk_i				=> mclk_w,
		rst_i				=> rst_w,
		div_instr_i	=> div_instr_w,
		divbusy_i		=> divbusy_w,			-- 2-FF synchronised from DIVCLK (SYNC_BUSY)
		divena_o		=> divena_w,
		stall_o			=> stall_w
	);

	-- suppress the register write while stalled or during interrupt service
	-- (the FSM's own forced writes go through intr_we_w, not this path)
	reg_write_gated_w	<=	reg_write_w and (not stall_w) and (not svc_active_w);

	-- write-back result mux: quotient / remainder / (ALU, incl. mul)
	exe_result_w	<=	quotient_w	WHEN (alu_op_w = ALU_DIV) ELSE
									residue_w		WHEN (alu_op_w = ALU_REM) ELSE
									alu_res_w;

	--=======================================
	-- P4b: CPU-side interrupt service
	--=======================================
	-- take an interrupt only at an instruction boundary (not mid-divide)
	can_take_w <= not stall_w;

	IRQ_FSM: entity work.intr_fsm
	PORT MAP (
		clk_i				=> mclk_w,
		rst_i				=> rst_w,
		intr_i			=> intr_w,
		gie_i				=> gp_w(0),				-- GIE = gp[0]
		can_take_i	=> can_take_w,
		inta_o			=> inta_w,
		svc_active_o	=> svc_active_w,
		capture_o		=> capture_w,
		clr_gie_o		=> clr_gie_w,
		vec_load_o		=> vec_load_w,
		set_pc_o			=> set_pc_w,
		write_tp_o		=> write_tp_w
	);

	-- freeze the PC during SVC1 (hold the deferred instruction); SVC2 redirects it
	pc_freeze_w			<=	svc_active_w and (not set_pc_w);
	ifetch_pc_hold_w	<=	stall_w or pc_freeze_w;

	-- keep the deferred store from touching memory during service
	mem_write_gated_w	<=	mem_write_w and (not svc_active_w);

	-- reti = jalr x0, 0(tp)  (tp = x4)  ->  encodes as 0x00020067
	reti_w <= '1' WHEN instruction_w = X"00020067" ELSE '0';

	-- SVC1: latch TYPE (off the data bus during INTA) and the return address
	intr_capture: process (mclk_w, rst_w)
	begin
		if rst_w = '1' then
			type_captured_q	<= (others => '0');
			return_pc_q			<= (others => '0');
		elsif rising_edge(mclk_w) then
			if capture_w = '1' then
				type_captured_q	<= mem_rdata_w(7 DOWNTO 0);	-- controller drives TYPE here
				return_pc_q			<= pc_w;								-- PC of the deferred instruction
			end if;
		end if;
	end process;

	-- RF write override:  SVC1 clears GIE (gp[0]=0);  SVC2 saves tp=return;
	-- reti sets GIE (gp[0]=1).  These are mutually exclusive by FSM state.
	intr_rf_override: process (clr_gie_w, write_tp_w, reti_w, gp_w, return_pc_q)
	begin
		if clr_gie_w = '1' then							-- SVC1
			intr_we_w		<= '1';
			intr_rd_w		<= "00011";					-- x3 = gp
			intr_wdata_w	<= gp_w and X"FFFFFFFE";	-- clear bit 0
		elsif write_tp_w = '1' then					-- SVC2
			intr_we_w		<= '1';
			intr_rd_w		<= "00100";					-- x4 = tp
			intr_wdata_w	<= CONV_STD_LOGIC_VECTOR(0, DATA_BUS_WIDTH-PC_WIDTH) & return_pc_q;
		elsif reti_w = '1' then							-- reti
			intr_we_w		<= '1';
			intr_rd_w		<= "00011";					-- x3 = gp
			intr_wdata_w	<= gp_w or X"00000001";		-- set bit 0
		else
			intr_we_w		<= '0';
			intr_rd_w		<= "00000";
			intr_wdata_w	<= (others => '0');
		end if;
	end process;

	--=======================================
	-- MCLK counter register connection
	--=======================================
	process (mclk_w , rst_w)
	begin
		if rst_w = '1' then
			mclk_cnt_q	<=	(others	=> '0');
		elsif rising_edge(mclk_w) then
			mclk_cnt_q	<=	mclk_cnt_q + '1';
		end if;
	end process;
---------------------------------------------------------------------------------------
-- Copying out important signals only for Verification and FPGA Velidation(Signal-TAP)
---------------------------------------------------------------------------------------
	pc_o							<=	pc_w;																				-- IFETCH output								
  instruction_o 		<= 	instruction_w;															-- IFETCH output
	
	RegWrite_ctrl_o 	<= 	reg_write_w;																-- CONTROL output
  MemWrite_ctrl_o 	<= 	mem_write_w;																-- CONTROL output
	Branch_ctrl_o 		<= 	branch_w;																		-- CONTROL output
	  
  read_data1_o 			<= 	read_data1_w;																-- IDECODE output
  read_data2_o 			<= 	read_data2_w;																-- IDECODE output
  write_data_o  		<= 	mem_rdata_w WHEN MemtoReg_w = '1' ELSE		-- IDECODE input(Write-Back)
												exe_result_w;
												
  alu_res_o 				<= 	alu_res_w;																	-- EXECUTE output			
  brTaken_o 				<= 	brTaken_w;																	-- EXECUTE output
  
	dtcm_addr_o 			<= 	dtcm_addr_w;																-- DMEMORY input
	dtcm_data_wr_o 		<= 	read_data2_w;																-- DMEMORY input
	dtcm_data_rd_o		<=	dtcm_data_rd_w;															-- DMEMORY output
	
	mclk_cnt_o				<=	mclk_cnt_q;																	-- TOP output
	
---------------------------------------------------------------------------------------

END structure;

