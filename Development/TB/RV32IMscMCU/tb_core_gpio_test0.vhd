--------------------------------------------------------------------------------
-- tb_core_gpio_test0.vhd
-- End-to-end GPO test of the MMIO-bus RV32IM core on benchmark GPIO/test0.
-- test0 counts up and writes the SAME count to PORT_LEDR and every PORT_HEX0..5
-- (no SW read). So at steady state:
--     LEDR      = count[7:0]
--     HEXn      = seg7(count[3:0])   for all n
-- The bench drives only clk/rst (SW/PB unused) and checks:
--   (a) LEDR advances (the counter is running -> stores reach the peripheral)
--   (b) during stable windows, every HEX == seg7(LEDR[3:0])   (HEX path + decode)
--
-- Prereq: G_MODELSIM=1 (PLL bypass) and SIM/RV32IMscMCU/{ITCM,DTCM}.hex are the
-- GPIO/test0 M9K-intel images (run_gpio0.do copies them in).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cond_compilation_package.all;
use work.aux_package.all;

entity tb_core_gpio_test0 is
end entity tb_core_gpio_test0;

architecture sim of tb_core_gpio_test0 is

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

    -- reference 7-seg table (same as Lab4 seg7.vhd, active-low, g f e d c b a)
    function seg7_ref(n : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable r : std_logic_vector(6 downto 0);
    begin
        case n is
            when "0000" => r := "1000000";
            when "0001" => r := "1111001";
            when "0010" => r := "0100100";
            when "0011" => r := "0110000";
            when "0100" => r := "0011001";
            when "0101" => r := "0010010";
            when "0110" => r := "0000010";
            when "0111" => r := "1111000";
            when "1000" => r := "0000000";
            when "1001" => r := "0010000";
            when "1010" => r := "0001000";
            when "1011" => r := "0000011";
            when "1100" => r := "1000110";
            when "1101" => r := "0100001";
            when "1110" => r := "0000110";
            when others => r := "0001110";
        end case;
        return r;
    end function;

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

    check : process
        variable ledr_s : std_logic_vector(7 downto 0);
        variable h0,h1,h2,h3,h4,h5 : std_logic_vector(6 downto 0);
        variable prev    : std_logic_vector(7 downto 0);
        variable exp     : std_logic_vector(6 downto 0);
        variable seen_inc  : natural := 0;
        variable good      : natural := 0;   -- settled AND all HEX == seg7(LEDR)
        variable bad       : natural := 0;   -- settled but inconsistent (real bug)
        variable stable    : boolean;
    begin
        wait until rst = '0';
        wait for 30*T;                       -- let the first counts happen
        prev := LEDR;

        for k in 0 to 160 loop
            -- snapshot all 7 outputs, then require them ALL unchanged across a
            -- window wider than the gaps between individual stores. That only
            -- holds in the delay loop, i.e. after every port is written -> settled.
            ledr_s := LEDR;
            h0:=HEX0; h1:=HEX1; h2:=HEX2; h3:=HEX3; h4:=HEX4; h5:=HEX5;
            wait for 4*T;
            stable := (LEDR = ledr_s) and (HEX0=h0) and (HEX1=h1) and (HEX2=h2)
                       and (HEX3=h3) and (HEX4=h4) and (HEX5=h5);

            if LEDR /= prev then
                seen_inc := seen_inc + 1;
                prev := LEDR;
            end if;

            if stable then
                exp := seg7_ref(ledr_s(3 downto 0));
                if h0=exp and h1=exp and h2=exp and h3=exp and h4=exp and h5=exp then
                    good := good + 1;        -- settled state is correct
                else
                    bad := bad + 1;          -- settled but wrong -> genuine defect
                    report "settled HEX mismatch at LEDR=" &
                           integer'image(to_integer(unsigned(ledr_s))) &
                           "  HEX0=" & integer'image(to_integer(unsigned(h0))) &
                           "  HEX5=" & integer'image(to_integer(unsigned(h5))) &
                           "  expected=" & integer'image(to_integer(unsigned(exp)))
                           severity error;
                end if;
            end if;

            wait for 2*T;
        end loop;

        report "==============================================";
        report "tb_core_gpio_test0: LEDR increments = " & integer'image(seen_inc) &
               ",  settled-correct = " & integer'image(good) &
               ",  settled-wrong = " & integer'image(bad);
        if bad = 0 and seen_inc >= 5 and good >= 8 then
            report "RESULT: PASS  (GPO: LEDR counts up; all HEX show seg7(count) when settled)" severity note;
        else
            report "RESULT: FAIL" severity failure;
        end if;
        report "==============================================";

        sim_done <= true;
        wait;
    end process;

end architecture sim;
