--------------------------------------------------------------------------------
-- tb_power.vhd
-- Minimal testbench used ONLY to generate a switching-activity VCD for the
-- Quartus Power Analyzer. Runs benchmark test1 (div/mul/rem) at 25 MHz so the
-- toggle rates match the FPGA MCLK (PLL c0 = 25 MHz). Requires G_MODELSIM = 1
-- (bypasses the PLL: mclk_w = clk_i). No self-checking here.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.cond_compilation_package.all;
use work.aux_package.all;

entity tb_power is
end entity tb_power;

architecture sim of tb_power is
    constant PCW : integer := G_PC_WIDTH;
    constant DAW : integer := G_ADDRWIDTH;

    signal clk, rst        : std_logic := '0';
    signal pc_o            : std_logic_vector(PCW-1 downto 0);
    signal instruction_o   : std_logic_vector(31 downto 0);
    signal RegWrite_ctrl_o : std_logic;
    signal MemWrite_ctrl_o : std_logic;
    signal Branch_ctrl_o   : std_logic;
    signal read_data1_o    : std_logic_vector(31 downto 0);
    signal read_data2_o    : std_logic_vector(31 downto 0);
    signal write_data_o    : std_logic_vector(31 downto 0);
    signal alu_res_o       : std_logic_vector(31 downto 0);
    signal brTaken_o       : std_logic;
    signal dtcm_addr_o     : std_logic_vector(DAW-1 downto 0);
    signal dtcm_data_wr_o  : std_logic_vector(31 downto 0);
    signal dtcm_data_rd_o  : std_logic_vector(31 downto 0);
    signal mclk_cnt_o      : std_logic_vector(15 downto 0);
begin
    CORE : RV32I_CORE
        generic map (
            WORD_GRANULARITY => G_WORD_GRANULARITY,
            MODELSIM         => G_MODELSIM,
            DATA_BUS_WIDTH   => 32,
            ITCM_ADDR_WIDTH  => G_ADDRWIDTH,
            DTCM_ADDR_WIDTH  => G_ADDRWIDTH,
            PC_WIDTH         => G_PC_WIDTH,
            MA_WIDTH         => G_MA_WIDTH,
            DATA_WORDS_NUM   => G_DATA_WORDSNUM,
            CLK_CNT_WIDTH    => 16
        )
        port map (
            rst_i => rst, clk_i => clk,
            pc_o => pc_o, instruction_o => instruction_o,
            RegWrite_ctrl_o => RegWrite_ctrl_o, MemWrite_ctrl_o => MemWrite_ctrl_o,
            Branch_ctrl_o => Branch_ctrl_o,
            read_data1_o => read_data1_o, read_data2_o => read_data2_o,
            write_data_o => write_data_o, alu_res_o => alu_res_o, brTaken_o => brTaken_o,
            dtcm_addr_o => dtcm_addr_o, dtcm_data_wr_o => dtcm_data_wr_o,
            dtcm_data_rd_o => dtcm_data_rd_o, mclk_cnt_o => mclk_cnt_o
        );

    clk <= not clk after 20 ns;        -- 40 ns period = 25 MHz (matches FPGA MCLK)
    rst <= '1', '0' after 100 ns;      -- active-high reset in sim (G_MODELSIM=1)
end architecture sim;
