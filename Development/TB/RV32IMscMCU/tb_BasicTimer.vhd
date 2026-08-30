--------------------------------------------------------------------------------
-- tb_BasicTimer.vhd
--
-- Self-checking testbench for the Basic Timer peripheral.
-- Drives the peripheral exactly the way the benchmark applications do: byte
-- stores to BTCTL1/BTCTL2 and word stores to BTCMPR0/BTCMPR1, using the same
-- io_map.s mask constants.
--
-- Coverage:
--   T1  reset state
--   T2  compare mode, BTSSEL = 0  -> BTIFG period
--   T3  BTSSEL = 3 (SMCLK/8)      -> BTIFG period scales x8
--   T4  BTHOLD freezes BTCNT, BTCLR clears it
--   T5  output compare, Output Mode 0 (Set/Reset)
--   T6  output compare, Output Mode 1 (Reset/Set)
--   T7  BTOUTEN = 0 freezes PWMout
--   T8  input capture: BTCAPR loads BTCNT, BTIFG fires with BTINT = 2
--   T9  BTCAPR readback over the bus
--
-- Run:  vsim -c -do SIM/RV32IMscMCU/bt_sim.do
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_BasicTimer is
end entity tb_BasicTimer;

architecture sim of tb_BasicTimer is

    constant W        : natural := 32;
    constant CLK_PER  : time    := 50 ns;   -- SMCLK = 20 MHz, as in the benchmarks

    -- register byte addresses, low 6 bits (io_map.s)
    constant A_BTCTL1  : std_logic_vector(5 downto 0) := "011100";  -- 0x201C
    constant A_BTCTL2  : std_logic_vector(5 downto 0) := "011101";  -- 0x201D
    constant A_BTCMPR0 : std_logic_vector(5 downto 0) := "100000";  -- 0x2020
    constant A_BTCMPR1 : std_logic_vector(5 downto 0) := "100100";  -- 0x2024
    constant A_BTCAPR  : std_logic_vector(5 downto 0) := "101000";  -- 0x2028

    -- BTCTL1 mask constants, straight out of io_map.s
    constant BTHOLD_BTCLR         : std_logic_vector(31 downto 0) := x"00000024";
    constant BTSSEL3              : std_logic_vector(31 downto 0) := x"00000018";
    constant BTOUTEN_BTSSEL3      : std_logic_vector(31 downto 0) := x"00000058";
    constant BTHOLD_BTCLR_BTINT2  : std_logic_vector(31 downto 0) := x"00000026";
    constant CAPMD1_CAPISEL3      : std_logic_vector(31 downto 0) := x"00000007";

    signal clk_s   : std_logic := '0';
    signal rst_s   : std_logic := '1';
    signal cs_s    : std_logic := '0';
    signal we_s    : std_logic := '0';
    signal addr_s  : std_logic_vector(5 downto 0)   := (others => '0');
    signal wdata_s : std_logic_vector(W-1 downto 0) := (others => '0');
    signal rdata_s : std_logic_vector(W-1 downto 0);

    signal capin1_s : std_logic := '0';
    signal capin2_s : std_logic := '0';
    signal pwm_s    : std_logic;
    signal btifg_s  : std_logic;

    signal sim_done : boolean := false;

begin

    ----------------------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------------------
    DUT : entity work.BasicTimer
        generic map (W => W)
        port map (
            clk       => clk_s,
            rst       => rst_s,
            cs        => cs_s,
            we        => we_s,
            addr      => addr_s,
            wdata     => wdata_s,
            rdata     => rdata_s,
            capin1    => capin1_s,
            capin2    => capin2_s,
            pwm_out   => pwm_s,
            btifg_evt => btifg_s
        );

    ----------------------------------------------------------------------------
    -- clock
    ----------------------------------------------------------------------------
    clk_gen : process
    begin
        while not sim_done loop
            clk_s <= '0';
            wait for CLK_PER / 2;
            clk_s <= '1';
            wait for CLK_PER / 2;
        end loop;
        wait;
    end process;

    ----------------------------------------------------------------------------
    -- stimulus + checks
    ----------------------------------------------------------------------------
    stim : process

        variable errors : natural := 0;

        procedure check (cond : boolean; msg : string) is
        begin
            if not cond then
                errors := errors + 1;
                report "FAIL: " & msg severity error;
            else
                report "pass: " & msg severity note;
            end if;
        end procedure;

        procedure bus_write (a : std_logic_vector(5 downto 0);
                             d : std_logic_vector(W-1 downto 0)) is
        begin
            addr_s  <= a;
            wdata_s <= d;
            cs_s    <= '1';
            we_s    <= '1';
            wait until rising_edge(clk_s);
            wait for 1 ns;
            cs_s <= '0';
            we_s <= '0';
        end procedure;

        procedure bus_read (a      :     std_logic_vector(5 downto 0);
                            result : out std_logic_vector(W-1 downto 0)) is
        begin
            addr_s <= a;
            cs_s   <= '1';
            we_s   <= '0';
            wait for 1 ns;
            result := rdata_s;
            cs_s   <= '0';
        end procedure;

        variable rv       : std_logic_vector(W-1 downto 0);
        variable t_rise   : time;
        variable t_fall   : time;
        variable t_next   : time;
        variable t_ifg1   : time;
        variable t_ifg2   : time;

    begin
        ------------------------------------------------------------------------
        report "=== Basic Timer testbench ===" severity note;

        rst_s <= '1';
        wait for 4 * CLK_PER;
        wait until rising_edge(clk_s);
        wait for 1 ns;
        rst_s <= '0';

        ------------------------------------------------------------------------
        -- T1: reset state
        ------------------------------------------------------------------------
        check(pwm_s = '0',   "T1 PWMout low after reset");
        check(btifg_s = '0' or btifg_s = '1', "T1 BTIFG resolved after reset");
        bus_read(A_BTCTL1, rv);
        check(rv = x"00000000", "T1 BTCTL1 reads 0 after reset");
        bus_read(A_BTCAPR, rv);
        check(rv = x"00000000", "T1 BTCAPR reads 0 after reset");

        ------------------------------------------------------------------------
        -- T2: compare mode, BTSSEL = 0.  BTCMPR0 = 9 -> BTCNT counts 0..9,
        --     so BTIFG must pulse every 10 SMCLK cycles.
        ------------------------------------------------------------------------
        bus_write(A_BTCTL1,  BTHOLD_BTCLR);            -- hold + clear
        bus_write(A_BTCMPR0, x"00000009");
        bus_write(A_BTCTL1,  x"00000000");             -- run, BTSSEL=0, BTINT=0

        wait until btifg_s = '1';
        t_ifg1 := now;
        wait until btifg_s = '0';
        wait until btifg_s = '1';
        t_ifg2 := now;
        check(t_ifg2 - t_ifg1 = 10 * CLK_PER,
              "T2 BTIFG period = 10 SMCLK (got " & time'image(t_ifg2 - t_ifg1) & ")");

        ------------------------------------------------------------------------
        -- T3: same period register, BTSSEL = 3 (SMCLK/8) -> 80 SMCLK cycles
        ------------------------------------------------------------------------
        bus_write(A_BTCTL1, BTHOLD_BTCLR);
        bus_write(A_BTCTL1, BTSSEL3);                  -- run, BTSSEL=3, BTINT=0

        wait until btifg_s = '1';
        t_ifg1 := now;
        wait until btifg_s = '0';
        wait until btifg_s = '1';
        t_ifg2 := now;
        check(t_ifg2 - t_ifg1 = 80 * CLK_PER,
              "T3 BTSSEL=3 divides by 8 (got " & time'image(t_ifg2 - t_ifg1) & ")");

        ------------------------------------------------------------------------
        -- T4: BTHOLD freezes the count; BTCLR clears it
        ------------------------------------------------------------------------
        bus_write(A_BTCTL1, x"00000020");              -- BTHOLD=1, BTSSEL=0
        wait for 30 * CLK_PER;
        check(btifg_s = '0', "T4 BTHOLD stops BTIFG");

        bus_write(A_BTCTL1, BTHOLD_BTCLR);             -- BTHOLD + BTCLR
        wait for 5 * CLK_PER;
        bus_write(A_BTCTL1, x"00000000");              -- release: restart from 0
        wait until btifg_s = '1';
        t_ifg1 := now;
        wait until btifg_s = '0';
        wait until btifg_s = '1';
        t_ifg2 := now;
        check(t_ifg2 - t_ifg1 = 10 * CLK_PER, "T4 restart after BTCLR keeps period");

        ------------------------------------------------------------------------
        -- T5: Output Compare, Output Mode 0 (Set/Reset), BTOUTMD = 0
        --     BTCL0 = 7 -> period 8 ticks (BTCNT 0..7)
        --     BTCL1 = 1 -> SET at BTCNT=1, RESET at BTCNT=7
        --     => PWMout high for BTCNT = 2..7, i.e. 6 of 8 cycles
        ------------------------------------------------------------------------
        bus_write(A_BTCTL1,  BTHOLD_BTCLR);
        bus_write(A_BTCMPR0, x"00000007");
        bus_write(A_BTCMPR1, x"00000001");
        bus_write(A_BTCTL1,  x"00000040");             -- BTOUTEN=1, BTOUTMD=0, BTSSEL=0

        wait until rising_edge(pwm_s);
        t_rise := now;
        wait until falling_edge(pwm_s);
        t_fall := now;
        wait until rising_edge(pwm_s);
        t_next := now;
        check(t_next - t_rise = 8 * CLK_PER,
              "T5 PWM period = 8 SMCLK (got " & time'image(t_next - t_rise) & ")");
        check(t_fall - t_rise = 6 * CLK_PER,
              "T5 Mode0 high time = 6 of 8 = (BTCL0-BTCL1)/BTCL0 (got "
              & time'image(t_fall - t_rise) & ")");

        ------------------------------------------------------------------------
        -- T6: Output Compare, Output Mode 1 (Reset/Set), BTOUTMD = 1
        --     Same registers => PWMout high for BTCNT = 0..1, i.e. 2 of 8 cycles
        ------------------------------------------------------------------------
        bus_write(A_BTCTL1, BTHOLD_BTCLR);
        bus_write(A_BTCTL1, x"000000C0");              -- BTOUTMD=1, BTOUTEN=1, BTSSEL=0

        wait until rising_edge(pwm_s);
        t_rise := now;
        wait until falling_edge(pwm_s);
        t_fall := now;
        wait until rising_edge(pwm_s);
        t_next := now;
        check(t_next - t_rise = 8 * CLK_PER,
              "T6 PWM period = 8 SMCLK (got " & time'image(t_next - t_rise) & ")");
        check(t_fall - t_rise = 2 * CLK_PER,
              "T6 Mode1 high time = 2 of 8 = BTCL1/BTCL0 (got "
              & time'image(t_fall - t_rise) & ")");

        ------------------------------------------------------------------------
        -- T7: BTOUTEN = 0 freezes PWMout at its current value
        ------------------------------------------------------------------------
        wait until rising_edge(pwm_s);
        wait for 1 ns;
        bus_write(A_BTCTL1, x"00000080");              -- BTOUTMD=1, BTOUTEN=0
        wait for 40 * CLK_PER;
        check(pwm_s = '1', "T7 BTOUTEN=0 holds PWMout at its last value");

        ------------------------------------------------------------------------
        -- T8: Input capture.  Free-running BTCNT (BTCMPR0 = 0xFFFFFFFF),
        --     BTINT = 2 so BTIFG comes from the capture event.
        --     Arm on GND (CAPISEL=3) then switch to VCC (CAPISEL=2) to make a
        --     rising edge -- this is what test4's capture_init/capture intend.
        ------------------------------------------------------------------------
        bus_write(A_BTCTL1,  BTHOLD_BTCLR_BTINT2);     -- hold + clear, BTINT=2
        bus_write(A_BTCMPR0, x"FFFFFFFF");
        bus_write(A_BTCTL2,  CAPMD1_CAPISEL3);         -- CAPMD=rising, CAPISEL=GND
        bus_write(A_BTCTL1,  x"00000002");             -- run, BTSSEL=0, BTINT=2

        wait for 25 * CLK_PER;                         -- let BTCNT advance
        bus_write(A_BTCTL2, x"00000006");              -- CAPMD=rising, CAPISEL=VCC

        wait until btifg_s = '1' for 20 * CLK_PER;
        check(btifg_s = '1', "T8 capture event raises BTIFG with BTINT=2");

        ------------------------------------------------------------------------
        -- T9: BTCAPR readback
        ------------------------------------------------------------------------
        wait for 4 * CLK_PER;
        bus_read(A_BTCAPR, rv);
        check(rv /= x"00000000", "T9 BTCAPR captured a non-zero BTCNT value");
        report "T9 BTCAPR = " & integer'image(to_integer(unsigned(rv))) severity note;

        ------------------------------------------------------------------------
        report "=== done, " & integer'image(errors) & " failure(s) ===" severity note;
        assert errors = 0
            report "TESTBENCH FAILED with " & integer'image(errors) & " error(s)"
            severity failure;

        sim_done <= true;
        wait;
    end process;

end architecture sim;
