--============================================================================
-- intr_ctrl.vhd  -  Basic Interrupt Controller (P4b) -- STANDALONE peripheral.
--
-- Does NOT touch the CPU. It is a peripheral on the MMIO bus plus an INTR/INTA
-- handshake pair, exactly the "Basic Interrupt Controller (IE, IFG, TYPE)" box.
--
-- Registers (low 6 bits of the byte address):
--   IE   0x202C (0x2C)  rw  interrupt enable  (mask)
--   IFG  0x202D (0x2D)  rw  interrupt flags   (pending)   -- write to clear
--   TYPE 0x202E (0x2E)  ro  vector of the acknowledged interrupt
--
-- 6 maskable sources, one bit each (priority: bit 0 highest .. bit 5 lowest):
--   bit  0    1    2    3     4     5
--        RX   TX   BT   KEY1  KEY2  KEY3
--   TYPE(i) = i*4 + 8  ->  RX 0x08, TX 0x0C, BT 0x10, KEY1 0x14,
--                          KEY2 0x18, KEY3 0x1C          (word-aligned vectors)
--   (RESET/NMI 0x00 is non-maskable and handled by the CPU, not here.)
--
-- Flow (the block decomposition, in HDL):
--   [B] each source pulse sets a STICKY flag (IFG); flags survive until cleared
--   [C] mask   : pend = IFG and IE
--   [D] priority: lowest set index wins
--   [E] TYPE    : winner's vector, snapshotted into TYPE on INTA
--   [F] INTR    : registered "any enabled-pending"
--   [G] INTA    : CPU acknowledge -> snapshot TYPE + auto-clear the winner flag
--   (software may also clear a flag by writing 0 to its IFG bit)
--
-- Source inputs are expected to be SYNCHRONOUS 1-cycle pulses (BT already is;
-- KEY presses get edge-detected/synced before this block at integration).
-- INTA here is active-high for readable logic; the spec's INTA is active-LOW,
-- so invert it at CPU integration (or drive inta_i = not INTA_n).
--============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity intr_ctrl is
    generic (
        DATA_WIDTH : integer := 32
    );
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;                                  -- async, active high
        -- ---- CPU bus (peripheral register access) ----
        cs_i    : in  std_logic;                                  -- controller chip-select
        we_i    : in  std_logic;                                  -- MemWrite
        addr_i  : in  std_logic_vector(5 downto 0);
        wdata_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        rdata_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
        -- ---- interrupt sources: synchronous 1-cycle pulses ----
        src_i   : in  std_logic_vector(5 downto 0);               -- [0]RX [1]TX [2]BT [3]KEY1 [4]KEY2 [5]KEY3
        -- ---- CPU handshake ----
        intr_o  : out std_logic;                                  -- request (active high)
        inta_i  : in  std_logic                                   -- acknowledge pulse (active high; spec is active-low)
    );
end entity intr_ctrl;

architecture rtl of intr_ctrl is

    constant A_IE   : std_logic_vector(5 downto 0) := "101100"; -- 0x2C
    constant A_IFG  : std_logic_vector(5 downto 0) := "101101"; -- 0x2D
    constant A_TYPE : std_logic_vector(5 downto 0) := "101110"; -- 0x2E

    signal ie_reg   : std_logic_vector(5 downto 0) := (others => '0');
    signal ifg_reg  : std_logic_vector(5 downto 0) := (others => '0');
    signal type_reg : std_logic_vector(7 downto 0) := (others => '0');

    signal pend     : std_logic_vector(5 downto 0);
    signal win_idx  : integer range 0 to 5;
    signal win_val  : std_logic;                                 -- any enabled-pending
    signal win_type : std_logic_vector(7 downto 0);

    signal intr_q   : std_logic := '0';
    signal wr       : std_logic;

begin

    wr   <= cs_i and we_i;

    ----------------------------------------------------------------------------
    -- [C] mask
    ----------------------------------------------------------------------------
    pend <= ifg_reg and ie_reg;

    ----------------------------------------------------------------------------
    -- [D] priority encoder : lowest set index wins (bit 0 highest priority)
    ----------------------------------------------------------------------------
    prio : process (pend)
        variable idx : integer range 0 to 5;
        variable val : std_logic;
    begin
        idx := 0; val := '0';
        for i in 5 downto 0 loop           -- last write (i=0) wins -> bit 0 highest
            if pend(i) = '1' then
                idx := i; val := '1';
            end if;
        end loop;
        win_idx <= idx;
        win_val <= val;
    end process;

    ----------------------------------------------------------------------------
    -- [E] TYPE of the current winner :  index*4 + 8
    ----------------------------------------------------------------------------
    win_type <= std_logic_vector(to_unsigned(win_idx * 4 + 8, 8)) when win_val = '1'
                else x"00";

    ----------------------------------------------------------------------------
    -- IE register
    ----------------------------------------------------------------------------
    ie_p : process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            ie_reg <= (others => '0');
        elsif rising_edge(clk_i) then
            if wr = '1' and addr_i = A_IE then
                ie_reg <= wdata_i(5 downto 0);
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- [B] IFG flags : set by source pulse (dominant), software write, or
    --     auto-clear the acknowledged winner on INTA.
    ----------------------------------------------------------------------------
    ifg_p : process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            ifg_reg <= (others => '0');
        elsif rising_edge(clk_i) then
            for i in 0 to 5 loop
                if src_i(i) = '1' then
                    ifg_reg(i) <= '1';                                    -- capture the event (never miss it)
                elsif wr = '1' and addr_i = A_IFG then
                    ifg_reg(i) <= wdata_i(i);                             -- software clear/set
                elsif inta_i = '1' and win_val = '1' and i = win_idx and i <= 2 then
                    ifg_reg(i) <= '0';                                    -- ack auto-clears ONLY synchronous sources (RX/TX/BT); KEYs are software-cleared
                end if;
            end loop;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- [E] TYPE register : snapshot the winner's vector when the CPU acknowledges
    ----------------------------------------------------------------------------
    type_p : process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            type_reg <= (others => '0');
        elsif rising_edge(clk_i) then
            if inta_i = '1' and win_val = '1' then
                type_reg <= win_type;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- [F] INTR : registered "any enabled-pending" (clean, glitch-free)
    ----------------------------------------------------------------------------
    intr_p : process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            intr_q <= '0';
        elsif rising_edge(clk_i) then
            intr_q <= win_val;
        end if;
    end process;
    intr_o <= intr_q;

    ----------------------------------------------------------------------------
    -- read mux
    ----------------------------------------------------------------------------
    rd_p : process (addr_i, ie_reg, ifg_reg, type_reg, inta_i, win_type)
    begin
        if inta_i = '1' then
            -- spec (p.15): during INTA the controller drives the winner's TYPE
            -- onto the data bus, and the CPU captures it into a dedicated register.
            rdata_o <= std_logic_vector(resize(unsigned(win_type), DATA_WIDTH));
        else
            case addr_i is
                when A_IE   => rdata_o <= std_logic_vector(resize(unsigned(ie_reg),   DATA_WIDTH));
                when A_IFG  => rdata_o <= std_logic_vector(resize(unsigned(ifg_reg),  DATA_WIDTH));
                when A_TYPE => rdata_o <= std_logic_vector(resize(unsigned(type_reg), DATA_WIDTH));
                when others => rdata_o <= (others => '0');
            end case;
        end if;
    end process;

end architecture rtl;
