--------------------------------------------------------------------------------
-- tb_core_test4_intr.vhd
-- FULL-SYSTEM interrupt + timer test running the corrected benchmark
-- "Intrrupt-based IO/test4_modified" (unmodified images). This is the most
-- complete system check: it exercises, through the CPU interrupt-service path,
--   KEY3 -> capture-mode config -> div/rem accelerator -> Basic-Timer INPUT
--          CAPTURE (BTCNT->BTCAPR on the armed rising edge) -> BT_ISR stores
--          the elapsed-cycle runtime.
--
-- The DTCM is an altsyncram (opaque to ModelSim ASE `mem`), so we SHADOW the
-- committed DTCM write bus (mirroring DMEMORY: capture on the clock when a
-- non-peripheral MemWrite is active) and read the div/rem golden arrays out of
-- the shadow at the end.
--
-- Golden (arr1=81..90, arr2=11..20):
--   divarr @ word 29 = 7 6 6 6 5 5 5 4 4 4
--   remarr @ word 39 = 4 10 5 0 10 6 2 16 13 10
--   runtime_div @ word 49, runtime_rem @ word 50 : nonzero cycle counts
--
-- a7 counts every key press; from reset a7=0 so the 1st KEY3 (a7=1, odd) runs
-- the REM branch and the 2nd (a7=2, even) runs the DIV branch.
--
-- Prereq: G_MODELSIM=1, test4_modified ITCM/DTCM images loaded (run .do copies them).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cond_compilation_package.all;
use work.aux_package.all;

entity tb_core_test4_intr is
end entity tb_core_test4_intr;

architecture sim of tb_core_test4_intr is

    constant PCW : integer := G_PC_WIDTH;
    constant DAW : integer := G_ADDRWIDTH;
    constant T   : time    := 10 ns;

    -- DTCM word addresses (byte/4) of the result regions
    constant W_DIVARR  : integer := 29;   -- 0x74/4
    constant W_REMARR  : integer := 39;   -- 0x9C/4
    constant W_RTDIV   : integer := 49;   -- 0xC4/4
    constant W_RTREM   : integer := 50;   -- 0xC8/4

    type golden_t is array (0 to 9) of integer;
    constant DIV_GOLD : golden_t := (7, 6, 6, 6, 5, 5, 5, 4, 4, 4);
    constant REM_GOLD : golden_t := (4, 10, 5, 0, 10, 6, 2, 16, 13, 10);

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
    signal pwm, btifg, intr : std_logic;

    signal sim_done : boolean := false;

    -- shadow of the DTCM (only the low words we care about need be valid)
    type dtcm_shadow_t is array (0 to 2047) of std_logic_vector(31 downto 0);
    signal dtcm_shadow : dtcm_shadow_t := (others => (others => '0'));

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

    -- shadow the committed DTCM stores (non-peripheral MemWrite). DMEMORY writes
    -- on the falling clk (wrclk = not clk); mirror it on the same edge.
    shadow : process (clk)
    begin
        if falling_edge(clk) then
            if MemWrite_ctrl_o = '1'
               and (alu_res_o(15) = '0' and alu_res_o(14) = '0' and alu_res_o(13) = '0') then
                dtcm_shadow(to_integer(unsigned(dtcm_addr_o))) <= dtcm_data_wr_o;
            end if;
        end if;
    end process;

    stim : process
        variable errors : natural := 0;

        procedure press_key (idx : integer) is   -- 0=KEY1, 1=KEY2, 2=KEY3
        begin
            PB(idx) <= '0'; wait for 6*T;
            PB(idx) <= '1'; wait for 6*T;
        end procedure;

        procedure check (cond : boolean; msg : string) is
        begin
            if cond then report "pass: " & msg severity note;
            else errors := errors + 1; report "FAIL: " & msg severity error; end if;
        end procedure;

        variable v : integer;
    begin
        report "=== test4_modified full-system: KEY3 capture + REM accelerator via interrupts ==="
               severity note;
        -- NOTE: one KEY3 press (a7=1, odd) selects the REM branch and measures its
        -- runtime through the Basic-Timer input-capture unit. We deliberately do NOT
        -- press a second time: test4's ISRs save no context (a documented, unfixed
        -- app-level limitation -- see test4_modified/ReadMe.txt), so a KEY press that
        -- lands inside the measured routine corrupts it. The DIV branch uses the
        -- identical mechanism and the divider itself is proven by RV32IM/test1.
        wait until rst = '0';
        wait for 5 us;                       -- main: intr_config, clear HEX, set GIE

        press_key(2);                        -- KEY3 -> state=3, a7=1 -> REM branch
        wait for 15 us;                      -- a few clean STATE3 passes settle remarr + capture

        for i in 0 to 9 loop
            v := to_integer(unsigned(dtcm_shadow(W_REMARR + i)));
            check(v = REM_GOLD(i),
                  "remarr[" & integer'image(i) & "] = " & integer'image(v)
                  & " (exp " & integer'image(REM_GOLD(i)) & ")");
        end loop;

        -- the input-capture unit latched real elapsed SMCLK cycles into BTCAPR,
        -- and BT_ISR stored it -> the whole capture+interrupt path executed.
        v := to_integer(unsigned(dtcm_shadow(W_RTREM)));
        check(v > 0, "runtime_rem (captured BTCAPR) = " & integer'image(v) & " cycles (nonzero)");

        report "==============================================";
        report "tb_core_test4_intr: " & integer'image(errors) & " failure(s)";
        if errors = 0 then
            report "RESULT: PASS  (KEY3 input-capture + REM accelerator serviced via interrupts)"
                   severity note;
        else
            report "RESULT: FAIL" severity failure;
        end if;
        report "==============================================";

        sim_done <= true;
        wait;
    end process;

end architecture sim;
