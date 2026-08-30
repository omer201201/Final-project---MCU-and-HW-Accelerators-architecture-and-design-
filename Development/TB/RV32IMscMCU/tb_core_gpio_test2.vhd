--------------------------------------------------------------------------------
-- tb_core_gpio_test2.vhd
-- End-to-end test of the MMIO-bus RV32IM core on benchmark GPIO/test2.
-- test2 reads PORT_SW (SW0=up, SW1=down, else hold) like test1, BUT displays the
-- count as a 6-digit hex number -- each HEX gets a DIFFERENT nibble:
--     HEX0 = count[3:0]   HEX1 = count[7:4]   HEX2 = count[11:8] ...
--     LEDR = count[7:0]
-- (test0/test1 wrote the SAME value to every HEX; test2 is the multi-digit case.)
--
-- The bench drives SW, lets the counter climb past 0x10 (so HEX1 is a distinct,
-- non-zero digit), then at settled states checks the per-digit split against a
-- golden seg7 table:
--     HEX0 == seg7(LEDR[3:0])   HEX1 == seg7(LEDR[7:4])   HEX2..5 == seg7(0)
-- It also checks the up/down/hold direction (GPI still works).
--
-- Prereq: G_MODELSIM=1 and SIM/RV32IMscMCU/{ITCM,DTCM}.hex = GPIO/test2 images.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cond_compilation_package.all;
use work.aux_package.all;

entity tb_core_gpio_test2 is
end entity tb_core_gpio_test2;

architecture sim of tb_core_gpio_test2 is

    constant PCW : integer := G_PC_WIDTH;
    constant DAW : integer := G_ADDRWIDTH;
    constant T   : time    := 10 ns;

    signal clk, rst : std_logic := '0';

    signal pc_o            : std_logic_vector(PCW-1 downto 0);
    signal instruction_o   : std_logic_vector(31 downto 0);
    signal RegWrite_ctrl_o : std_logic;
    signal MemWrite_ctrl_o : std_logic;
    signal Branch_ctrl_o   : std_logic;
    signal read_data1_o    : std_logic_vector(31 downto 0);
    signal read_data2_o    : std_logic_vector(31 downto 0);
    signal write_data_o    : std_logic_vector(31 downto 0);
    signal alu_res_o       : std_logic_vector(31 downto 0);
    signal brTaken_o       : std_logic;
    signal dtcm_addr_o     : std_logic_vector(DAW-1 downto 0);
    signal dtcm_data_wr_o  : std_logic_vector(31 downto 0);
    signal dtcm_data_rd_o  : std_logic_vector(31 downto 0);
    signal mclk_cnt_o      : std_logic_vector(15 downto 0);

    signal SW   : std_logic_vector(7 downto 0) := (others => '0');
    signal PB   : std_logic_vector(2 downto 0) := (others => '0');
    signal LEDR : std_logic_vector(7 downto 0);
    signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);

    signal sim_done : boolean := false;

    -- golden 7-seg table (same as Lab4 seg7.vhd, active-low)
    function seg7_ref(n : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable r : std_logic_vector(6 downto 0);
    begin
        case n is
            when "0000" => r := "1000000";  when "0001" => r := "1111001";
            when "0010" => r := "0100100";  when "0011" => r := "0110000";
            when "0100" => r := "0011001";  when "0101" => r := "0010010";
            when "0110" => r := "0000010";  when "0111" => r := "1111000";
            when "1000" => r := "0000000";  when "1001" => r := "0010000";
            when "1010" => r := "0001000";  when "1011" => r := "0000011";
            when "1100" => r := "1000110";  when "1101" => r := "0100001";
            when "1110" => r := "0000110";  when others => r := "0001110";
        end case;
        return r;
    end function;

begin

    CORE : RV32I_CORE
        generic map (
            WORD_GRANULARITY => G_WORD_GRANULARITY, MODELSIM => G_MODELSIM,
            DATA_BUS_WIDTH => 32, ITCM_ADDR_WIDTH => G_ADDRWIDTH,
            DTCM_ADDR_WIDTH => G_ADDRWIDTH, PC_WIDTH => G_PC_WIDTH,
            MA_WIDTH => G_MA_WIDTH, DATA_WORDS_NUM => G_DATA_WORDSNUM,
            CLK_CNT_WIDTH => 16
        )
        port map (
            rst_i => rst, clk_i => clk,
            pc_o => pc_o, instruction_o => instruction_o,
            RegWrite_ctrl_o => RegWrite_ctrl_o, MemWrite_ctrl_o => MemWrite_ctrl_o,
            Branch_ctrl_o => Branch_ctrl_o,
            read_data1_o => read_data1_o, read_data2_o => read_data2_o,
            write_data_o => write_data_o, alu_res_o => alu_res_o, brTaken_o => brTaken_o,
            dtcm_addr_o => dtcm_addr_o, dtcm_data_wr_o => dtcm_data_wr_o,
            dtcm_data_rd_o => dtcm_data_rd_o, mclk_cnt_o => mclk_cnt_o,
            SW_i => SW, PB_i => PB, LEDR_o => LEDR,
            HEX0_o => HEX0, HEX1_o => HEX1, HEX2_o => HEX2,
            HEX3_o => HEX3, HEX4_o => HEX4, HEX5_o => HEX5
        );

    clkgen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for T/2;
            clk <= '1'; wait for T/2;
        end loop;
        wait;
    end process;

    rst <= '1', '0' after 8*T;

    check : process
        variable v0, v1  : std_logic_vector(7 downto 0);
        variable ledr_s  : std_logic_vector(7 downto 0);
        variable h0,h1,h2,h3,h4,h5 : std_logic_vector(6 downto 0);
        variable e0,e1,eh : std_logic_vector(6 downto 0);
        variable c1v      : std_logic_vector(7 downto 0);
        variable a, b     : std_logic_vector(7 downto 0);
        variable d        : integer;
        variable md_good  : natural := 0;   -- settled, multi-digit correct
        variable md_bad   : natural := 0;   -- settled, wrong split
        variable errors   : natural := 0;
    begin
        wait until rst = '0';
        wait for 1 us;

        ------------------------------------------------------------------
        -- UP: drive SW0, let the count climb past 0x10 (so HEX1 != 0)
        ------------------------------------------------------------------
        SW <= x"01";
        v0 := LEDR;
        wait for 16 us;                       -- climb well past 16
        v1 := LEDR;
        if to_integer(unsigned(v1)) <= to_integer(unsigned(v0)) or
           to_integer(unsigned(v1)) < 16 then
            errors := errors + 1;
            report "UP: expected count to climb past 16, got " &
                   integer'image(to_integer(unsigned(v1))) severity error;
        end if;

        ------------------------------------------------------------------
        -- multi-digit check at settled states (still counting up)
        ------------------------------------------------------------------
        for k in 0 to 120 loop
            ledr_s := LEDR;
            h0:=HEX0; h1:=HEX1; h2:=HEX2; h3:=HEX3; h4:=HEX4; h5:=HEX5;
            wait for 4*T;
            if (LEDR=ledr_s) and (HEX0=h0) and (HEX1=h1) and (HEX2=h2)
               and (HEX3=h3) and (HEX4=h4) and (HEX5=h5) then    -- settled
                eh  := seg7_ref("0000");              -- HEX2..5 = 0 (count < 256)
                -- HEX group is written before LEDR, so at a settled sample it
                -- reflects count = LEDR (delay loop) or LEDR+1 (HEX-vs-LEDR gap).
                c1v := std_logic_vector(unsigned(ledr_s) + 1);
                if ( h0=seg7_ref(ledr_s(3 downto 0)) and h1=seg7_ref(ledr_s(7 downto 4))
                     and h2=eh and h3=eh and h4=eh and h5=eh )
                   or
                   ( h0=seg7_ref(c1v(3 downto 0)) and h1=seg7_ref(c1v(7 downto 4))
                     and h2=eh and h3=eh and h4=eh and h5=eh ) then
                    md_good := md_good + 1;
                else
                    md_bad := md_bad + 1;
                    report "multi-digit MISMATCH at LEDR=" &
                           integer'image(to_integer(unsigned(ledr_s))) &
                           "  HEX0=" & integer'image(to_integer(unsigned(h0))) &
                           " HEX1=" & integer'image(to_integer(unsigned(h1))) severity error;
                end if;
            end if;
            wait for 2*T;
        end loop;

        ------------------------------------------------------------------
        -- DOWN
        ------------------------------------------------------------------
        SW <= x"02"; wait for 900 ns;
        a := LEDR; wait for 2 us; b := LEDR;
        d := to_integer(signed(std_logic_vector(unsigned(b) - unsigned(a))));
        if d >= 0 then
            errors := errors + 1;
            report "DOWN: expected decrease, delta=" & integer'image(d) severity error;
        end if;

        ------------------------------------------------------------------
        -- HOLD
        ------------------------------------------------------------------
        SW <= x"00"; wait for 900 ns;
        a := LEDR; wait for 2 us; b := LEDR;
        d := to_integer(signed(std_logic_vector(unsigned(b) - unsigned(a))));
        if d /= 0 then
            errors := errors + 1;
            report "HOLD: expected no change, delta=" & integer'image(d) severity error;
        end if;

        report "==============================================";
        report "tb_core_gpio_test2: multi-digit good=" & integer'image(md_good) &
               " bad=" & integer'image(md_bad) & "  other errors=" & integer'image(errors);
        if errors = 0 and md_bad = 0 and md_good >= 5 then
            report "RESULT: PASS  (6-digit HEX split + up/down/hold)" severity note;
        else
            report "RESULT: FAIL" severity failure;
        end if;
        report "==============================================";

        sim_done <= true;
        wait;
    end process;

end architecture sim;
