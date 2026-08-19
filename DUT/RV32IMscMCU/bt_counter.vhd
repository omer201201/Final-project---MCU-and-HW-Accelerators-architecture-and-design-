--------------------------------------------------------------------------------
-- bt_counter.vhd
--
-- BTCNT: the 32-bit Basic Timer core counter, Up-Mode (Figures 7 and 8).
--
-- Up-Mode semantics, taken from Figure 8: the counter ramps 0 -> BTCL0 and then
-- wraps back to 0, so BTCL0 is the PERIOD register.  BTR(max) in Figure 8 is the
-- full-scale 32-bit value, which Up-Mode never reaches unless BTCL0 is set to it
-- (which is exactly what the test4 capture path does: BTCMPR0 = 0xFFFFFFFF).
--
-- Controls (BTCTL1):
--   BTCLR  - level.  While asserted BTCNT is held cleared.  It is NOT
--            self-clearing: the benchmark writes BTHOLD+BTCLR and later writes a
--            different BTCTL1 value to release both, so a level is the correct
--            reading of "reset the content of the BTCNT register".
--   BTHOLD - level.  Drives the active-low EN of BTCNT in Figure 7, so
--            BTHOLD = '1' freezes the count, BTHOLD = '0' runs it.
--
-- Event outputs are ONE-CYCLE PULSES, not levels:
--   EUQ0 - BTCNT reached BTCL0 (the wrap instant)
--   EUQ1 - BTCNT reached BTCL1
-- Pulses are what both consumers want: the output unit needs edges, and the
-- interrupt controller (Figure 13) clocks a set-only flip-flop from the source.
--
-- Degenerate case: BTCL0 = 0 (the reset value) makes the wrap condition true at
-- every enabled tick, so BTCNT stays at 0 and EUQ0 pulses continuously.  This is
-- the literal reading of the figure and is harmless in practice - BTIE is 0 out
-- of reset, and every benchmark writes BTCMPR0 before enabling the timer.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bt_counter is
    generic (
        W : natural := 32
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;                       -- async, active high
        tick   : in  std_logic;                       -- from bt_prescaler
        btclr  : in  std_logic;                       -- BTCTL1(2)
        bthold : in  std_logic;                       -- BTCTL1(5)
        btcl0  : in  std_logic_vector(W-1 downto 0);  -- period  latch
        btcl1  : in  std_logic_vector(W-1 downto 0);  -- compare latch
        btcnt  : out std_logic_vector(W-1 downto 0);
        euq0   : out std_logic;                       -- pulse: reached BTCL0
        euq1   : out std_logic                        -- pulse: reached BTCL1
    );
end entity bt_counter;

architecture rtl of bt_counter is
    -- Initialisers keep the time-0 delta clean (no NUMERIC_STD metavalue warnings
    -- in the ModelSim transcript before the async reset propagates).
    signal cnt : unsigned(W-1 downto 0) := (others => '0');
    signal ena : std_logic;
    signal at0 : std_logic;
    signal at1 : std_logic;
begin

    ena <= tick and (not bthold);

    -- ">=" rather than "=" so the counter still recovers if software shrinks
    -- BTCMPR0 below the current count while the timer is running.
    at0 <= '1' when cnt >= unsigned(btcl0) else '0';
    at1 <= '1' when cnt  = unsigned(btcl1) else '0';

    euq0 <= ena and at0;
    euq1 <= ena and at1;

    process (clk, rst)
    begin
        if rst = '1' then
            cnt <= (others => '0');
        elsif rising_edge(clk) then
            if btclr = '1' then
                cnt <= (others => '0');
            elsif ena = '1' then
                if at0 = '1' then
                    cnt <= (others => '0');
                else
                    cnt <= cnt + 1;
                end if;
            end if;
        end if;
    end process;

    btcnt <= std_logic_vector(cnt);

end architecture rtl;
