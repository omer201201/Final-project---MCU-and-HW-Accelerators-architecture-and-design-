--------------------------------------------------------------------------------
-- bt_output_unit.vhd
--
-- Basic Timer Output Unit: PWM generation in Output Compare Mode (Figure 8).
--
-- Read straight off Figure 8, where the ramp runs 0 -> BTCL1 -> BTCL0 -> wrap:
--
--   Output Mode 0 ("Set/Reset",  BTOUTMD = '0')
--       SET   (high) when BTCNT reaches BTCL1   -> EUQ1
--       RESET (low)  when BTCNT reaches BTCL0   -> EUQ0
--       high fraction = (BTCL0 - BTCL1) / BTCL0
--
--   Output Mode 1 ("Reset/Set",  BTOUTMD = '1')
--       RESET (low)  when BTCNT reaches BTCL1   -> EUQ1
--       SET   (high) when BTCNT reaches BTCL0   -> EUQ0
--       high fraction = BTCL1 / BTCL0
--
-- Both collapse to the single assignment below:
--       on EUQ0 -> PWMout <=     BTOUTMD
--       on EUQ1 -> PWMout <= not BTOUTMD
--
-- >>> Polarity note for the report / demo <<<
-- Benchmark "Intrrupt-based IO/test4" (01_func.s : bt_outcmp_config) selects
-- BTOUTMD = '0' (Mode 0) via BTOUTEN_BTSSEL3 = 0x58, then writes
-- BTCMPR1 = BTCMPR0 >> k and comments the result as duty = 2^-k.  Under
-- Figure 8 Mode 0 the measured HIGH fraction is 1 - 2^-k, i.e. the complement
-- (they agree only for k = 1, the 0.5 case).  The comment matches Mode 1.
-- This RTL implements the FIGURE, which is the normative source and is
-- unambiguous at full zoom.  See DOC note - worth confirming with the
-- instructor before the demo, since a scope trace makes the difference obvious.
--
-- BTOUTEN ("hold the PWMout signal value"): '1' lets the output follow the
-- compare events, '0' freezes it at its current value.  This orientation is
-- forced by the benchmark, which asserts BTOUTEN when it wants PWM out.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity bt_output_unit is
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;   -- async, active high
        euq0    : in  std_logic;   -- pulse: BTCNT reached BTCL0 (wrap)
        euq1    : in  std_logic;   -- pulse: BTCNT reached BTCL1
        btouten : in  std_logic;   -- BTCTL1(6)
        btoutmd : in  std_logic;   -- BTCTL1(7)
        pwm_out : out std_logic
    );
end entity bt_output_unit;

architecture rtl of bt_output_unit is
    signal q : std_logic;
begin

    process (clk, rst)
    begin
        if rst = '1' then
            q <= '0';
        elsif rising_edge(clk) then
            if btouten = '1' then
                -- EUQ0 (the wrap) wins if both land on the same tick, which
                -- happens when software programs BTCL1 >= BTCL0.
                if euq0 = '1' then
                    q <= btoutmd;
                elsif euq1 = '1' then
                    q <= not btoutmd;
                end if;
            end if;
        end if;
    end process;

    pwm_out <= q;

end architecture rtl;
