--------------------------------------------------------------------------------
-- bt_prescaler.vhd
--
-- Basic Timer source-clock selector (BTSSEL), Figure 7.
--
-- Figure 7 draws a 4:1 clock multiplexer selecting SMCLK / {1,2,4,8} as the
-- BTCNT clock.  On an FPGA a combinational clock mux creates a derived clock
-- with uncontrolled skew and forces Quartus to route it off the global clock
-- network, which hurts fmax and makes the .sdc constraints messy.  The
-- functionally identical, synthesis-clean form is used instead: BTCNT stays on
-- SMCLK and this block produces a one-cycle clock ENABLE ("tick") at the
-- selected rate.  Behaviour at the BTCNT output is bit-for-bit the same.
--
--   BTSSEL = 00 -> SMCLK      (tick every cycle)
--   BTSSEL = 01 -> SMCLK / 2
--   BTSSEL = 10 -> SMCLK / 4
--   BTSSEL = 11 -> SMCLK / 8
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bt_prescaler is
    port (
        clk    : in  std_logic;                     -- SMCLK
        rst    : in  std_logic;                     -- async, active high
        clr    : in  std_logic;                     -- BTCLR: restart phase
        btssel : in  std_logic_vector(1 downto 0);  -- BTCTL1(4:3)
        tick   : out std_logic                      -- one-cycle clock enable
    );
end entity bt_prescaler;

architecture rtl of bt_prescaler is
    signal cnt : unsigned(2 downto 0);
begin

    process (clk, rst)
    begin
        if rst = '1' then
            cnt <= (others => '0');
        elsif rising_edge(clk) then
            if clr = '1' then
                cnt <= (others => '0');
            else
                cnt <= cnt + 1;
            end if;
        end if;
    end process;

    -- cnt(0)                     is high 1 cycle in 2
    -- cnt(0) and cnt(1)          is high 1 cycle in 4
    -- cnt(0) and cnt(1) and c(2) is high 1 cycle in 8
    with btssel select
        tick <= '1'                                  when "00",
                cnt(0)                               when "01",
                cnt(0) and cnt(1)                    when "10",
                cnt(0) and cnt(1) and cnt(2)         when others;

end architecture rtl;
