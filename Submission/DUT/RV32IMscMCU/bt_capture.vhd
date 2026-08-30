--------------------------------------------------------------------------------
-- bt_capture.vhd
--
-- Basic Timer Input Capture unit (Figure 7, BTCTL2).
--
--   CAPISEL (BTCTL2(1:0)) - capture source
--       00 : CAPIN1 external input pin
--       01 : CAPIN2 external input pin
--       10 : VCC ('1')
--       11 : GND ('0')
--
--   CAPMD (BTCTL2(3:2)) - trigger
--       00 : capture disabled
--       01 : rising edge
--       10 : falling edge
--       11 : capture disabled
--
-- On a qualifying edge, BTCNT is copied into BTCAPR and cap_evt pulses for one
-- cycle (this is the third BTINT source in Figure 7).
--
-- CAPIN1/CAPIN2 arrive from board pins and are asynchronous to SMCLK, so the
-- selected source is passed through a two-flop synchroniser before edge
-- detection.  That also removes the glitch that would otherwise be produced when
-- software switches CAPISEL between sources - which is precisely how the
-- benchmark intends to fire a capture (arm on GND, then select VCC).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity bt_capture is
    generic (
        W : natural := 32
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;                       -- async, active high
        capisel : in  std_logic_vector(1 downto 0);    -- BTCTL2(1:0)
        capmd   : in  std_logic_vector(1 downto 0);    -- BTCTL2(3:2)
        capin1  : in  std_logic;
        capin2  : in  std_logic;
        btcnt   : in  std_logic_vector(W-1 downto 0);
        btcapr  : out std_logic_vector(W-1 downto 0);
        cap_evt : out std_logic                        -- one-cycle pulse
    );
end entity bt_capture;

architecture rtl of bt_capture is
    signal src      : std_logic;
    signal sync_q   : std_logic_vector(2 downto 0)   := (others => '0');  -- 2FF sync + edge history
    signal evt      : std_logic;
    signal capr_reg : std_logic_vector(W-1 downto 0) := (others => '0');
begin

    -- CAPISEL source multiplexer
    with capisel select
        src <= capin1 when "00",
               capin2 when "01",
               '1'    when "10",
               '0'    when others;

    -- Two-flop synchroniser (sync_q(1)) plus one delay stage (sync_q(2)) so the
    -- edge detector compares two adjacent synchronised samples.
    process (clk, rst)
    begin
        if rst = '1' then
            sync_q <= (others => '0');
        elsif rising_edge(clk) then
            sync_q <= sync_q(1 downto 0) & src;
        end if;
    end process;

    with capmd select
        evt <= (    sync_q(1) and not sync_q(2)) when "01",  -- rising
               (not sync_q(1) and     sync_q(2)) when "10",  -- falling
               '0'                               when others; -- disabled

    process (clk, rst)
    begin
        if rst = '1' then
            capr_reg <= (others => '0');
        elsif rising_edge(clk) then
            if evt = '1' then
                capr_reg <= btcnt;
            end if;
        end if;
    end process;

    btcapr  <= capr_reg;
    cap_evt <= evt;

end architecture rtl;
