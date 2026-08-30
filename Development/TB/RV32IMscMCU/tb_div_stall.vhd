--------------------------------------------------------------------------------
-- tb_div_stall.vhd
-- Verifies the stall controller (div_stall_ctrl) driving the REAL divider,
-- single clock (MCLK = DIVCLK), the way the stalled CPU would use it.
--
-- Models the CPU feedback: div_instr is held high while stall is high (PC frozen
-- on the div), and dropped the moment stall releases (PC advances).
--
-- Checks per divide:
--   * result correct (quotient/residue) -> proves divena reached the divider
--   * saw_busy: stall did NOT leak during the startup window before DIVBUSY rose
--   * divena pulsed exactly once per divide (counted across the whole run)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_div_stall is
end entity tb_div_stall;

architecture sim of tb_div_stall is

    constant N : positive := 32;
    constant T : time     := 10 ns;

    signal clk       : std_logic := '0';
    signal rst       : std_logic := '1';
    signal div_instr : std_logic := '0';
    signal w_divena  : std_logic;
    signal w_divbusy : std_logic;
    signal w_stall   : std_logic;
    signal rd1, rd2  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal quotient  : std_logic_vector(N-1 downto 0);
    signal residue   : std_logic_vector(N-1 downto 0);

    signal sim_done      : boolean := false;
    signal divena_pulses : natural := 0;   -- counted by the monitor below

begin

    CTRL : entity work.div_stall_ctrl
        port map (
            clk_i       => clk,
            rst_i       => rst,
            div_instr_i => div_instr,
            divbusy_i   => w_divbusy,
            divena_o    => w_divena,
            stall_o     => w_stall
        );

    DUT : entity work.divider
        generic map ( N => N )
        port map (
            DIVCLK     => clk,
            DIVRST     => rst,
            DIVENA     => w_divena,
            read_data1 => rd1,
            read_data2 => rd2,
            Quotient   => quotient,
            Residue    => residue,
            DIVBUSY    => w_divbusy
        );

    clkgen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for T/2;
            clk <= '1'; wait for T/2;
        end loop;
        wait;
    end process;

    -- count DIVENA pulses (it is high exactly one cycle per divide)
    ena_mon : process (clk)
    begin
        if rising_edge(clk) then
            if w_divena = '1' then
                divena_pulses <= divena_pulses + 1;
            end if;
        end if;
    end process;

    stim : process
        variable errors   : natural := 0;
        variable num_divs : natural := 0;
        variable eq, er   : unsigned(N-1 downto 0);
        variable saw_busy1, saw_busy2 : boolean;

        -- issue one div/rem and self-check (samples on falling edges = settled)
        procedure run_div(a, b : in unsigned(N-1 downto 0)) is
            variable saw_busy : boolean := false;
        begin
            wait until rising_edge(clk);
            rd1       <= std_logic_vector(a);
            rd2       <= std_logic_vector(b);
            div_instr <= '1';                     -- PC now sits on the div
            num_divs  := num_divs + 1;

            -- stall holds the PC here until the divide completes
            loop
                wait until falling_edge(clk);     -- mid-cycle: all settled
                if w_divbusy = '1' then saw_busy := true; end if;
                exit when w_stall = '0';          -- completion cycle
            end loop;

            -- completion cycle: results are valid and the write would happen now
            if b = 0 then
                eq := (others => '1'); er := a;
            else
                eq := a / b; er := a mod b;
            end if;
            if unsigned(quotient) /= eq or unsigned(residue) /= er then
                errors := errors + 1;
                report "RESULT mismatch " & integer'image(to_integer(a)) & "/" &
                       integer'image(to_integer(b)) & " got q=" &
                       integer'image(to_integer(unsigned(quotient))) & " r=" &
                       integer'image(to_integer(unsigned(residue))) severity error;
            end if;
            if not saw_busy then
                errors := errors + 1;
                report "STALL leaked during startup (dropped before divide ran)" severity error;
            end if;

            div_instr <= '0';                     -- PC advances past the div
            wait until rising_edge(clk);          -- one non-div gap cycle
        end procedure;

    begin
        rst <= '1';
        wait for 4*T;
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        run_div(to_unsigned(7,   N), to_unsigned(2,  N));
        run_div(to_unsigned(100, N), to_unsigned(10, N));
        run_div(to_unsigned(100, N), to_unsigned(7,  N));
        run_div(to_unsigned(255, N), to_unsigned(16, N));
        run_div(to_unsigned(0,   N), to_unsigned(5,  N));   -- q=0 r=0
        run_div(to_unsigned(5,   N), to_unsigned(0,  N));   -- div by zero
        run_div((others => '1'),     to_unsigned(3,  N));   -- large dividend

        ----------------------------------------------------------------------
        -- ZERO-GAP back-to-back: div_instr stays HIGH across div1 -> div2
        -- (the case that would hang if we fed div_instr straight to DIVENA)
        ----------------------------------------------------------------------
        wait until rising_edge(clk);
        rd1       <= std_logic_vector(to_unsigned(200, N));
        rd2       <= std_logic_vector(to_unsigned(7,   N));
        div_instr <= '1';                                    -- present div1
        num_divs  := num_divs + 1;
        saw_busy1 := false;
        loop
            wait until falling_edge(clk);
            if w_divbusy = '1' then saw_busy1 := true; end if;
            exit when w_stall = '0';                         -- div1 completes
        end loop;
        if unsigned(quotient) /= to_unsigned(28, N) or unsigned(residue) /= to_unsigned(4, N) then
            errors := errors + 1;
            report "B2B div1 (200/7) wrong: got q=" &
                   integer'image(to_integer(unsigned(quotient))) & " r=" &
                   integer'image(to_integer(unsigned(residue))) severity error;
        end if;
        if not saw_busy1 then
            errors := errors + 1; report "B2B div1 startup leak" severity error;
        end if;

        -- PC advances to div2 next edge: swap operands, but KEEP div_instr HIGH
        rd1       <= std_logic_vector(to_unsigned(90, N));
        rd2       <= std_logic_vector(to_unsigned(9,  N));
        num_divs  := num_divs + 1;
        saw_busy2 := false;
        loop
            wait until falling_edge(clk);
            if w_divbusy = '1' then saw_busy2 := true; end if;
            exit when w_stall = '0';                         -- div2 completes
        end loop;
        if unsigned(quotient) /= to_unsigned(10, N) or unsigned(residue) /= to_unsigned(0, N) then
            errors := errors + 1;
            report "B2B div2 (90/9) wrong: got q=" &
                   integer'image(to_integer(unsigned(quotient))) & " r=" &
                   integer'image(to_integer(unsigned(residue))) severity error;
        end if;
        if not saw_busy2 then
            errors := errors + 1; report "B2B div2 startup leak" severity error;
        end if;
        div_instr <= '0';
        wait until rising_edge(clk);

        if divena_pulses /= num_divs then
            errors := errors + 1;
            report "DIVENA pulse count " & integer'image(divena_pulses) &
                   " /= number of divides " & integer'image(num_divs) severity error;
        end if;

        report "==============================================";
        report "tb_div_stall done: " & integer'image(num_divs) & " divides, " &
               integer'image(errors) & " errors, divena pulses=" &
               integer'image(divena_pulses);
        if errors = 0 then
            report "RESULT: PASS" severity note;
        else
            report "RESULT: FAIL" severity failure;
        end if;
        report "==============================================";

        sim_done <= true;
        wait;
    end process;

end architecture sim;
