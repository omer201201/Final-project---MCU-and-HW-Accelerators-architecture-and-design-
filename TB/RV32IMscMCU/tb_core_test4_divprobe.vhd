--------------------------------------------------------------------------------
-- tb_core_test4_divprobe.vhd
--
-- INSTRUMENTED variant of tb_core_test4_intr for the "memory-mismatch" root-cause
-- investigation.  It presses KEY3 TWICE (1st press a7=1 -> REM branch, 2nd press
-- a7=2 -> DIV branch) and then, on EVERY completed div_arrays pass, snapshots the
-- 10-element div-result array `divarr` (DTCM words 29..38) out of the shadowed
-- committed store bus, together with a per-pass flag telling whether an interrupt
-- (an ISR entry) landed WHILE div_arrays was executing.
--
-- Purpose: decide whether the HW ISMCE read-back `7 6 6 4 6 5 5 4 4 4`
-- (golden `7 6 6 6 5 5 5 4 4 4`) is a real architecture fault or an application
-- level interrupt-collision artifact.  The app's BT_ISR / KEY_ISR save NO context
-- and use t1/t2/t3 -- the very registers div_arrays holds its live dividend /
-- divisor / quotient in.  If a Basic-Timer capture interrupt lands between the
-- `div t3,t1,t2` and the following `sw t3,0(s10)`, t3 is clobbered and one divarr
-- element is stored wrong.
--
-- Memory map / static addresses (all byte addresses; DTCM word = byte/4):
--   divarr    : DTCM words 29..38   (byte 0x74..0x98)
--   div_arrays: byte pc 0x444..0x47C   (entry 0x444, div 0x460, sw 0x464, ret 0x47C)
--   ISR entries: KEY1 0x134, KEY2 0x170, KEY3 0x1AC, BT_ISR 0x1E8
--
-- Interrupt-overlap detection uses ONLY the top-level pc / intr (no VHDL-2008
-- external name into the FSM), to avoid the opt-related clock-stall the task warns
-- about.  div_active is armed when pc enters the div_arrays entry (0x444) and
-- disarmed when the last element (word 38) is committed; any ISR-entry pc or
-- asserted `intr` seen while div_active marks the pass corrupted-by-interrupt.
--
-- Prereq: G_MODELSIM=1, test4_modified ITCM/DTCM images loaded (run .do copies).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cond_compilation_package.all;
use work.aux_package.all;

entity tb_core_test4_divprobe is
end entity tb_core_test4_divprobe;

architecture sim of tb_core_test4_divprobe is

    constant PCW : integer := G_PC_WIDTH;
    constant DAW : integer := G_ADDRWIDTH;
    constant T   : time    := 10 ns;

    constant W_DIVARR_LO : integer := 29;   -- divarr[0] word
    constant W_DIVARR_HI : integer := 38;   -- divarr[9] word

    -- div_arrays byte-pc window and ISR entry byte-pcs
    constant PC_DIV_ENTRY : integer := 16#444#;
    constant PC_DIV_END   : integer := 16#47C#;
    constant PC_BT_ISR    : integer := 16#1E8#;
    constant PC_KEY1_ISR  : integer := 16#134#;
    constant PC_KEY2_ISR  : integer := 16#170#;
    constant PC_KEY3_ISR  : integer := 16#1AC#;

    type golden_t is array (0 to 9) of integer;
    constant DIV_GOLD : golden_t := (7, 6, 6, 6, 5, 5, 5, 4, 4, 4);

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
    signal PB   : std_logic_vector(2 downto 0) := (others => '1');
    signal LEDR : std_logic_vector(7 downto 0);
    signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);
    signal pwm, btifg, intr : std_logic;

    signal sim_done : boolean := false;

    type dtcm_shadow_t is array (0 to 2047) of std_logic_vector(31 downto 0);
    signal dtcm_shadow : dtcm_shadow_t := (others => (others => '0'));

    -- per-pass recorded results
    constant MAXPASS : integer := 128;
    type passvals_t is array (0 to MAXPASS-1, 0 to 9) of integer;
    signal pass_vals  : passvals_t := (others => (others => 0));
    type passbool_t is array (0 to MAXPASS-1) of boolean;
    signal pass_intr  : passbool_t := (others => false);  -- interrupt hit during div_arrays
    signal pass_which : passbool_t := (others => false);   -- (reserved)
    signal npass      : integer := 0;

    -- diagnostics
    signal dbg_entry  : integer := 0;   -- times pc hit div_arrays entry 0x444
    signal dbg_st29   : integer := 0;   -- stores to word 29 (divarr[0])
    signal dbg_st38   : integer := 0;   -- stores to word 38 (divarr[9])
    signal dbg_maxpc  : integer := 0;   -- max byte pc observed
    signal dbg_key3   : integer := 0;   -- KEY3_ISR entries (pc=0x1AC)
    signal dbg_bt     : integer := 0;   -- BT_ISR entries (pc=0x1E8)
    signal dbg_divi   : integer := 0;   -- div instruction fetches (pc=0x460)
    signal dbg_remi   : integer := 0;   -- rem instruction fetches (pc=0x49C)

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

    -----------------------------------------------------------------------------
    -- Shadow committed DTCM stores AND record div_arrays passes.
    -- Committed store = MemWrite='1' AND non-peripheral (alu_res(15:13)="000").
    -- DMEMORY writes on falling clk; mirror + probe on the same edge.
    -----------------------------------------------------------------------------
    monitor : process (clk)
        variable pc_b       : integer;
        variable is_store   : boolean;
        variable word_addr  : integer;
        variable div_active : boolean := false;
        variable intr_hit   : boolean := false;
        variable idx        : integer;
    begin
        if falling_edge(clk) then
            if rst = '0' then
                pc_b := to_integer(unsigned(pc_o));

                if pc_b > dbg_maxpc then dbg_maxpc <= pc_b; end if;
                if pc_b = PC_KEY3_ISR then dbg_key3 <= dbg_key3 + 1; end if;
                if pc_b = PC_KEY1_ISR then dbg_divi <= dbg_divi + 1000000; end if; -- reuse hi digits: KEY1
                if pc_b = PC_KEY2_ISR then dbg_remi <= dbg_remi + 1000000; end if; -- reuse hi digits: KEY2
                if pc_b = PC_BT_ISR   then dbg_bt   <= dbg_bt   + 1; end if;
                if pc_b = 16#460#     then dbg_divi <= dbg_divi + 1; end if;
                if pc_b = 16#49C#     then dbg_remi <= dbg_remi + 1; end if;

                -- arm the div_arrays pass window on entry
                if pc_b = PC_DIV_ENTRY then
                    div_active := true;
                    intr_hit   := false;
                    dbg_entry  <= dbg_entry + 1;
                end if;

                -- while a div_arrays pass is open, note any ISR entry / intr assert
                if div_active then
                    if pc_b = PC_BT_ISR or pc_b = PC_KEY1_ISR
                       or pc_b = PC_KEY2_ISR or pc_b = PC_KEY3_ISR
                       or intr = '1' then
                        intr_hit := true;
                    end if;
                end if;

                -- committed store?
                is_store := (MemWrite_ctrl_o = '1')
                            and (alu_res_o(15) = '0' and alu_res_o(14) = '0'
                                 and alu_res_o(13) = '0');
                if is_store then
                    word_addr := to_integer(unsigned(dtcm_addr_o));
                    dtcm_shadow(word_addr) <= dtcm_data_wr_o;
                    if word_addr = W_DIVARR_LO then dbg_st29 <= dbg_st29 + 1; end if;
                    if word_addr = W_DIVARR_HI then dbg_st38 <= dbg_st38 + 1; end if;

                    -- last divarr element committed -> a full pass just finished
                    if word_addr = W_DIVARR_HI and div_active then
                        if npass < MAXPASS then
                            for i in 0 to 9 loop
                                if i = 9 then
                                    -- word 38 is being written this very edge
                                    pass_vals(npass, i)
                                        <= to_integer(unsigned(dtcm_data_wr_o));
                                else
                                    pass_vals(npass, i)
                                        <= to_integer(unsigned(
                                             dtcm_shadow(W_DIVARR_LO + i)));
                                end if;
                            end loop;
                            pass_intr(npass) <= intr_hit;
                            npass <= npass + 1;
                        end if;
                        div_active := false;
                        intr_hit   := false;
                    end if;
                end if;
            end if;
        end if;
    end process;

    stim : process
        variable errors : natural := 0;
        variable clean_cnt     : integer := 0;
        variable clean_ok      : integer := 0;
        variable corrupt_cnt   : integer := 0;
        variable corrupt_wintr : integer := 0;
        variable is_gold       : boolean;

        procedure press_key (idx : integer) is   -- 0=KEY1, 1=KEY2, 2=KEY3
        begin
            PB(idx) <= '0'; wait for 6*T;
            PB(idx) <= '1'; wait for 6*T;
        end procedure;
    begin
        report "=== test4_divprobe: KEY3 x2 (REM then DIV), per-pass divarr probe ===";
        wait until rst = '0';
        wait for 5 us;          -- main: intr_config, clear HEX, set GIE

        press_key(2);           -- 1st KEY3: a7=1 (odd) -> REM branch
        wait for 15 us;

        press_key(2);           -- 2nd KEY3: a7=2 (even) -> DIV branch
        wait for 60 us;         -- collect many STATE3 DIV passes

        report "DIAG: div_arrays entries=" & integer'image(dbg_entry)
             & " stores_to_w29=" & integer'image(dbg_st29)
             & " stores_to_w38=" & integer'image(dbg_st38)
             & " max_pc_byte=" & integer'image(dbg_maxpc);
        report "DIAG2: KEY3_ISR=" & integer'image(dbg_key3)
             & " BT_ISR=" & integer'image(dbg_bt)
             & " div_instr=" & integer'image(dbg_divi)
             & " rem_instr=" & integer'image(dbg_remi);
        -- report every recorded pass
        report "----- per-pass divarr snapshots (DTCM words 29..38) -----";
        for p in 0 to npass-1 loop
            report "pass " & integer'image(p) & " : "
                 & integer'image(pass_vals(p,0)) & " "
                 & integer'image(pass_vals(p,1)) & " "
                 & integer'image(pass_vals(p,2)) & " "
                 & integer'image(pass_vals(p,3)) & " "
                 & integer'image(pass_vals(p,4)) & " "
                 & integer'image(pass_vals(p,5)) & " "
                 & integer'image(pass_vals(p,6)) & " "
                 & integer'image(pass_vals(p,7)) & " "
                 & integer'image(pass_vals(p,8)) & " "
                 & integer'image(pass_vals(p,9))
                 & "   intr_in_div=" & boolean'image(pass_intr(p));
        end loop;

        -- verdict logic: every CLEAN pass must equal golden; every CORRUPT pass
        -- must coincide with an interrupt in div_arrays.
        report "----- correlation check -----";
        for p in 0 to npass-1 loop
            is_gold := true;
            for i in 0 to 9 loop
                if pass_vals(p,i) /= DIV_GOLD(i) then
                    is_gold := false;
                end if;
            end loop;
            if is_gold then
                clean_ok := clean_ok + 1;
            end if;
            if pass_intr(p) then
                corrupt_cnt := corrupt_cnt + 1;
                if not is_gold then
                    corrupt_wintr := corrupt_wintr + 1;
                end if;
            else
                clean_cnt := clean_cnt + 1;
                if not is_gold then
                    errors := errors + 1;
                    report "VIOLATION: NO-interrupt pass " & integer'image(p)
                         & " differs from golden -> would be an ARCH fault"
                         severity error;
                end if;
            end if;
        end loop;
        report "passes total          = " & integer'image(npass);
        report "passes == golden      = " & integer'image(clean_ok);
        report "passes WITHOUT intr   = " & integer'image(clean_cnt);
        report "passes WITH intr      = " & integer'image(corrupt_cnt);
        report "  of those, corrupted = " & integer'image(corrupt_wintr);

        report "==============================================";
        if errors = 0 then
            report "RESULT: PASS  -- every no-interrupt pass equals golden "
                 & "7 6 6 6 5 5 5 4 4 4; corruption only ever coincides with an "
                 & "interrupt inside div_arrays  => APPLICATION collision, not an "
                 & "architecture fault." severity note;
        else
            report "RESULT: FAIL -- a no-interrupt pass diverged from golden "
                 & "=> possible architecture fault." severity failure;
        end if;
        report "==============================================";

        sim_done <= true;
        wait;
    end process;

end architecture sim;
