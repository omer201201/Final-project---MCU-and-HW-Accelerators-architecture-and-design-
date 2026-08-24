--============================================================================
-- bus_interface.vhd  -  Memory-Mapped I/O bus hub (P3)
--
-- The single new block the CPU talks to. It owns the bus mechanisms:
--
--   1. level-1 decode : is_peripheral  (byte address >= 0x2000)
--   2. write gating    : dtcm_we / per-port peripheral write-enables
--   3. level-2 decode  : one-hot chip-selects  (the "Optimized Address Decoder")
--   4. read-return mux : peripheral read data vs DTCM read data
--
-- It instantiates gpio (LEDR + HEX0-5 outputs AND SW/PB input mux). The input
-- read (GPI) now lives inside gpio; bus_interface just hands it the read
-- selects and muxes its rdata against DTCM. Reads are side-effect free, so the
-- read mux is never gated by MemRead: IDECODE's MemtoReg decides if it is used.
--============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity bus_interface is
    generic (
        DATA_WIDTH : integer := 32
    );
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;                               -- active high
        -- ---- CPU side ----
        addr_i       : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- alu_res_w (byte address)
        wdata_i      : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- read_data2_w (store data)
        mem_write_i  : in  std_logic;                               -- CONTROL MemWrite
        dtcm_rdata_i : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- DTCM read data
        dtcm_we_o    : out std_logic;                               -- gated DTCM write-enable
        rdata_o      : out std_logic_vector(DATA_WIDTH-1 downto 0); -- -> IDECODE dtcm_data_rd_i
        -- ---- board pins ----
        SW_i         : in  std_logic_vector(7 downto 0);            -- PORT_SW  (GPI)
        PB_i         : in  std_logic_vector(2 downto 0);            -- PORT_PB  (GPI, KEY3..1)
        LEDR_o       : out std_logic_vector(7 downto 0);            -- PORT_LEDR
        HEX0_o       : out std_logic_vector(6 downto 0);
        HEX1_o       : out std_logic_vector(6 downto 0);
        HEX2_o       : out std_logic_vector(6 downto 0);
        HEX3_o       : out std_logic_vector(6 downto 0);
        HEX4_o       : out std_logic_vector(6 downto 0);
        HEX5_o       : out std_logic_vector(6 downto 0)
    );
end entity bus_interface;

architecture rtl of bus_interface is

    component gpio is
        generic ( DATA_WIDTH : integer := 32 );
        port (
            clk_i     : in  std_logic;
            rst_i     : in  std_logic;
            wdata_i   : in  std_logic_vector(7 downto 0);
            we_ledr_i : in  std_logic;
            we_hex_i  : in  std_logic_vector(5 downto 0);
            sel_sw_i  : in  std_logic;
            sel_pb_i  : in  std_logic;
            rdata_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
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
    end component;

    -- MMIO byte-address offsets within the peripheral page (low 6 bits).
    -- (see Benchmark apps/GPIO/.../io_map.s -- these are the given, fixed addresses)
    constant OFF_LEDR : std_logic_vector(5 downto 0) := "000000"; -- 0x2000
    constant OFF_HEX0 : std_logic_vector(5 downto 0) := "000100"; -- 0x2004
    constant OFF_HEX1 : std_logic_vector(5 downto 0) := "000101"; -- 0x2005
    constant OFF_HEX2 : std_logic_vector(5 downto 0) := "001000"; -- 0x2008
    constant OFF_HEX3 : std_logic_vector(5 downto 0) := "001001"; -- 0x2009
    constant OFF_HEX4 : std_logic_vector(5 downto 0) := "001100"; -- 0x200C
    constant OFF_HEX5 : std_logic_vector(5 downto 0) := "001101"; -- 0x200D
    constant OFF_SW   : std_logic_vector(5 downto 0) := "010000"; -- 0x2010
    constant OFF_PB   : std_logic_vector(5 downto 0) := "010100"; -- 0x2014

    signal is_peripheral : std_logic;
    signal off           : std_logic_vector(5 downto 0);

    signal cs_ledr : std_logic;
    signal cs_hex  : std_logic_vector(5 downto 0);
    signal cs_sw   : std_logic;
    signal cs_pb   : std_logic;

    signal we_ledr : std_logic;
    signal we_hex  : std_logic_vector(5 downto 0);

    signal periph_rdata : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    off <= addr_i(5 downto 0);

    ----------------------------------------------------------------------------
    -- (1) level-1 decode : robust "address >= 0x2000" (any bit at/above 0x2000)
    ----------------------------------------------------------------------------
    -- >= 0x2000 via a 3-input OR (bits 15:13). Kept deliberately narrow: this
    -- signal gates the DTCM write-enable, which sits on the single-cycle store
    -- critical path -- a wide OR-reduce here costs setup slack.
    is_peripheral <= addr_i(15) or addr_i(14) or addr_i(13);

    ----------------------------------------------------------------------------
    -- (3) level-2 decode : one-hot chip-selects (Optimized Address Decoder)
    ----------------------------------------------------------------------------
    cs_ledr   <= '1' when (is_peripheral = '1' and off = OFF_LEDR) else '0';
    cs_hex(0) <= '1' when (is_peripheral = '1' and off = OFF_HEX0) else '0';
    cs_hex(1) <= '1' when (is_peripheral = '1' and off = OFF_HEX1) else '0';
    cs_hex(2) <= '1' when (is_peripheral = '1' and off = OFF_HEX2) else '0';
    cs_hex(3) <= '1' when (is_peripheral = '1' and off = OFF_HEX3) else '0';
    cs_hex(4) <= '1' when (is_peripheral = '1' and off = OFF_HEX4) else '0';
    cs_hex(5) <= '1' when (is_peripheral = '1' and off = OFF_HEX5) else '0';
    cs_sw     <= '1' when (is_peripheral = '1' and off = OFF_SW)   else '0';
    cs_pb     <= '1' when (is_peripheral = '1' and off = OFF_PB)   else '0';

    ----------------------------------------------------------------------------
    -- (2) write gating : per-port write-enables = chip-select AND MemWrite
    ----------------------------------------------------------------------------
    we_ledr <= cs_ledr and mem_write_i;
    gen_we_hex : for i in 0 to 5 generate
        we_hex(i) <= cs_hex(i) and mem_write_i;
    end generate;

    -- DTCM writes only when the access is NOT a peripheral
    dtcm_we_o <= mem_write_i and (not is_peripheral);

    ----------------------------------------------------------------------------
    -- (4) read-return mux : peripheral (from gpio) vs DTCM
    ----------------------------------------------------------------------------
    rdata_o <= periph_rdata when is_peripheral = '1' else dtcm_rdata_i;

    ----------------------------------------------------------------------------
    -- GPIO : output registers (GPO) + SW/PB input mux (GPI)
    ----------------------------------------------------------------------------
    U_GPIO : gpio
        generic map ( DATA_WIDTH => DATA_WIDTH )
        port map (
            clk_i     => clk_i,
            rst_i     => rst_i,
            wdata_i   => wdata_i(7 downto 0),
            we_ledr_i => we_ledr,
            we_hex_i  => we_hex,
            sel_sw_i  => cs_sw,
            sel_pb_i  => cs_pb,
            rdata_o   => periph_rdata,
            SW_i      => SW_i,
            PB_i      => PB_i,
            LEDR_o    => LEDR_o,
            HEX0_o    => HEX0_o,
            HEX1_o    => HEX1_o,
            HEX2_o    => HEX2_o,
            HEX3_o    => HEX3_o,
            HEX4_o    => HEX4_o,
            HEX5_o    => HEX5_o
        );

end architecture rtl;
