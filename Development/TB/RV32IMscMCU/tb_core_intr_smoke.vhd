--------------------------------------------------------------------------------
-- tb_core_intr_smoke.vhd
-- Integration smoke test for the Basic Interrupt Controller on the bus (CPU
-- untouched). The hand-assembled program (SIM/RV32IMscMCU/ITCM.hex) does:
--     BTCTL1 = 0x24 (hold+clear)
--     BTCMPR0 = 9    (compare -> btifg every 10 SMCLK)
--     IE      = 0x04 (enable the BT interrupt, bit 2)
--     BTCTL1 = 0x00  (run)
--     spin
-- Verifies the whole chain through the integrated bus:
--     CPU writes IE + timer config  ->  timer fires btifg  ->  controller sets
--     IFG.BT (enabled)              ->  INTR asserts (intr_o).
-- INTR stays high (sticky flag, inta tied 0) until a CPU protocol services it.
-- Prereq: G_MODELSIM=1.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cond_compilation_package.all;
use work.aux_package.all;

entity tb_core_intr_smoke is
end entity tb_core_intr_smoke;

architecture sim of tb_core_intr_smoke is

    constant PCW : integer := G_PC_WIDTH;
    constant DAW : integer := G_ADDRWIDTH;
    constant T   : time    := 10 ns;

    signal clk, rst : std_logic := '0';

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

    signal SW   : std_logic_vector(7 downto 0) := (others => '0');
    signal PB   : std_logic_vector(2 downto 0) := (others => '1');   -- KEYs released (active-low)
    signal LEDR : std_logic_vector(7 downto 0);
    signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);
    signal pwm  : std_logic;
    signal btifg: std_logic;
    signal intr : std_logic;

    signal sim_done : boolean := false;

begin

    CORE : RV32I_CORE
        generic map (
            WORD_GRANULARITY => G_WORD_GRANULARITY, MODELSIM => G_MODELSIM,
            DATA_BUS_WIDTH => 32, ITCM_ADDR_WIDTH => G_ADDRWIDTH,
            DTCM_ADDR_WIDTH => G_ADDRWIDTH, PC_WIDTH => G_PC_WIDTH,
            MA_WIDTH => G_MA_WIDTH, DATA_WORDS_NUM => G_DATA_WORDSNUM,
            CLK_CNT_WIDTH => 16
        )
        port map (
            rst_i => rst, clk_i => clk,
            pc_o => pc_o, instruction_o => instruction_o,
            RegWrite_ctrl_o => RegWrite_ctrl_o, MemWrite_ctrl_o => MemWrite_ctrl_o,
            Branch_ctrl_o => Branch_ctrl_o,
            read_data1_o => read_data1_o, read_data2_o => read_data2_o,
            write_data_o => write_data_o, alu_res_o => alu_res_o, brTaken_o => brTaken_o,
            dtcm_addr_o => dtcm_addr_o, dtcm_data_wr_o => dtcm_data_wr_o,
            dtcm_data_rd_o => dtcm_data_rd_o, mclk_cnt_o => mclk_cnt_o,
            SW_i => SW, PB_i => PB, LEDR_o => LEDR,
            HEX0_o => HEX0, HEX1_o => HEX1, HEX2_o => HEX2,
            HEX3_o => HEX3, HEX4_o => HEX4, HEX5_o => HEX5,
            pwm_o => pwm, btifg_o => btifg, intr_o => intr
        );

    clkgen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for T/2;
            clk <= '1'; wait for T/2;
        end loop;
        wait;
    end process;

    rst <= '1', '0' after 8*T;

    check : process
        variable errors : natural := 0;
    begin
        wait until rst = '0';

        -- right after reset, before the program has configured anything, INTR is low
        wait for 3*T;
        if intr /= '0' then
            errors := errors + 1;
            report "FAIL: INTR high before any interrupt is configured" severity error;
        else
            report "pass: INTR low after reset (nothing pending yet)" severity note;
        end if;

        -- let the program configure (IE + timer) and the timer fire; sample INTR
        wait for 2 us;
        if intr = '1' then
            report "pass: INTR asserted (timer btifg -> IFG.BT -> INTR, all via the bus)"
                   severity note;
        else
            errors := errors + 1;
            report "FAIL: INTR never asserted -> controller not reachable / no source"
                   severity error;
        end if;

        report "==============================================";
        if errors = 0 then
            report "RESULT: PASS  (interrupt controller integrated; BT interrupt reaches INTR)"
                   severity note;
        else
            report "RESULT: FAIL" severity failure;
        end if;
        report "==============================================";

        sim_done <= true;
        wait;
    end process;

end architecture sim;
