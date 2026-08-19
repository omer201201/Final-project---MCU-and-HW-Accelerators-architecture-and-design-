--------------------------------------------------------------------------------
-- tb_divider.vhd
-- Self-checking unit testbench for the divider + CDC synchronizer module.
--
-- Two asynchronous clocks are used on purpose:
--   * DIVCLK  - the fast divider clock
--   * MCLK    - a slower, asynchronous clock that GENERATES the DIVENA start,
--               emulating the CPU/slow domain, so the synchronizer's clock
--               crossing is actually exercised.
--
-- Checks:
--   * divider math (directed corner cases + random) against numeric_std / and mod
--   * divide-by-zero convention (q = all ones, r = dividend)
--   * synchronizer single-shot: holding DIVENA high triggers exactly ONE divide
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_divider is
end entity tb_divider;

architecture sim of tb_divider is

    constant N             : positive := 32;
    constant DIVCLK_PERIOD : time     := 10 ns;   -- fast clock (illustrative)
    constant MCLK_PERIOD   : time     := 35 ns;   -- slow clock, async to DIVCLK

    signal divclk   : std_logic := '0';
    signal mclk     : std_logic := '0';
    signal divrst   : std_logic := '1';
    signal divena   : std_logic := '0';
    signal dividend : std_logic_vector(N-1 downto 0) := (others => '0');
    signal divisor  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal quotient : std_logic_vector(N-1 downto 0);
    signal residue  : std_logic_vector(N-1 downto 0);
    signal divbusy  : std_logic;

    signal sim_done : boolean := false;

begin

    DUT : entity work.divider
        generic map ( N => N )
        port map (
            DIVCLK     => divclk,
            DIVRST     => divrst,
            DIVENA     => divena,
            read_data1 => dividend,
            read_data2 => divisor,
            Quotient   => quotient,
            Residue  => residue,
            DIVBUSY  => divbusy
        );

    -- fast clock
    divclk_gen : process
    begin
        while not sim_done loop
            divclk <= '0'; wait for DIVCLK_PERIOD/2;
            divclk <= '1'; wait for DIVCLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- slow, asynchronous clock (source of DIVENA)
    mclk_gen : process
    begin
        while not sim_done loop
            mclk <= '0'; wait for MCLK_PERIOD/2;
            mclk <= '1'; wait for MCLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim : process
        variable errors : natural := 0;
        variable tests  : natural := 0;
        variable seed1  : positive := 42;
        variable seed2  : positive := 7;
        variable r      : real;
        variable hi, lo : integer;
        variable op_a, op_b : unsigned(N-1 downto 0);   -- random operands
        variable eq, er : unsigned(N-1 downto 0);        -- reference results

        -- drive one divide (clean DIVENA pulse in the slow domain) and self-check
        procedure do_div(av, bv : in unsigned(N-1 downto 0)) is
        begin
            wait until rising_edge(mclk);
            dividend <= std_logic_vector(av);
            divisor  <= std_logic_vector(bv);
            divena   <= '1';
            wait until divbusy = '1';         -- busy is 0 here, so we catch its rise
            divena   <= '0';                  -- one start captured; release the enable
            wait until divbusy = '0';         -- divide finished
            wait until rising_edge(divclk);   -- let outputs settle
            if bv = 0 then
                eq := (others => '1'); er := av;
            else
                eq := av / bv; er := av mod bv;
            end if;
            tests := tests + 1;
            if unsigned(quotient) /= eq or unsigned(residue) /= er then
                errors := errors + 1;
                report "MISMATCH " & integer'image(to_integer(av)) & " / " &
                       integer'image(to_integer(bv)) & " : got q=" &
                       integer'image(to_integer(unsigned(quotient))) & " r=" &
                       integer'image(to_integer(unsigned(residue))) & " exp q=" &
                       integer'image(to_integer(eq)) & " r=" &
                       integer'image(to_integer(er)) severity error;
            end if;
        end procedure;

    begin
        -- reset
        divrst <= '1';
        wait for 4*DIVCLK_PERIOD;
        wait until rising_edge(mclk);
        divrst <= '0';

        -- directed corner cases
        do_div(to_unsigned(7,   N), to_unsigned(2,    N));
        do_div(to_unsigned(1,   N), to_unsigned(1,    N));
        do_div(to_unsigned(100, N), to_unsigned(10,   N));
        do_div(to_unsigned(100, N), to_unsigned(7,    N));
        do_div(to_unsigned(0,   N), to_unsigned(5,    N));   -- q=0, r=0
        do_div(to_unsigned(1,   N), to_unsigned(1000, N));   -- q=0, r=a
        do_div((others => '1'),     to_unsigned(1,    N));   -- max / 1
        do_div((others => '1'),     (others => '1'));        -- max / max = 1 r0
        do_div(to_unsigned(5,   N), to_unsigned(0,    N));   -- div by zero
        do_div((others => '1'),     to_unsigned(0,    N));   -- max / 0

        -- random cases (full 32-bit operands from two 16-bit draws)
        for i in 0 to 199 loop
            uniform(seed1, seed2, r); hi := integer(floor(r*65536.0));
            uniform(seed1, seed2, r); lo := integer(floor(r*65536.0));
            op_a := to_unsigned(hi,16) & to_unsigned(lo,16);
            uniform(seed1, seed2, r); hi := integer(floor(r*65536.0));
            uniform(seed1, seed2, r); lo := integer(floor(r*65536.0));
            op_b := to_unsigned(hi,16) & to_unsigned(lo,16);
            do_div(op_a, op_b);
        end loop;

        -----------------------------------------------------------------------
        -- Synchronizer single-shot check: hold DIVENA high, expect ONE divide
        -----------------------------------------------------------------------
        wait until rising_edge(mclk);
        dividend <= std_logic_vector(to_unsigned(50, N));
        divisor  <= std_logic_vector(to_unsigned(4,  N));
        divena   <= '1';                       -- assert and HOLD high
        wait until divbusy = '1';
        wait until divbusy = '0';              -- first (and only) divide done
        wait until rising_edge(divclk);
        tests := tests + 1;
        if unsigned(quotient) /= to_unsigned(12,N) or unsigned(residue) /= to_unsigned(2,N) then
            errors := errors + 1;
            report "SYNC test: wrong result 50/4" severity error;
        end if;
        -- DIVENA still high: must NOT re-trigger
        for i in 0 to 100 loop
            wait until rising_edge(divclk);
            if divbusy /= '0' then
                errors := errors + 1;
                report "SYNC test: re-triggered while DIVENA held high!" severity error;
                exit;
            end if;
        end loop;
        divena <= '0';

        -- summary
        report "==============================================";
        report "tb_divider done: " & integer'image(tests) & " tests, " &
               integer'image(errors) & " errors.";
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
