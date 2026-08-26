--============================================================================
-- bus_interface.vhd  -  Memory-Mapped I/O bus hub (P3 GPIO + P4 Timer + IntrCtrl)
--
-- The single new block the CPU talks to. It owns the bus mechanisms:
--   1. level-1 decode : is_peripheral  (byte address >= 0x2000)
--   2. write gating    : dtcm_we (peripheral writes never touch DTCM)
--   3. level-2 decode  : one-hot chip-selects (the "Optimized Address Decoder")
--   4. read-return mux : timer vs intr-ctrl vs gpio vs DTCM
--
-- Peripherals on the bus:
--   gpio        - LEDR + HEX0-5 (GPO) and SW/PB (GPI)          0x2000..0x2014
--   BasicTimer  - BTCTL1/2, BTCMPR0/1, BTCAPR                   0x201C..0x2028
--   intr_ctrl   - IE, IFG, TYPE                                 0x202C..0x202E
--
-- Interrupt sources feeding the controller:
--   BT   = the Basic Timer's btifg pulse (internal)
--   KEY1-3 = rising edge of a press on PB_i (active-low buttons -> falling edge),
--            2-FF synchronised + edge-detected here
--   RX/TX = tied off (no UART - it is the bonus)
-- intr_o = the controller's INTR to the CPU (observable now; CONTROL consumes it
--          in P4b). inta is tied '0' for now (the CPU will drive it in P4b).
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
        PB_i         : in  std_logic_vector(2 downto 0);            -- PORT_PB  (KEY1,KEY2,KEY3)
        LEDR_o       : out std_logic_vector(7 downto 0);            -- PORT_LEDR
        HEX0_o       : out std_logic_vector(6 downto 0);
        HEX1_o       : out std_logic_vector(6 downto 0);
        HEX2_o       : out std_logic_vector(6 downto 0);
        HEX3_o       : out std_logic_vector(6 downto 0);
        HEX4_o       : out std_logic_vector(6 downto 0);
        HEX5_o       : out std_logic_vector(6 downto 0);
        -- ---- Basic Timer ----
        pwm_o        : out std_logic;                              -- PWM output pin
        btifg_o      : out std_logic;                              -- timer interrupt pulse (debug/observe)
        -- ---- Interrupt controller ----
        intr_o       : out std_logic                               -- aggregated INTR -> CPU (P4b consumes)
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

    component BasicTimer is
        generic ( W : natural := 32 );
        port (
            clk       : in  std_logic;
            rst       : in  std_logic;
            cs        : in  std_logic;
            we        : in  std_logic;
            addr      : in  std_logic_vector(5 downto 0);
            wdata     : in  std_logic_vector(W-1 downto 0);
            rdata     : out std_logic_vector(W-1 downto 0);
            capin1    : in  std_logic;
            capin2    : in  std_logic;
            pwm_out   : out std_logic;
            btifg_evt : out std_logic
        );
    end component;

    component intr_ctrl is
        generic ( DATA_WIDTH : integer := 32 );
        port (
            clk_i   : in  std_logic;
            rst_i   : in  std_logic;
            cs_i    : in  std_logic;
            we_i    : in  std_logic;
            addr_i  : in  std_logic_vector(5 downto 0);
            wdata_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            rdata_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
            src_i   : in  std_logic_vector(5 downto 0);
            intr_o  : out std_logic;
            inta_i  : in  std_logic
        );
    end component;

    -- MMIO byte-address offsets within the peripheral page (low 6 bits).
    constant OFF_LEDR    : std_logic_vector(5 downto 0) := "000000"; -- 0x2000
    constant OFF_HEX0    : std_logic_vector(5 downto 0) := "000100"; -- 0x2004
    constant OFF_HEX1    : std_logic_vector(5 downto 0) := "000101"; -- 0x2005
    constant OFF_HEX2    : std_logic_vector(5 downto 0) := "001000"; -- 0x2008
    constant OFF_HEX3    : std_logic_vector(5 downto 0) := "001001"; -- 0x2009
    constant OFF_HEX4    : std_logic_vector(5 downto 0) := "001100"; -- 0x200C
    constant OFF_HEX5    : std_logic_vector(5 downto 0) := "001101"; -- 0x200D
    constant OFF_SW      : std_logic_vector(5 downto 0) := "010000"; -- 0x2010
    constant OFF_PB      : std_logic_vector(5 downto 0) := "010100"; -- 0x2014
    -- Basic Timer
    constant OFF_BTCTL1  : std_logic_vector(5 downto 0) := "011100"; -- 0x201C
    constant OFF_BTCTL2  : std_logic_vector(5 downto 0) := "011101"; -- 0x201D
    constant OFF_BTCMPR0 : std_logic_vector(5 downto 0) := "100000"; -- 0x2020
    constant OFF_BTCMPR1 : std_logic_vector(5 downto 0) := "100100"; -- 0x2024
    constant OFF_BTCAPR  : std_logic_vector(5 downto 0) := "101000"; -- 0x2028
    -- Interrupt controller
    constant OFF_IE      : std_logic_vector(5 downto 0) := "101100"; -- 0x202C
    constant OFF_IFG     : std_logic_vector(5 downto 0) := "101101"; -- 0x202D
    constant OFF_TYPE    : std_logic_vector(5 downto 0) := "101110"; -- 0x202E

    signal is_peripheral : std_logic;
    signal off           : std_logic_vector(5 downto 0);

    signal cs_ledr  : std_logic;
    signal cs_hex   : std_logic_vector(5 downto 0);
    signal cs_sw    : std_logic;
    signal cs_pb    : std_logic;
    signal cs_timer : std_logic;
    signal cs_intr  : std_logic;

    signal we_ledr : std_logic;
    signal we_hex  : std_logic_vector(5 downto 0);

    signal gpio_rdata  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal timer_rdata : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal intr_rdata  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal periph_rdata: std_logic_vector(DATA_WIDTH-1 downto 0);

    signal timer_btifg : std_logic;

    -- KEY input conditioning (2-FF sync + press edge). Buttons are active-low,
    -- so a press is a 1->0 transition on the synchronised sample.
    signal pb_s1, pb_s2, pb_s3 : std_logic_vector(2 downto 0) := (others => '1');
    signal key_pulse           : std_logic_vector(2 downto 0);

    signal src_intr : std_logic_vector(5 downto 0);

begin

    off <= addr_i(5 downto 0);

    ----------------------------------------------------------------------------
    -- (1) level-1 decode : robust "address >= 0x2000"
    ----------------------------------------------------------------------------
    is_peripheral <= addr_i(15) or addr_i(14) or addr_i(13);

    ----------------------------------------------------------------------------
    -- (3) level-2 decode : one-hot chip-selects
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

    cs_timer  <= '1' when (is_peripheral = '1' and
                           (off = OFF_BTCTL1  or off = OFF_BTCTL2  or
                            off = OFF_BTCMPR0 or off = OFF_BTCMPR1 or
                            off = OFF_BTCAPR)) else '0';

    cs_intr   <= '1' when (is_peripheral = '1' and
                           (off = OFF_IE or off = OFF_IFG or off = OFF_TYPE)) else '0';

    ----------------------------------------------------------------------------
    -- (2) write gating : GPO write-enables = chip-select AND MemWrite
    ----------------------------------------------------------------------------
    we_ledr <= cs_ledr and mem_write_i;
    gen_we_hex : for i in 0 to 5 generate
        we_hex(i) <= cs_hex(i) and mem_write_i;
    end generate;

    dtcm_we_o <= mem_write_i and (not is_peripheral);

    ----------------------------------------------------------------------------
    -- (4) read-return mux : timer vs intr-ctrl vs gpio vs DTCM
    ----------------------------------------------------------------------------
    periph_rdata <= timer_rdata when cs_timer = '1' else
                    intr_rdata  when cs_intr  = '1' else
                    gpio_rdata;
    rdata_o      <= periph_rdata when is_peripheral = '1' else dtcm_rdata_i;

    ----------------------------------------------------------------------------
    -- KEY conditioning : 2-FF synchroniser + press (falling) edge -> 1-cyc pulse
    ----------------------------------------------------------------------------
    key_sync : process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            pb_s1 <= (others => '1');
            pb_s2 <= (others => '1');
            pb_s3 <= (others => '1');
        elsif rising_edge(clk_i) then
            pb_s1 <= PB_i;
            pb_s2 <= pb_s1;
            pb_s3 <= pb_s2;
        end if;
    end process;
    -- press = 1 (released) -> 0 (pressed)
    key_pulse <= pb_s3 and (not pb_s2);

    -- interrupt sources: [0]RX [1]TX [2]BT [3]KEY1 [4]KEY2 [5]KEY3
    src_intr(0) <= '0';
    src_intr(1) <= '0';
    src_intr(2) <= timer_btifg;
    src_intr(3) <= key_pulse(0);   -- PB_i(0) = KEY1
    src_intr(4) <= key_pulse(1);   -- PB_i(1) = KEY2
    src_intr(5) <= key_pulse(2);   -- PB_i(2) = KEY3

    ----------------------------------------------------------------------------
    -- GPIO
    ----------------------------------------------------------------------------
    U_GPIO : gpio
        generic map ( DATA_WIDTH => DATA_WIDTH )
        port map (
            clk_i => clk_i, rst_i => rst_i,
            wdata_i => wdata_i(7 downto 0),
            we_ledr_i => we_ledr, we_hex_i => we_hex,
            sel_sw_i => cs_sw, sel_pb_i => cs_pb,
            rdata_o => gpio_rdata,
            SW_i => SW_i, PB_i => PB_i,
            LEDR_o => LEDR_o,
            HEX0_o => HEX0_o, HEX1_o => HEX1_o, HEX2_o => HEX2_o,
            HEX3_o => HEX3_o, HEX4_o => HEX4_o, HEX5_o => HEX5_o
        );

    ----------------------------------------------------------------------------
    -- Basic Timer.  btifg is routed internally to the interrupt controller and
    -- also brought out for observation.
    ----------------------------------------------------------------------------
    U_TIMER : BasicTimer
        generic map ( W => DATA_WIDTH )
        port map (
            clk => clk_i, rst => rst_i,
            cs => cs_timer, we => mem_write_i, addr => off,
            wdata => wdata_i, rdata => timer_rdata,
            capin1 => '0', capin2 => '0',
            pwm_out => pwm_o,
            btifg_evt => timer_btifg
        );
    btifg_o <= timer_btifg;

    ----------------------------------------------------------------------------
    -- Basic Interrupt Controller.  inta tied '0' until the CPU protocol (P4b)
    -- drives it; software can still poll/clear IFG in the meantime.
    ----------------------------------------------------------------------------
    U_INTR : intr_ctrl
        generic map ( DATA_WIDTH => DATA_WIDTH )
        port map (
            clk_i => clk_i, rst_i => rst_i,
            cs_i => cs_intr, we_i => mem_write_i, addr_i => off,
            wdata_i => wdata_i, rdata_o => intr_rdata,
            src_i => src_intr,
            intr_o => intr_o,
            inta_i => '0'
        );

end architecture rtl;
