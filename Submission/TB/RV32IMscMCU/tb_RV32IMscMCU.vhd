--------------------------------------------------------------------------------
-- tb_RV32IMscMCU.vhd
--
-- THE system testbench for the RV32IM single-cycle MCU (project spec, Table 1:
-- "In folder RV32IMscMCU insert the tb_RV32IMscMCU.vhd file").
--
-- It is deliberately BENCHMARK-AGNOSTIC. One testbench serves every benchmark
-- application; everything that differs between benchmarks lives in the .do file:
--
--   * which memory images are loaded   -> the .do copies them into SIM/RV32IMscMCU/
--   * how long the application runs    -> the .do issues `run <time>`
--   * which board inputs are driven    -> the .do uses `force` on SW / PB
--
-- SW and PB therefore have NO driver in this file, only initial (idle) values, so
-- a ModelSim `force` takes effect cleanly. PB is idle HIGH because the DE2-115
-- pushbuttons are active-low (pull-up to VCC3P3, switch to GND -- spec Figure 6).
--
-- >>> Why the DTCM is shadowed rather than dumped directly <<<
-- The DTCM is an altsyncram megafunction. Its storage lives inside a generated
-- submodule that ModelSim ASE's `mem save` cannot reach, so the spec's
-- "ModelSim output file DTCM.mem" cannot be produced with `mem save`. Instead we
-- mirror the DTCM: the shadow array is pre-loaded with the same image the
-- hardware memory is initialised from, and every committed (non-peripheral)
-- store is applied to it on the same clock edge DMEMORY uses. At end of run the
-- shadow is written out as DTCM.mem, one 8-hex-digit word per line -- the exact
-- format of the RARS DTCM.h golden, so the two files can be compared directly.
--
-- Note on the golden model: only "Benchmark apps/RV32IM/test1" ships a RARS
-- POST-RUN golden (gcc_compiled/output/RARS/DTCM.h). The GPIO and interrupt
-- benchmarks ship a load image only -- their programs never terminate (they sit
-- in an FSM loop), so there is no end-of-run state for RARS to dump. For those,
-- DTCM.mem is still produced and is useful for inspection, but the pass/fail
-- criterion is behavioural, not a file compare.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.cond_compilation_package.all;
use work.aux_package.all;

entity tb_RV32IMscMCU is
    generic (
        -- clock period used in simulation (MODELSIM=1 bypasses the PLL, so the
        -- core runs directly at this rate)
        TCLK        : time    := 10 ns;
        -- plain-text image (one 8-hex-digit word per line) used to pre-load the
        -- DTCM shadow. The .do copies the benchmark's Hexadecimal-Text/DTCM.h here.
        DTCM_INIT   : string  := "SIM/RV32IMscMCU/DTCM_init.txt";
        -- where the end-of-run DTCM image is written for the golden comparison
        DTCM_DUMP   : string  := "SIM/RV32IMscMCU/DTCM.mem";
        -- how many DTCM words to dump (RARS goldens in this project are 1024)
        DUMP_WORDS  : integer := 1024
    );
end entity tb_RV32IMscMCU;

architecture sim of tb_RV32IMscMCU is

    constant PCW : integer := G_PC_WIDTH;
    constant DAW : integer := G_ADDRWIDTH;

    signal clk : std_logic := '0';
    signal rst : std_logic;

    -- core observation outputs (also the Signal-Tap auxiliary set)
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

    -- board I/O.  SW and PB are NOT driven here -- the .do forces them.
    signal SW   : std_logic_vector(7 downto 0) := (others => '0');
    signal PB   : std_logic_vector(2 downto 0) := (others => '1');  -- KEYs released
    signal LEDR : std_logic_vector(7 downto 0);
    signal HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : std_logic_vector(6 downto 0);
    signal pwm, btifg, intr : std_logic;

    -- DTCM shadow (see header)
    type dtcm_shadow_t is array (0 to 2047) of std_logic_vector(31 downto 0);
    signal dtcm_shadow : dtcm_shadow_t := (others => (others => '0'));
    signal shadow_ready : boolean := false;

    -- Dump handshake. The .do requests the end-of-run image with
    --     force -deposit /tb_RV32IMscMCU/dump_req 1 0 ; run 1 ns
    -- so the .do decides exactly when the application is "finished".
    signal dump_req  : std_logic := '0';
    signal dump_done : std_logic := '0';

    ----------------------------------------------------------------------------
    -- IPC instrumentation  (LAB5 task definition, clause 6.iii.b)
    --
    --     IPC = (CLKCNT_o - (STCNT_o + 4 + depth*FHCNT_o)) / CLKCNT_o
    --         =  InstructionCounter / CLKCNT_o
    --
    -- For this single-cycle MCU there are no flushes and no pipeline fill, so
    -- FHCNT_o = 0 and the "+4" term drops out, leaving
    --
    --     IPC = (CLKCNT - STCNT) / CLKCNT
    --
    -- Both counters are accumulated HERE, in the testbench, so that measuring
    -- IPC costs the design nothing. CLKCNT is counted directly; STCNT counts
    -- every cycle in which no instruction can retire, which in this design means
    -- the PC is being held -- the divider stall or the 2-cycle interrupt service.
    -- The PC is a top-level output, so this needs no access to core internals.
    ----------------------------------------------------------------------------
    -- A benchmark that finishes ends in "while(1)", which compiles to a jump to
    -- itself -- the PC is held forever, and a naive "PC held = stalled" rule
    -- would count the whole idle tail as stall. SPIN_LIMIT distinguishes the two:
    -- a real divider stall is 8 cycles and the interrupt service is 2, so a PC
    -- held far longer than that means the application has terminated. When that
    -- is detected the counters freeze and the spin cycles already accumulated
    -- are backed out, leaving CLKCNT/STCNT for the program proper.
    constant SPIN_LIMIT : natural := 64;

    signal clk_cnt   : natural := 0;   -- CLKCNT : total cycles after reset
    signal stall_cnt : natural := 0;   -- STCNT  : cycles that retired nothing
    signal same_cnt  : natural := 0;   -- consecutive cycles with the PC held
    signal pc_prev   : std_logic_vector(PCW-1 downto 0) := (others => '0');
    signal ipc_done  : boolean := false;

begin

    ----------------------------------------------------------------------------
    -- DUT : the complete MCU
    ----------------------------------------------------------------------------
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
            HEX5_o          => HEX5,
            pwm_o           => pwm,
            btifg_o         => btifg,
            intr_o          => intr
        );

    ----------------------------------------------------------------------------
    -- clock and reset
    --   MODELSIM=1 -> reset is active-HIGH straight through (see RV32I_CORE).
    ----------------------------------------------------------------------------
    clk <= not clk after TCLK/2;
    rst <= '1', '0' after 8*TCLK;

    ----------------------------------------------------------------------------
    -- IPC counters. A held PC means the cycle retired no instruction.
    ----------------------------------------------------------------------------
    ipc_count : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                clk_cnt   <= 0;
                stall_cnt <= 0;
                same_cnt  <= 0;
                ipc_done  <= false;
            elsif not ipc_done then
                if pc_o = pc_prev then
                    if same_cnt = SPIN_LIMIT then
                        -- terminal spin: stop, and back out the idle tail
                        ipc_done  <= true;
                        clk_cnt   <= clk_cnt   - SPIN_LIMIT;
                        stall_cnt <= stall_cnt - SPIN_LIMIT;
                    else
                        same_cnt  <= same_cnt + 1;
                        clk_cnt   <= clk_cnt + 1;
                        stall_cnt <= stall_cnt + 1;
                    end if;
                else
                    same_cnt <= 0;
                    clk_cnt  <= clk_cnt + 1;
                end if;
            end if;
            pc_prev <= pc_o;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- DTCM model : pre-load, mirror committed stores, dump on request.
    --
    -- All three jobs live in ONE process on purpose. dtcm_shadow is a resolved
    -- (std_logic_vector) signal, so two processes assigning it would each carry
    -- their own driver and the results would be RESOLVED, not overwritten -- a
    -- '1' from the pre-load against the default '0' of a second driver resolves
    -- to 'X'. One process = one driver = the value you actually wrote.
    --
    -- The authoritative copy is the variable `mem`; dtcm_shadow only mirrors it
    -- so the array is visible in the wave window.
    --
    -- DMEMORY is clocked on (not clk), so stores are captured on the falling
    -- edge. A store targets the DTCM only when it is NOT in the peripheral
    -- region, which bus_interface decodes as address bits 15/14/13 all zero.
    ----------------------------------------------------------------------------
    dtcm_model : process
        file     f    : text;
        variable l    : line;
        variable w    : std_logic_vector(31 downto 0);
        variable i    : integer := 0;
        variable st   : file_open_status;
        variable idx  : integer;
        variable mem  : dtcm_shadow_t := (others => (others => '0'));
    begin
        ---------------------------------------------------------------- preload
        file_open(st, f, DTCM_INIT, read_mode);
        if st /= open_ok then
            report "tb_RV32IMscMCU: could not open '" & DTCM_INIT
                 & "' -- DTCM shadow starts at all-zero. The .do should copy the "
                 & "benchmark's Hexadecimal-Text/DTCM.h to that path."
                 severity warning;
        else
            while not endfile(f) and i <= 2047 loop
                readline(f, l);
                hread(l, w);
                mem(i) := w;
                i := i + 1;
            end loop;
            file_close(f);
            report "tb_RV32IMscMCU: DTCM shadow pre-loaded with "
                 & integer'image(i) & " words from " & DTCM_INIT severity note;
        end if;
        for k in 0 to 2047 loop
            dtcm_shadow(k) <= mem(k);
        end loop;
        shadow_ready <= true;

        ------------------------------------------------- capture until dump_req
        loop
            wait until falling_edge(clk) or dump_req = '1';
            exit when dump_req = '1';

            if MemWrite_ctrl_o = '1'
               and alu_res_o(15) = '0' and alu_res_o(14) = '0' and alu_res_o(13) = '0'
            then
                idx := to_integer(unsigned(dtcm_addr_o));
                if idx >= 0 and idx <= 2047 then
                    mem(idx)          := dtcm_data_wr_o;
                    dtcm_shadow(idx)  <= dtcm_data_wr_o;
                end if;
            end if;
        end loop;

        ------------------------------------------------------------------- dump
        file_open(st, f, DTCM_DUMP, write_mode);
        if st /= open_ok then
            report "tb_RV32IMscMCU: cannot write '" & DTCM_DUMP & "'" severity error;
        else
            for k in 0 to DUMP_WORDS-1 loop
                hwrite(l, mem(k));
                writeline(f, l);
            end loop;
            file_close(f);
            report "tb_RV32IMscMCU: wrote " & integer'image(DUMP_WORDS)
                 & " words to " & DTCM_DUMP severity note;
        end if;

        -- IPC report (LAB5 clause 6.iii.b). Compare the left-hand side printed
        -- here against InstructionCounter/CLKCNT taken from the RARS run.
        report "IPC: CLKCNT = " & integer'image(clk_cnt)
             & "  STCNT = "     & integer'image(stall_cnt)
             & "  retired = "   & integer'image(clk_cnt - stall_cnt)
             & "  IPC = "       & real'image(real(clk_cnt - stall_cnt) / real(clk_cnt))
             severity note;

        dump_done <= '1';
        wait;
    end process;

end architecture sim;
