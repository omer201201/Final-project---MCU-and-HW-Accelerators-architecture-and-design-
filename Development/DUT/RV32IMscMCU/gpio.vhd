--============================================================================
-- gpio.vhd  -  General-Purpose I/O (P3, MMIO)
--   Outputs (GPO): PORT_LEDR (8-bit reg) + PORT_HEX0..5 (6x 4-bit reg -> seg7)
--   Inputs  (GPI): PORT_SW / PORT_PB pins -> read-data mux
--
-- Output registers are clock-enabled flip-flops (they HOLD unless their write
-- strobe is high, NOT gated clocks); reset (active-high) clears them. Inputs
-- have no state: the selected pins are zero-extended onto rdata_o. Output ports
-- read back as 0 for now (read-back deferred).
--
-- Decode/gating stays in bus_interface; this block receives ready-made write
-- strobes (we_*) and read selects (sel_*).
--============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity gpio is
    generic (
        DATA_WIDTH : integer := 32
    );
    port (
        clk_i     : in  std_logic;
        rst_i     : in  std_logic;                       -- active high
        -- ---- write side (GPO) ----
        wdata_i   : in  std_logic_vector(7 downto 0);    -- store byte from CPU
        we_ledr_i : in  std_logic;                       -- LEDR write strobe
        we_hex_i  : in  std_logic_vector(5 downto 0);    -- per-HEX write strobes
        -- ---- read side (GPI) ----
        sel_sw_i  : in  std_logic;                       -- reading PORT_SW ?
        sel_pb_i  : in  std_logic;                       -- reading PORT_PB ?
        rdata_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);  -- GPI read data
        -- ---- board pins ----
        SW_i      : in  std_logic_vector(7 downto 0);
        PB_i      : in  std_logic_vector(2 downto 0);
        LEDR_o    : out std_logic_vector(7 downto 0);
        HEX0_o    : out std_logic_vector(6 downto 0);
        HEX1_o    : out std_logic_vector(6 downto 0);
        HEX2_o    : out std_logic_vector(6 downto 0);
        HEX3_o    : out std_logic_vector(6 downto 0);
        HEX4_o    : out std_logic_vector(6 downto 0);
        HEX5_o    : out std_logic_vector(6 downto 0)
    );
end entity gpio;

architecture rtl of gpio is

    component seg7 is
        port (
            nibble_i : in  std_logic_vector(3 downto 0);
            seg_o    : out std_logic_vector(6 downto 0)
        );
    end component;

    type nibble_array is array (0 to 5) of std_logic_vector(3 downto 0);
    type seg_array    is array (0 to 5) of std_logic_vector(6 downto 0);

    signal ledr_q  : std_logic_vector(7 downto 0);
    signal hex_q   : nibble_array;
    signal hex_seg : seg_array;

begin

    ----------------------------------------------------------------------------
    -- GPO : PORT_LEDR - one clock-enabled output register
    ----------------------------------------------------------------------------
    process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            ledr_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if we_ledr_i = '1' then
                ledr_q <= wdata_i;          -- latch on write, else hold
            end if;
        end if;
    end process;

    LEDR_o <= ledr_q;

    ----------------------------------------------------------------------------
    -- GPO : PORT_HEX0..5 - six clock-enabled 4-bit registers -> Lab 4 seg7
    ----------------------------------------------------------------------------
    gen_hex : for i in 0 to 5 generate
        process (clk_i, rst_i)
        begin
            if rst_i = '1' then
                hex_q(i) <= (others => '0');
            elsif rising_edge(clk_i) then
                if we_hex_i(i) = '1' then
                    hex_q(i) <= wdata_i(3 downto 0);
                end if;
            end if;
        end process;

        U_SEG : seg7 port map (nibble_i => hex_q(i), seg_o => hex_seg(i));
    end generate gen_hex;

    HEX0_o <= hex_seg(0);
    HEX1_o <= hex_seg(1);
    HEX2_o <= hex_seg(2);
    HEX3_o <= hex_seg(3);
    HEX4_o <= hex_seg(4);
    HEX5_o <= hex_seg(5);

    ----------------------------------------------------------------------------
    -- GPI : PORT_SW / PORT_PB - no state, selected pins zero-extended to rdata_o
    ----------------------------------------------------------------------------
    rdata_o <= std_logic_vector(resize(unsigned(SW_i), DATA_WIDTH)) when sel_sw_i = '1' else
               std_logic_vector(resize(unsigned(PB_i), DATA_WIDTH)) when sel_pb_i = '1' else
               (others => '0');

end architecture rtl;
