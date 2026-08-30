--------------------------------------------------------------------------------
-- bt_regs.vhd
--
-- Basic Timer device-interface registers + bus decode.
-- These are the "Device Interface Registers" of Figure 1, for this peripheral:
--
--   Command : BTCTL1 (0x201C), BTCTL2 (0x201D)      - byte addressed
--   Out     : BTCMPR0 (0x2020), BTCMPR1 (0x2024)    - word addressed
--   In      : BTCAPR  (0x2028)                      - word addressed
--   Status  : BTIFG -- lives in the interrupt controller's IFG register, not here
--
-- Address decoding uses bits (5:0) of the DATA byte address, which uniquely
-- separate every Basic Timer register inside the 0x2000 I/O page:
--       BTCTL1  0x1C   BTCTL2  0x1D
--       BTCMPR0 0x20   BTCMPR1 0x24   BTCAPR 0x28
--
-- >>> Byte vs word writes <<<
-- The benchmarks store to BTCTL2 at 0x201D with a full "sw" - an UNALIGNED word
-- store by normal RISC-V rules.  I/O space here does not enforce alignment: the
-- peripheral decodes the BYTE address and captures wdata(7:0), exactly like the
-- 8-bit D-latches of Figure 5 that implement the HEX ports.  BTCMPR0/1 and
-- BTCAPR are true 32-bit registers and take the whole data bus
-- (SEC_PERIOD = 0x01312D00 would not fit in a byte).
--
-- >>> BTCL0 / BTCL1 <<<
-- Figure 7 shows "Latch BTCL0"/"Latch BTCL1" fed from BTCMPR0/BTCMPR1 with their
-- load input HEU0 tied to '1', and the spec says data written to BTCMPRx is
-- "automatically transferred" to BTCLx.  They are therefore transparent and
-- BTCLx simply tracks BTCMPRx.  They are kept as named signals so the RTL Viewer
-- picture matches Figure 7 for the report.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity bt_regs is
    generic (
        W : natural := 32
    );
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;                       -- async, active high

        -- CPU bus (data-memory side)
        cs      : in  std_logic;                       -- Basic Timer chip select
        we      : in  std_logic;                       -- MemWrite
        addr    : in  std_logic_vector(5 downto 0);    -- byte address (5:0)
        wdata   : in  std_logic_vector(W-1 downto 0);
        rdata   : out std_logic_vector(W-1 downto 0);

        -- to the timer datapath
        -- Port defaults so the value seen at time 0, delta 0 -- before the
        -- concurrent drivers below have run -- is 0 rather than 'U'.
        btctl1  : out std_logic_vector(7 downto 0)   := (others => '0');
        btctl2  : out std_logic_vector(7 downto 0)   := (others => '0');
        btcl0   : out std_logic_vector(W-1 downto 0) := (others => '0');
        btcl1   : out std_logic_vector(W-1 downto 0) := (others => '0');

        -- from the capture unit
        btcapr  : in  std_logic_vector(W-1 downto 0)
    );
end entity bt_regs;

architecture rtl of bt_regs is

    constant A_BTCTL1  : std_logic_vector(5 downto 0) := "011100";  -- 0x1C
    constant A_BTCTL2  : std_logic_vector(5 downto 0) := "011101";  -- 0x1D
    constant A_BTCMPR0 : std_logic_vector(5 downto 0) := "100000";  -- 0x20
    constant A_BTCMPR1 : std_logic_vector(5 downto 0) := "100100";  -- 0x24
    constant A_BTCAPR  : std_logic_vector(5 downto 0) := "101000";  -- 0x28

    constant ZEROS : std_logic_vector(W-1 downto 0) := (others => '0');

    signal ctl1_reg  : std_logic_vector(7 downto 0)   := (others => '0');
    signal ctl2_reg  : std_logic_vector(7 downto 0)   := (others => '0');
    signal cmpr0_reg : std_logic_vector(W-1 downto 0) := (others => '0');
    signal cmpr1_reg : std_logic_vector(W-1 downto 0) := (others => '0');

    signal wr : std_logic;

begin

    wr <= cs and we;

    process (clk, rst)
    begin
        if rst = '1' then
            ctl1_reg  <= (others => '0');
            ctl2_reg  <= (others => '0');
            cmpr0_reg <= (others => '0');
            cmpr1_reg <= (others => '0');
        elsif rising_edge(clk) then
            if wr = '1' then
                case addr is
                    when A_BTCTL1  => ctl1_reg  <= wdata(7 downto 0);
                    when A_BTCTL2  => ctl2_reg  <= wdata(7 downto 0);
                    when A_BTCMPR0 => cmpr0_reg <= wdata;
                    when A_BTCMPR1 => cmpr1_reg <= wdata;
                    when others    => null;   -- BTCAPR is written by the capture unit
                end case;
            end if;
        end if;
    end process;

    -- BTCTL2(7:4) are reserved, read as 0 (see the BTCTL2 register map).
    btctl1 <= ctl1_reg;
    btctl2 <= "0000" & ctl2_reg(3 downto 0);

    -- Transparent BTCL latches (HEU0 = '1' in Figure 7)
    btcl0 <= cmpr0_reg;
    btcl1 <= cmpr1_reg;

    -- Read mux.  Driven combinationally; the top-level bus mux qualifies it with
    -- the chip select, so no read strobe is needed here.
    process (addr, ctl1_reg, ctl2_reg, cmpr0_reg, cmpr1_reg, btcapr)
    begin
        case addr is
            when A_BTCTL1  => rdata <= ZEROS(W-1 downto 8) & ctl1_reg;
            when A_BTCTL2  => rdata <= ZEROS(W-1 downto 4) & ctl2_reg(3 downto 0);
            when A_BTCMPR0 => rdata <= cmpr0_reg;
            when A_BTCMPR1 => rdata <= cmpr1_reg;
            when A_BTCAPR  => rdata <= btcapr;
            when others    => rdata <= (others => '0');
        end case;
    end process;

end architecture rtl;
