--------------------------------------------------------------------------------
-- BasicTimer.vhd
--
-- Basic Timer with output-comparing capabilities - Figure 7 of the assignment.
-- Structural top level; every block below is a separate entity so that the RTL
-- Viewer capture for the report lines up one-to-one with Figure 7.
--
--   bt_regs        - device interface registers + bus decode
--   bt_prescaler   - BTSSEL source-clock select (as a clock enable)
--   bt_counter     - BTCNT 32-bit up-mode core, EUQ0 / EUQ1 compares
--   bt_output_unit - PWM out, Output Mode 0 / Mode 1
--   bt_capture     - CAPISEL / CAPMD input capture into BTCAPR
--   (BTINT mux)    - selects which event drives BTIFG
--
-- Register map (byte addresses in the 0x2000 I/O page):
--   BTCTL1  0x201C   BTCTL2  0x201D
--   BTCMPR0 0x2020   BTCMPR1 0x2024   BTCAPR 0x2028
--
-- BTCTL1: [7] BTOUTMD  [6] BTOUTEN  [5] BTHOLD  [4:3] BTSSEL  [2] BTCLR  [1:0] BTINT
-- BTCTL2: [7:4] reserved-0          [3:2] CAPMD             [1:0] CAPISEL
--
-- The three operating modes are not separate state machines - they are what you
-- get by pointing BTINT at a different event source:
--   Compare mode        : BTINT = 00 -> BTIFG from EUQ0 (periodic, BTCMPR0)
--                         BTINT = 01 -> BTIFG from EUQ1 (periodic, BTCMPR1)
--   Output compare mode : BTOUTEN = 1, PWM out from BTCL0 (period) / BTCL1 (edge)
--   Input capture mode  : BTINT = 10 -> BTIFG from the capture event
--
-- >>> Clocking <<<
-- One clock domain.  The course forum guidance is that MCLK and SMCLK come from
-- integer-multiple PLL outputs and that MCLK = SMCLK is acceptable for the
-- single-cycle MCU, so bus writes and the timer share `clk` and no CDC is
-- required here (unlike the divider accelerator, which genuinely does cross into
-- DIVCLK and needs the Figure 10b synchroniser).  If MCLK /= SMCLK is ever
-- chosen, the `cs`/`we`/`addr`/`wdata` group is what needs synchronising.
--
-- >>> Interrupt output <<<
-- btifg_evt is a ONE-CYCLE PULSE, not a sticky flag.  Figure 13 shows each
-- interrupt source clocking a set-only flip-flop inside the interrupt
-- controller, cleared by clr_irq - so the sticky BTIFG bit belongs to the
-- interrupt controller's IFG register, and this peripheral only reports events.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity BasicTimer is
    generic (
        W : natural := 32
    );
    port (
        clk       : in  std_logic;                       -- SMCLK
        rst       : in  std_logic;                       -- async, active high

        -- CPU data bus
        cs        : in  std_logic;                       -- Basic Timer chip select
        we        : in  std_logic;                       -- MemWrite
        addr      : in  std_logic_vector(5 downto 0);    -- data byte address (5:0)
        wdata     : in  std_logic_vector(W-1 downto 0);
        rdata     : out std_logic_vector(W-1 downto 0);

        -- device pins
        capin1    : in  std_logic;
        capin2    : in  std_logic;
        pwm_out   : out std_logic;

        -- to the interrupt controller
        btifg_evt : out std_logic
    );
end entity BasicTimer;

architecture structural of BasicTimer is

    component bt_regs is
        generic (W : natural := 32);
        port (
            clk    : in  std_logic;
            rst    : in  std_logic;
            cs     : in  std_logic;
            we     : in  std_logic;
            addr   : in  std_logic_vector(5 downto 0);
            wdata  : in  std_logic_vector(W-1 downto 0);
            rdata  : out std_logic_vector(W-1 downto 0);
            btctl1 : out std_logic_vector(7 downto 0)   := (others => '0');
            btctl2 : out std_logic_vector(7 downto 0)   := (others => '0');
            btcl0  : out std_logic_vector(W-1 downto 0) := (others => '0');
            btcl1  : out std_logic_vector(W-1 downto 0) := (others => '0');
            btcapr : in  std_logic_vector(W-1 downto 0)
        );
    end component;

    component bt_prescaler is
        port (
            clk    : in  std_logic;
            rst    : in  std_logic;
            clr    : in  std_logic;
            btssel : in  std_logic_vector(1 downto 0);
            tick   : out std_logic
        );
    end component;

    component bt_counter is
        generic (W : natural := 32);
        port (
            clk    : in  std_logic;
            rst    : in  std_logic;
            tick   : in  std_logic;
            btclr  : in  std_logic;
            bthold : in  std_logic;
            btcl0  : in  std_logic_vector(W-1 downto 0);
            btcl1  : in  std_logic_vector(W-1 downto 0);
            btcnt  : out std_logic_vector(W-1 downto 0);
            euq0   : out std_logic;
            euq1   : out std_logic
        );
    end component;

    component bt_output_unit is
        port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            euq0    : in  std_logic;
            euq1    : in  std_logic;
            btouten : in  std_logic;
            btoutmd : in  std_logic;
            pwm_out : out std_logic
        );
    end component;

    component bt_capture is
        generic (W : natural := 32);
        port (
            clk     : in  std_logic;
            rst     : in  std_logic;
            capisel : in  std_logic_vector(1 downto 0);
            capmd   : in  std_logic_vector(1 downto 0);
            capin1  : in  std_logic;
            capin2  : in  std_logic;
            btcnt   : in  std_logic_vector(W-1 downto 0);
            btcapr  : out std_logic_vector(W-1 downto 0);
            cap_evt : out std_logic
        );
    end component;

    -- control register fields
    signal btctl1_s : std_logic_vector(7 downto 0);
    signal btctl2_s : std_logic_vector(7 downto 0);

    alias BTOUTMD : std_logic                    is btctl1_s(7);
    alias BTOUTEN : std_logic                    is btctl1_s(6);
    alias BTHOLD  : std_logic                    is btctl1_s(5);
    alias BTSSEL  : std_logic_vector(1 downto 0) is btctl1_s(4 downto 3);
    alias BTCLR   : std_logic                    is btctl1_s(2);
    alias BTINT   : std_logic_vector(1 downto 0) is btctl1_s(1 downto 0);

    alias CAPMD   : std_logic_vector(1 downto 0) is btctl2_s(3 downto 2);
    alias CAPISEL : std_logic_vector(1 downto 0) is btctl2_s(1 downto 0);

    -- datapath (initialised so time-0 deltas do not raise NUMERIC_STD
    -- metavalue warnings before the async reset propagates)
    signal btcl0_s  : std_logic_vector(W-1 downto 0) := (others => '0');
    signal btcl1_s  : std_logic_vector(W-1 downto 0) := (others => '0');
    signal btcnt_s  : std_logic_vector(W-1 downto 0) := (others => '0');
    signal btcapr_s : std_logic_vector(W-1 downto 0) := (others => '0');

    signal tick_s     : std_logic;
    signal euq0_s     : std_logic;
    signal euq1_s     : std_logic;
    signal cap_evt_s  : std_logic;
    signal btifg_mux  : std_logic;

begin

    U_REGS : bt_regs
        generic map (W => W)
        port map (
            clk    => clk,
            rst    => rst,
            cs     => cs,
            we     => we,
            addr   => addr,
            wdata  => wdata,
            rdata  => rdata,
            btctl1 => btctl1_s,
            btctl2 => btctl2_s,
            btcl0  => btcl0_s,
            btcl1  => btcl1_s,
            btcapr => btcapr_s
        );

    U_PRESCALER : bt_prescaler
        port map (
            clk    => clk,
            rst    => rst,
            clr    => BTCLR,
            btssel => BTSSEL,
            tick   => tick_s
        );

    U_COUNTER : bt_counter
        generic map (W => W)
        port map (
            clk    => clk,
            rst    => rst,
            tick   => tick_s,
            btclr  => BTCLR,
            bthold => BTHOLD,
            btcl0  => btcl0_s,
            btcl1  => btcl1_s,
            btcnt  => btcnt_s,
            euq0   => euq0_s,
            euq1   => euq1_s
        );

    U_OUTPUT : bt_output_unit
        port map (
            clk     => clk,
            rst     => rst,
            euq0    => euq0_s,
            euq1    => euq1_s,
            btouten => BTOUTEN,
            btoutmd => BTOUTMD,
            pwm_out => pwm_out
        );

    U_CAPTURE : bt_capture
        generic map (W => W)
        port map (
            clk     => clk,
            rst     => rst,
            capisel => CAPISEL,
            capmd   => CAPMD,
            capin1  => capin1,
            capin2  => capin2,
            btcnt   => btcnt_s,
            btcapr  => btcapr_s,
            cap_evt => cap_evt_s
        );

    -- BTINT: interrupt-source select (Figure 7).  The spec calls it "three
    -- options", and the 4:1 mux in the figure ties both upper inputs to the
    -- capture event -- consistent with the benchmark, which uses BTINT = 2
    -- (BTINT2 = 0x02) for capture mode and BTINT = 0 for compare mode.
    with BTINT select
        btifg_mux <= euq0_s    when "00",
                     euq1_s    when "01",
                     cap_evt_s when others;

    -- The BTINT mux is combinational over EUQ0/EUQ1/cap_evt, which are AND terms
    -- of signals that all change on the same clock edge (BTCNT, the prescaler
    -- tick, BTHOLD).  Settling in different delta cycles, it can emit a
    -- glitch narrower than a clock period.  Figure 13 uses this line to CLOCK
    -- the IFG flip-flop, where such a glitch would latch a phantom interrupt.
    -- One register makes it a clean, glitch-free single-cycle pulse.
    IFG_PULSE : process (clk, rst)
    begin
        if rst = '1' then
            btifg_evt <= '0';
        elsif rising_edge(clk) then
            btifg_evt <= btifg_mux;
        end if;
    end process;

end architecture structural;
