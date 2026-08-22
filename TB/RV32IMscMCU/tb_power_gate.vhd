-- Gate-level power VCD testbench: drives the post-fit RV32I_CORE netlist.
-- 50 MHz into clk_i (the on-chip PLL divides to 25 MHz MCLK). Reset held through
-- PLL lock, then released so test1 (baked into the M9K ROM) runs.
library ieee;
use ieee.std_logic_1164.all;

entity tb_power_gate is
end entity tb_power_gate;

architecture sim of tb_power_gate is
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
begin
    CORE : entity work.RV32I_CORE
        port map ( clk_i => clk, rst_i => rst );   -- JTAG inputs default, outputs open

    clk <= not clk after 10 ns;    -- 20 ns period = 50 MHz PLL input
    rst <= '1', '0' after 3 us;    -- hold reset while the PLL locks, then run
end architecture sim;
