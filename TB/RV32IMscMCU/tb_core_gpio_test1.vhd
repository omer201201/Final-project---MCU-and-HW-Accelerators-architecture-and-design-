--------------------------------------------------------------------------------
-- tb_core_gpio_test1.vhd
-- End-to-end GPI+GPO test of the MMIO-bus RV32IM core on benchmark GPIO/test1.
-- test1 READS PORT_SW every loop and:
--     SW0 (0x01) -> count UP     SW1 (0x02) -> count DOWN     else -> HOLD
-- (SW0 checked first, so with both set UP wins -- software priority.)
-- The count is written to LEDR + all HEX (same as test0), so LEDR = count[7:0].
--
-- This bench is an ACTIVE stimulus: it drives SW through phases and checks the
-- DIRECTION of LEDR each phase. The direction is measured as an 8-bit *signed*
-- delta so it stays correct even if the counter wraps through 0.
--   Phase A: SW=0x01 -> LEDR delta > 0   (up)
--   Phase B: SW=0x02 -> LEDR delta < 0   (down)
--   Phase C: SW=0x00 -> LEDR delta = 0   (hold: no write -> register retains)
--   Phase D: SW=0x03 -> LEDR delta > 0   (priority: SW0 wins)
--
-- Prereq: G_MODELSIM=1 and SIM/RV32IMscMCU/{ITCM,DTCM}.hex = GPIO/test1 images
-- (run_gpio1.do copies them in).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cond_compilation_package.all;
use work.aux_package.all;

entity tb_core_gpio_test1 is
end entity tb_core_gpio_test1;

architecture sim of tb_core_gpio_test1 is

    constant PCW : integer := G_PC_WIDTH;
    constant DAW : integer := G_ADDRWIDTH;
    constant T   : time    := 10 ns;

    signal clk, rst : std_logic := '0';

    -- core debug outputs
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

    -- GPIO pins
    signal SW   : std_logic_vector(7 downto 0) := (others => '0');
    signal PB   : std_logic_vector(2 downto 0) := (others => '0');
    signal LEDR : std_logic_vector(7 downto 0);
    signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);

    signal sim_done : boolean := false;

begin

    CORE : RV32I_CORE
        generic map (
            WORD_GRANULARITY => G_WORD_GRANULARITY,
            MODELSIM         => G_MODELSIM,
            DATA_BUS_WIDTH   => 32,
            ITCM_ADDR_WIDTH  => G_ADDRWIDTH,
            DTCM_ADDR_WIDTH  => G_ADDRWIDTH,
            PC_WIDTH         => G_PC_WIDTH,
            MA_WIDTH         => G_MA_WIDTH,
            DATA_WORDS_NUM   => G_DATA_WORDSNUM,
            CLK_CNT_WIDTH    => 16
        )
        port map (
            rst_i           => rst,
            clk_i           => clk,
            pc_o            => pc_o,
            instruction_o   => instruction_o,
            RegWrite_ctrl_o => RegWrite_ctrl_o,
            MemWrite_ctrl_o => MemWrite_ctrl_o,
            Branch_ctrl_o   => Branch_ctrl_o,
            read_data1_o    => read_data1_o,
            read_data2_o    => read_data2_o,
            write_data_o    => write_data_o,
            alu_res_o       => alu_res_o,
            brTaken_o       => brTaken_o,
            dtcm_addr_o     => dtcm_addr_o,
            dtcm_data_wr_o  => dtcm_data_wr_o,
            dtcm_data_rd_o  => dtcm_data_rd_o,
            mclk_cnt_o      => mclk_cnt_o,
            SW_i            => SW,
            PB_i            => PB,
            LEDR_o          => LEDR,
            HEX0_o          => HEX0,
            HEX1_o          => HEX1,
            HEX2_o          => HEX2,
            HEX3_o          => HEX3,
            HEX4_o          => HEX4,
            HEX5_o          => HEX5
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

    stim_check : process
        variable errors : natural := 0;

        -- drive SW, wait for the program to react, then measure LEDR direction
        procedure check_phase(constant name : in string;
                              constant swval : in std_logic_vector(7 downto 0);
                              constant want  : in integer) is   -- +1 up, -1 down, 0 hold
            variable a, b : std_logic_vector(7 downto 0);
            variable d    : integer;
        begin
            SW <= swval;
            wait for 900 ns;                 -- program reads new SW, enters its branch
            a := LEDR;
            wait for 1500 ns;                -- ~4-5 count iterations
            b := LEDR;
            -- 8-bit signed delta: correct even across a wrap through 0
            d := to_integer(signed(std_logic_vector(unsigned(b) - unsigned(a))));
            if (want > 0 and d <= 0) or (want < 0 and d >= 0) or (want = 0 and d /= 0) then
                errors := errors + 1;
                report name & " FAIL: LEDR " & integer'image(to_integer(unsigned(a))) &
                       " -> " & integer'image(to_integer(unsigned(b))) &
                       "  (signed delta " & integer'image(d) & ")" severity error;
            else
                report name & " ok:   LEDR " & integer'image(to_integer(unsigned(a))) &
                       " -> " & integer'image(to_integer(unsigned(b))) &
                       "  (signed delta " & integer'image(d) & ")" severity note;
            end if;
        end procedure;

    begin
        wait until rst = '0';
        wait for 1 us;                       -- reach steady loop (SW=0 -> holding at 0)

        check_phase("A up   (SW=0x01)", x"01",  1);
        check_phase("B down (SW=0x02)", x"02", -1);
        check_phase("C hold (SW=0x00)", x"00",  0);
        check_phase("D prio (SW=0x03)", x"03",  1);

        report "==============================================";
        report "tb_core_gpio_test1: errors = " & integer'image(errors);
        if errors = 0 then
            report "RESULT: PASS  (GPI: SW read drives up/down/hold + SW0 priority)" severity note;
        else
            report "RESULT: FAIL" severity failure;
        end if;
        report "==============================================";

        sim_done <= true;
        wait;
    end process;

end architecture sim;
