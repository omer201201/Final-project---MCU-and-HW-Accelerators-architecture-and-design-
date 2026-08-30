--------------------------------------------------------------------------------
-- cdc_sync.vhd
--
-- Clock-domain-crossing synchroniser -- project definition Figure 10b.
--
-- Figure 10a states the rule: a signal driven by combinational logic in the slow
-- domain A must first be REGISTERED in A before it is sent to the fast domain B,
-- and in B it must be registered again to avoid metastability. Figure 10b draws
-- the resulting structure: two flip-flops in the destination domain, per bit.
--
-- This block implements the destination-domain half (the two DFFs). It is used
-- three times in RV32I_CORE:
--
--   MCLK -> DIVCLK : the two 32-bit operands  (Figure 3's "Sync" box, whose
--                    outputs feed the divider's Ain/Bin)
--   MCLK -> DIVCLK : DIVENA, the start pulse
--   DIVCLK -> MCLK : DIVBUSY, the completion status back to div_stall_ctrl
--
-- >>> A note on synchronising a BUS <<<
-- Putting an independent 2-flop synchroniser on each bit of a bus is only safe
-- when the bus is STABLE across the crossing -- otherwise different bits can
-- resolve on different destination cycles and a torn value is captured. That
-- condition holds here, and it is what makes Figure 10b legitimate: the operands
-- come from the register file and do not change while the instruction is held in
-- execute by the divider stall. They are settled long before DIVENA is asserted
-- and stay settled until the divide retires. The start pulse and the busy flag
-- are single bits, so the question does not arise for them.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity cdc_sync is
    generic (
        W : positive := 1                       -- number of bits to synchronise
    );
    port (
        clk_i  : in  std_logic;                 -- DESTINATION domain clock
        rst_i  : in  std_logic;                 -- async, active high
        d_i    : in  std_logic_vector(W-1 downto 0);   -- from the source domain
        q_o    : out std_logic_vector(W-1 downto 0)    -- safe in the destination
    );
end entity cdc_sync;

architecture rtl of cdc_sync is
    -- stage 1 is the metastability catcher, stage 2 is the settled value.
    signal ff1 : std_logic_vector(W-1 downto 0) := (others => '0');
    signal ff2 : std_logic_vector(W-1 downto 0) := (others => '0');

    -- >>> Do NOT let the synthesiser turn these two stages into a shift register <<<
    -- ff1/ff2 is a 2-deep chain, and Quartus recognises 2-deep chains as altshift_taps
    -- and implements them in M9K memory. It did exactly that here: the three instances
    -- (32 + 32 + 1 bits) were merged into one 2 x 65 ALTSYNCRAM costing two M9K blocks.
    -- That is wrong for a synchroniser. The whole point of stage 1 is that a metastable
    -- sample lands in a DEDICATED FLIP-FLOP and is given a full destination-clock period
    -- to resolve; a RAM cell read back through an address counter does not provide that
    -- guarantee. Figure 10b draws two flip-flops, so two flip-flops is what must be built.
    attribute altera_attribute : string;
    attribute altera_attribute of rtl : architecture is
        "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
begin

    process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            ff1 <= (others => '0');
            ff2 <= (others => '0');
        elsif rising_edge(clk_i) then
            ff1 <= d_i;
            ff2 <= ff1;
        end if;
    end process;

    q_o <= ff2;

end architecture rtl;
