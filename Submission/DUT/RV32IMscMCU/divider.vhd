--------------------------------------------------------------------------------
-- divider.vhd
-- Unsigned multicycle division accelerator (Figure 9) bundled with the full CDC
-- synchronizer (Figure 10), as ONE module.
--
-- THREE 2-FF synchronizers cross the slow (MCLK/CPU) -> fast (DIVCLK) boundary:
--   1) read_data1 -> Ain   (operand, Figure 10b)
--   2) read_data2 -> Bin   (operand, Figure 10b)
--   3) DIVENA     -> edge-detected start pulse (control)
--
-- Operands are safe through a plain 2-FF (no handshake/gray-code) ONLY because
-- the CPU holds them static for the whole divide (stalled on DIVBUSY); with a
-- non-changing value there is no bit-skew, so the 2-FF just absorbs metastability.
-- The start is not acted on until its own synchronizer fires, by which time the
-- operands have been stable for several DIVCLK cycles.
--
-- Divider core (Figure 9), shift-subtract (restoring):
--     Quotient = Dividend / Divisor        (unsigned)
--     Residue  = Dividend mod Divisor
--     Divide-by-zero (Divisor = 0) -> Quotient = all ones, Residue = Dividend.
--     Latency: N DIVCLK cycles once a start is captured; DIVBUSY high meanwhile.
--
-- Note: DIVBUSY leaves in the DIVCLK domain; its return path into MCLK is
-- synchronized on the CPU side (added at integration, P2).
--
-- No subprograms (functions/procedures) are used.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity divider is
    generic (
        N : positive := 32
    );
    port (
        DIVCLK     : in  std_logic;                        -- fast clock domain
        DIVRST     : in  std_logic;                        -- async reset, active high
        DIVENA     : in  std_logic;                        -- start (slow MCLK domain)
        read_data1 : in  std_logic_vector(N-1 downto 0);   -- operand rs1 (slow domain)
        read_data2 : in  std_logic_vector(N-1 downto 0);   -- operand rs2 (slow domain)
        Quotient   : out std_logic_vector(N-1 downto 0);
        Residue    : out std_logic_vector(N-1 downto 0);
        DIVBUSY    : out std_logic
    );
end entity divider;

architecture rtl of divider is

    -- ===== Operand synchronizers (Figure 10b): each is 2 FFs on DIVCLK =====
    signal rd1_meta : std_logic_vector(N-1 downto 0) := (others => '0');  -- Ds node
    signal ain      : std_logic_vector(N-1 downto 0) := (others => '0');  -- clean operand 1
    signal rd2_meta : std_logic_vector(N-1 downto 0) := (others => '0');  -- Ds node
    signal bin      : std_logic_vector(N-1 downto 0) := (others => '0');  -- clean operand 2

    -- ===== Enable synchronizer (2 FFs) + edge detector =====
    signal ena_meta    : std_logic := '0';   -- 1st FF (may be metastable)
    signal ena_sync    : std_logic := '0';   -- 2nd FF (clean, DIVCLK domain)
    signal ena_sync_d  : std_logic := '0';   -- delayed copy, for edge detect
    signal start_pulse : std_logic;          -- one-DIVCLK internal Load strobe

    -- ===== Divider core (Figure 9) =====
    type state_t is (IDLE, CALC);
    signal state  : state_t := IDLE;
    signal count  : natural range 0 to N := 0;

    signal rem_q  : unsigned(N-1 downto 0) := (others => '0');  -- remainder Y (upper half)
    signal dvnd_q : unsigned(N-1 downto 0) := (others => '0');  -- dividend shift-reg (lower half)
    signal quo_q  : unsigned(N-1 downto 0) := (others => '0');  -- quotient left shift-reg
    signal dsor_q : unsigned(N-1 downto 0) := (others => '0');  -- divisor register X

begin

    --==========================================================================
    -- 1) The three synchronizers (all FFs clocked by DIVCLK)
    --==========================================================================
    sync_proc : process (DIVCLK, DIVRST)
    begin
        if DIVRST = '1' then
            rd1_meta   <= (others => '0');
            ain        <= (others => '0');
            rd2_meta   <= (others => '0');
            bin        <= (others => '0');
            ena_meta   <= '0';
            ena_sync   <= '0';
            ena_sync_d <= '0';
        elsif rising_edge(DIVCLK) then
            -- operand synchronizers (read_data1 -> Ain, read_data2 -> Bin)
            rd1_meta <= read_data1;   ain <= rd1_meta;
            rd2_meta <= read_data2;   bin <= rd2_meta;
            -- enable synchronizer, plus one more FF for rising-edge detection
            ena_meta   <= DIVENA;
            ena_sync   <= ena_meta;
            ena_sync_d <= ena_sync;
        end if;
    end process;

    -- rising edge of the synchronized enable = a single Load strobe
    start_pulse <= ena_sync and (not ena_sync_d);

    --==========================================================================
    -- 2) Divider core: multicycle shift-subtract (restoring)
    --==========================================================================
    div_proc : process (DIVCLK, DIVRST)
        variable rem_shifted : unsigned(N-1 downto 0);
        variable sub         : unsigned(N downto 0);   -- extra bit holds the borrow
        variable qbit        : std_logic;
    begin
        if DIVRST = '1' then
            state   <= IDLE;
            count   <= 0;
            rem_q   <= (others => '0');
            dvnd_q  <= (others => '0');
            quo_q   <= (others => '0');
            dsor_q  <= (others => '0');
            DIVBUSY <= '0';

        elsif rising_edge(DIVCLK) then
            case state is

                when IDLE =>
                    DIVBUSY <= '0';
                    if start_pulse = '1' then
                        -- Load the SYNCHRONIZED operands (Figure 9 "Load").
                        -- RISC-V  div rd,rs1,rs2 => rd = rs1/rs2, so:
                        --   dividend = rs1 = read_data1 = Ain
                        --   divisor  = rs2 = read_data2 = Bin
                        -- (swap the two lines below if the course maps Ain=divisor)
                        rem_q   <= (others => '0');
                        dvnd_q  <= unsigned(ain);
                        dsor_q  <= unsigned(bin);
                        quo_q   <= (others => '0');
                        count   <= 0;
                        DIVBUSY <= '1';
                        state   <= CALC;
                    end if;

                when CALC =>
                    -- shift remainder left, pulling in the dividend MSB
                    rem_shifted := rem_q(N-2 downto 0) & dvnd_q(N-1);
                    -- trial subtraction: Result = Y - X
                    sub := ('0' & rem_shifted) - ('0' & dsor_q);

                    if sub(N) = '0' then           -- non-negative: Y >= X, keep result
                        rem_q <= sub(N-1 downto 0);
                        qbit  := '1';
                    else                           -- negative: restore old remainder
                        rem_q <= rem_shifted;
                        qbit  := '0';
                    end if;

                    dvnd_q <= dvnd_q(N-2 downto 0) & '0';   -- shift dividend left
                    quo_q  <= quo_q(N-2 downto 0) & qbit;   -- shift quotient bit in

                    if count = N-1 then
                        DIVBUSY <= '0';
                        state   <= IDLE;
                    end if;
                    count <= count + 1;

            end case;
        end if;
    end process;

    Quotient <= std_logic_vector(quo_q);
    Residue  <= std_logic_vector(rem_q);

end architecture rtl;
