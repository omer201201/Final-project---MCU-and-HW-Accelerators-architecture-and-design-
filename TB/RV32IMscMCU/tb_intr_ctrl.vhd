--------------------------------------------------------------------------------
-- tb_intr_ctrl.vhd  -  standalone self-checking testbench for the Basic
-- Interrupt Controller. Drives the bus (IE/IFG/TYPE), the 6 source pulses, and
-- the INTA handshake directly -- NO CPU. Covers every block:
--   T1 reset state
--   T2 IE register read/write
--   T3 masking: a source sets IFG, but INTR only asserts when IE enables it
--   T4 single interrupt + INTA: TYPE snapshot, flag auto-clear, INTR drops
--   T5 priority: BT(bit2) beats KEY3(bit5); after ack, KEY3 becomes the winner
--   T6 software clear: writing IFG=0 clears a pending flag and drops INTR
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_intr_ctrl is
end entity tb_intr_ctrl;

architecture sim of tb_intr_ctrl is

    constant W : integer := 32;
    constant T : time    := 10 ns;

    constant A_IE   : std_logic_vector(5 downto 0) := "101100"; -- 0x2C
    constant A_IFG  : std_logic_vector(5 downto 0) := "101101"; -- 0x2D
    constant A_TYPE : std_logic_vector(5 downto 0) := "101110"; -- 0x2E

    -- source bit indices
    constant RX : natural := 0;
    constant TX : natural := 1;
    constant BT : natural := 2;
    constant K1 : natural := 3;
    constant K2 : natural := 4;
    constant K3 : natural := 5;

    signal clk_s, rst_s : std_logic := '0';
    signal cs_s, we_s   : std_logic := '0';
    signal addr_s       : std_logic_vector(5 downto 0)  := (others => '0');
    signal wdata_s      : std_logic_vector(W-1 downto 0) := (others => '0');
    signal rdata_s      : std_logic_vector(W-1 downto 0);
    signal src_s        : std_logic_vector(5 downto 0)  := (others => '0');
    signal intr_s       : std_logic;
    signal inta_s       : std_logic := '0';

    signal sim_done : boolean := false;

begin

    DUT : entity work.intr_ctrl
        generic map ( DATA_WIDTH => W )
        port map (
            clk_i => clk_s, rst_i => rst_s,
            cs_i => cs_s, we_i => we_s, addr_i => addr_s,
            wdata_i => wdata_s, rdata_o => rdata_s,
            src_i => src_s, intr_o => intr_s, inta_i => inta_s
        );

    clk_gen : process
    begin
        while not sim_done loop
            clk_s <= '0'; wait for T/2;
            clk_s <= '1'; wait for T/2;
        end loop;
        wait;
    end process;

    stim : process
        variable errors : natural := 0;
        variable rv     : std_logic_vector(W-1 downto 0);

        procedure check (cond : boolean; msg : string) is
        begin
            if cond then
                report "pass: " & msg severity note;
            else
                errors := errors + 1;
                report "FAIL: " & msg severity error;
            end if;
        end procedure;

        procedure bus_write (a : std_logic_vector(5 downto 0); d : std_logic_vector(W-1 downto 0)) is
        begin
            wait until falling_edge(clk_s);
            addr_s <= a; wdata_s <= d; cs_s <= '1'; we_s <= '1';
            wait until rising_edge(clk_s);
            wait until falling_edge(clk_s);
            cs_s <= '0'; we_s <= '0';
        end procedure;

        procedure bus_read (a : std_logic_vector(5 downto 0); result : out std_logic_vector(W-1 downto 0)) is
        begin
            wait until falling_edge(clk_s);
            addr_s <= a; cs_s <= '1'; we_s <= '0';
            wait for 1 ns;
            result := rdata_s;
            cs_s <= '0';
        end procedure;

        procedure pulse_src (b : natural) is
        begin
            wait until falling_edge(clk_s);
            src_s(b) <= '1';
            wait until rising_edge(clk_s);          -- captured on this edge
            wait until falling_edge(clk_s);
            src_s(b) <= '0';
        end procedure;

        procedure pulse_inta is
        begin
            wait until falling_edge(clk_s);
            inta_s <= '1';
            wait until rising_edge(clk_s);          -- TYPE snapshot + winner clear
            wait until falling_edge(clk_s);
            inta_s <= '0';
        end procedure;

    begin
        report "=== Basic Interrupt Controller testbench ===" severity note;
        rst_s <= '1';
        wait for 4*T;
        wait until rising_edge(clk_s);
        wait for 1 ns;
        rst_s <= '0';

        ---------------------------------------------------------------- T1
        bus_read(A_IE,   rv); check(rv = x"00000000", "T1 IE=0 after reset");
        bus_read(A_IFG,  rv); check(rv = x"00000000", "T1 IFG=0 after reset");
        bus_read(A_TYPE, rv); check(rv = x"00000000", "T1 TYPE=0 after reset");
        check(intr_s = '0', "T1 INTR low after reset");

        ---------------------------------------------------------------- T2
        bus_write(A_IE, x"00000004");                       -- enable BT (bit2)
        bus_read(A_IE, rv); check(rv = x"00000004", "T2 IE read-back = 0x04");

        ---------------------------------------------------------------- T3 masking
        bus_write(A_IE, x"00000000");                       -- disable all
        pulse_src(BT);
        wait for 3*T;
        bus_read(A_IFG, rv); check(rv = x"00000004", "T3 source sets IFG.BT even when masked");
        check(intr_s = '0', "T3 INTR stays low while masked (IE=0)");
        bus_write(A_IE, x"00000004");                       -- now enable BT
        wait for 3*T;
        check(intr_s = '1', "T3 INTR asserts once BT is enabled");

        ---------------------------------------------------------------- T4 single + INTA
        pulse_inta;
        wait for 3*T;
        bus_read(A_TYPE, rv); check(rv = x"00000010", "T4 TYPE = BT vector 0x10 after INTA");
        bus_read(A_IFG,  rv); check(rv = x"00000000", "T4 INTA auto-cleared IFG.BT");
        check(intr_s = '0', "T4 INTR drops after the source is serviced");

        ---------------------------------------------------------------- T5 priority
        bus_write(A_IE, x"00000024");                       -- enable BT(bit2) + KEY3(bit5)
        pulse_src(K3);
        pulse_src(BT);
        wait for 3*T;
        check(intr_s = '1', "T5 INTR asserts with two sources pending");
        pulse_inta;                                         -- winner = BT (higher priority)
        wait for 3*T;
        bus_read(A_TYPE, rv); check(rv = x"00000010", "T5 higher priority BT (0x10) serviced first");
        check(intr_s = '1', "T5 INTR still high: KEY3 remains pending");
        pulse_inta;                                         -- now winner = KEY3 (async: NOT auto-cleared)
        wait for 3*T;
        bus_read(A_TYPE, rv); check(rv = x"0000001C", "T5 KEY3 (0x1C) TYPE captured next");
        check(intr_s = '1', "T5 KEY3 is async -> NOT auto-cleared -> INTR stays high");
        bus_write(A_IFG, x"00000000");                      -- ISR software-clears KEY3
        wait for 3*T;
        check(intr_s = '0', "T5 INTR drops after software-clearing KEY3");

        ---------------------------------------------------------------- T6 software clear
        bus_write(A_IE, x"00000004");                       -- enable BT
        pulse_src(BT);
        wait for 3*T;
        check(intr_s = '1', "T6 BT pending+enabled -> INTR");
        bus_write(A_IFG, x"00000000");                      -- ISR-style software clear
        wait for 3*T;
        bus_read(A_IFG, rv); check(rv = x"00000000", "T6 software write clears IFG");
        check(intr_s = '0', "T6 INTR drops after software clear");

        report "==============================================";
        report "tb_intr_ctrl: " & integer'image(errors) & " failure(s)";
        if errors = 0 then
            report "RESULT: PASS  (registers, mask, priority, INTA/TYPE, software clear)" severity note;
        else
            report "RESULT: FAIL" severity failure;
        end if;
        report "==============================================";

        sim_done <= true;
        wait;
    end process;

end architecture sim;
