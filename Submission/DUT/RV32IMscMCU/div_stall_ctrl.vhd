--------------------------------------------------------------------------------
-- div_stall_ctrl.vhd
-- Stall controller for the multicycle divider ("Divctrl" brain).
--
-- For a div/rem instruction it:
--   * pulses DIVENA once to start the divider,
--   * holds STALL high for the WHOLE divide -- including the startup window
--     before DIVBUSY rises -- and drops STALL on the single completion cycle,
--     so the PC advances and the result is written back exactly once.
--
-- Why an FSM (not just "STALL = DIVBUSY"): at BOTH "just detected" and
-- "just finished" DIVBUSY = 0. A state bit (seen_busy) distinguishes the two.
--
-- STALL drives IFETCH.pc_hold and the RegWrite gate (same signal for both).
-- divbusy_i must already be in THIS clock domain (single-clock now; add a
-- 2-FF sync on the divider's DIVBUSY when MCLK and DIVCLK differ).
--
-- No subprograms (functions/procedures) are used.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity div_stall_ctrl is
    port (
        clk_i       : in  std_logic;
        rst_i       : in  std_logic;
        div_instr_i : in  std_logic;   -- current instruction is div or rem
        divbusy_i   : in  std_logic;   -- from the divider (this clock domain)
        divena_o    : out std_logic;   -- one-cycle start pulse to the divider
        stall_o     : out std_logic    -- -> pc_hold and RegWrite gate
    );
end entity div_stall_ctrl;

architecture rtl of div_stall_ctrl is
    type state_t is (IDLE, RUN);
    signal dstate     : state_t   := IDLE;
    signal seen_busy  : std_logic := '0';   -- have we seen DIVBUSY high this divide?
    signal completion : std_logic;          -- RUN and the divide just finished
begin

    -- completion = we were running, saw DIVBUSY high, and it has now dropped
    completion <= '1' when (dstate = RUN and seen_busy = '1' and divbusy_i = '0')
                  else '0';

    process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            dstate    <= IDLE;
            seen_busy <= '0';
        elsif rising_edge(clk_i) then
            case dstate is
                when IDLE =>
                    seen_busy <= '0';                 -- fresh start for the next divide
                    if div_instr_i = '1' then
                        dstate <= RUN;
                    end if;
                when RUN =>
                    if divbusy_i = '1' then
                        seen_busy <= '1';             -- remember the divide is really underway
                    end if;
                    if completion = '1' then
                        dstate <= IDLE;
                    end if;
            end case;
        end if;
    end process;

    -- one-cycle start pulse when a new div/rem is seen (only in IDLE)
    divena_o <= '1' when (dstate = IDLE and div_instr_i = '1') else '0';

    -- stall from detection, through the startup window and RUN,
    -- dropping on the completion cycle
    stall_o  <= '1' when (dstate = IDLE and div_instr_i = '1') else
                '1' when (dstate = RUN  and completion = '0')  else
                '0';

end architecture rtl;
