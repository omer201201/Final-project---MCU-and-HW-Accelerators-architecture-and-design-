--------------------------------------------------------------------------------
-- tb_core_test1.vhd
-- End-to-end test of the divider-integrated RV32IM core on benchmark RV32IM/test1
-- (uses div, mul, rem). ITCM/DTCM images loaded via IFETCH/DMEMORY init_file.
--
-- ModelSim ASE won't expose the altsyncram DTCM to `mem` commands, so we SHADOW
-- the DTCM write bus (mirroring DMEMORY: write on rising clk when MemWrite=1) and
-- compare the computed result arrays against the RARS golden:
--   res1 = arr1/arr2 (div)  @ words 16-23
--   res2 = arr1*arr2 (mul)  @ words 24-31
--   res3 = arr1%arr2 (rem)  @ words 32-39
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cond_compilation_package.all;
use work.aux_package.all;

entity tb_core_test1 is
end entity tb_core_test1;

architecture sim of tb_core_test1 is

    constant PCW : integer := G_PC_WIDTH;
    constant DAW : integer := G_ADDRWIDTH;
    constant T   : time    := 10 ns;

    signal clk, rst : std_logic := '0';

    -- core outputs
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

    -- shadow of the low DTCM region we check
    type mem_t is array(0 to 63) of std_logic_vector(31 downto 0);
    signal shadow : mem_t := (others => (others => '0'));

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
            mclk_cnt_o      => mclk_cnt_o
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

    -- shadow the DTCM writes exactly like DMEMORY does
    shadow_p : process (clk)
    begin
        if rising_edge(clk) then
            if MemWrite_ctrl_o = '1' and to_integer(unsigned(dtcm_addr_o)) <= 63 then
                shadow(to_integer(unsigned(dtcm_addr_o))) <= dtcm_data_wr_o;
            end if;
        end if;
    end process;

    check : process
        variable errors : natural := 0;
        type iv is array(0 to 7) of integer;
        constant exp_res1 : iv := (0, 0, 0, 0, 1, 2, 3, 8);          -- div
        constant exp_res2 : iv := (8, 14, 18, 20, 20, 18, 14, 8);    -- mul
        constant exp_res3 : iv := (1, 2, 3, 4, 1, 0, 1, 0);          -- rem
    begin
        wait for 20 us;                 -- allow all 8 iterations to complete
        for i in 0 to 7 loop
            if to_integer(unsigned(shadow(16 + i))) /= exp_res1(i) then
                errors := errors + 1;
                report "res1[" & integer'image(i) & "] (div) got " &
                       integer'image(to_integer(unsigned(shadow(16 + i)))) &
                       " expected " & integer'image(exp_res1(i)) severity error;
            end if;
            if to_integer(unsigned(shadow(24 + i))) /= exp_res2(i) then
                errors := errors + 1;
                report "res2[" & integer'image(i) & "] (mul) got " &
                       integer'image(to_integer(unsigned(shadow(24 + i)))) &
                       " expected " & integer'image(exp_res2(i)) severity error;
            end if;
            if to_integer(unsigned(shadow(32 + i))) /= exp_res3(i) then
                errors := errors + 1;
                report "res3[" & integer'image(i) & "] (rem) got " &
                       integer'image(to_integer(unsigned(shadow(32 + i)))) &
                       " expected " & integer'image(exp_res3(i)) severity error;
            end if;
        end loop;

        report "==============================================";
        report "tb_core_test1: " & integer'image(errors) &
               " errors (24 words checked: 8 div, 8 mul, 8 rem)";
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
