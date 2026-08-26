--------------------------------------------------------------------------------
-- tb_core_test2_intr.vhd
-- END-TO-END interrupt test of the CPU-side service protocol (P4b) running the
-- lecturer's real benchmark "Intrrupt-based IO/test2" (unmodified images).
--
-- test2 is a state-based FSM kernel. KEY1/2/3 presses raise maskable interrupts;
-- each KEYx_ISR sets  state = x  (a .data word) and software-clears its IFG, then
-- `reti`. The main loop reads `state` and drives the display. BT is enabled too
-- but its period is SEC_PERIOD=20M -> never fires in sim, so KEYs are the driver.
--
-- We press KEY1, KEY2, KEY3 in turn and check the committed write to the `state`
-- variable (DTCM word 8) becomes 1, then 2, then 3. Each transition proves the
-- WHOLE mechanism: INTR -> INTA -> capture TYPE -> vector Mem[TYPE] -> run the
-- ISR body -> reti -> resume the main program (which is what wrote nothing to
-- state before the first key).
--
-- Prereq: G_MODELSIM=1, and test2 ITCM/DTCM images loaded (the run .do copies them).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cond_compilation_package.all;
use work.aux_package.all;

entity tb_core_test2_intr is
end entity tb_core_test2_intr;

architecture sim of tb_core_test2_intr is

    constant PCW : integer := G_PC_WIDTH;
    constant DAW : integer := G_ADDRWIDTH;
    constant T   : time    := 10 ns;
    constant STATE_WORD : integer := 8;   -- `state` variable = DTCM word 8

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

    signal sim_done       : boolean := false;
    signal observed_state : integer := -1;   -- last value committed to the state word

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

    -- snoop the committed write to the `state` variable (DTCM word 8, mid-cycle)
    snoop : process (clk)
    begin
        if falling_edge(clk) then
            -- a real DTCM store (not a peripheral write that merely aliases in the
            -- low address bits) to the state word: addr>=0x2000 => peripheral.
            if MemWrite_ctrl_o = '1'
               and (alu_res_o(15) = '0' and alu_res_o(14) = '0' and alu_res_o(13) = '0')
               and to_integer(unsigned(dtcm_addr_o)) = STATE_WORD then
                observed_state <= to_integer(unsigned(dtcm_data_wr_o));
            end if;
        end if;
    end process;

    stim : process
        variable errors : natural := 0;

        procedure press_key (idx : integer) is   -- 0=KEY1, 1=KEY2, 2=KEY3
        begin
            PB(idx) <= '0'; wait for 6*T;         -- press  (1->0 falling edge = press)
            PB(idx) <= '1'; wait for 6*T;         -- release
        end procedure;

        procedure check (cond : boolean; msg : string) is
        begin
            if cond then report "pass: " & msg severity note;
            else errors := errors + 1; report "FAIL: " & msg severity error; end if;
        end procedure;
    begin
        report "=== test2 interrupt end-to-end (KEY-driven) ===" severity note;
        wait until rst = '0';
        wait for 3 us;                            -- let main run sys_init + set GIE
        check(observed_state <= 0, "no state write before any key press (main only reads state)");

        press_key(0);                             -- KEY1 -> KEY1_ISR -> state=1
        wait for 2 us;
        check(observed_state = 1, "KEY1: interrupt vectored to KEY1_ISR, state=1, reti resumed");

        press_key(1);                             -- KEY2 -> state=2
        wait for 2 us;
        check(observed_state = 2, "KEY2: interrupt vectored to KEY2_ISR, state=2, reti resumed");

        press_key(2);                             -- KEY3 -> state=3
        wait for 2 us;
        check(observed_state = 3, "KEY3: interrupt vectored to KEY3_ISR, state=3, reti resumed");

        report "==============================================";
        report "tb_core_test2_intr: " & integer'image(errors) & " failure(s)";
        if errors = 0 then
            report "RESULT: PASS  (CPU services KEY interrupts: vector, ISR, reti, resume)" severity note;
        else
            report "RESULT: FAIL" severity failure;
        end if;
        report "==============================================";

        sim_done <= true;
        wait;
    end process;

end architecture sim;
