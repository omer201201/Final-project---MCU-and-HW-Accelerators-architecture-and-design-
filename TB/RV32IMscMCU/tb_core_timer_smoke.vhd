--------------------------------------------------------------------------------
-- tb_core_timer_smoke.vhd
-- Integration smoke test: proves the CPU can reach the Basic Timer registers
-- through the MMIO bus after integration. Runs a tiny hand-assembled program
-- (in SIM/RV32IMscMCU/ITCM.hex) that does, in compare mode:
--     BTCTL1 = 0x24   (BTHOLD+BTCLR)
--     BTCMPR0 = 9     (period -> BTIFG every 10 SMCLK)
--     BTCTL1 = 0x00   (run, BTINT=0 -> EUQ0, BTSSEL=0 -> /1)
--     spin
-- Then checks btifg_o pulses, and that the period is 10 MCLK cycles.
-- Prereq: G_MODELSIM=1. This ONLY observes the integrated core -- CPU untouched.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cond_compilation_package.all;
use work.aux_package.all;

entity tb_core_timer_smoke is
end entity tb_core_timer_smoke;

architecture sim of tb_core_timer_smoke is

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
    signal PB   : std_logic_vector(2 downto 0) := (others => '0');
    signal LEDR : std_logic_vector(7 downto 0);
    signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);
    signal pwm  : std_logic;
    signal btifg: std_logic;

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
            pwm_o => pwm, btifg_o => btifg
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
        variable t1, t2 : time;
        variable errors : natural := 0;
    begin
        wait until rst = '0';
        wait for 1 us;                        -- program configures the timer

        -- first BTIFG pulse (fail cleanly if the timer never fires)
        wait until btifg = '1' for 5 us;
        if btifg /= '1' then
            errors := errors + 1;
            report "FAIL: btifg never pulsed -> CPU cannot reach the timer via the bus"
                   severity error;
        else
            t1 := now;
            wait until btifg = '0';
            wait until btifg = '1';           -- second pulse
            t2 := now;
            report "btifg period = " & time'image(t2 - t1) severity note;
            if (t2 - t1) = 10 * T then
                report "pass: compare period = 10 MCLK (BTCMPR0=9)" severity note;
            else
                errors := errors + 1;
                report "FAIL: expected 10*T period, got " & time'image(t2 - t1)
                       severity error;
            end if;
        end if;

        report "==============================================";
        if errors = 0 then
            report "RESULT: PASS  (timer reachable from CPU; compare fires @ correct period)"
                   severity note;
        else
            report "RESULT: FAIL" severity failure;
        end if;
        report "==============================================";

        sim_done <= true;
        wait;
    end process;

end architecture sim;
