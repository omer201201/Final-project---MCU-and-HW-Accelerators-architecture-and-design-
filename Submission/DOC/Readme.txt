================================================================================
RV32IM-based MCU  --  Final Project
Advanced CPU Architecture & Hardware Accelerators Lab 361-1-4693, BGU
Submission contents and navigation guide
================================================================================

Directory structure (project definition, Table 1):

    DUT/RV32IMscMCU/        24 VHDL design files (no testbench, no build output)
    TB/RV32IMscMCU/         tb_RV32IMscMCU.vhd
    SIM/RV32IMscMCU/        ModelSim *.do scripts + benchmark memory images
    Quartus/RV32IMscMCU/    SDC, Signal-Tap file, SOF
    DOC/                    Readme.txt (this file), Final_report.pdf

The pipelined bonus (RV32IMpipelinedMCU) was not attempted, so those subfolders
are not present.


================================================================================
1. DUT/RV32IMscMCU  --  description of each design file
================================================================================

PACKAGES
--------
cond_compilation_package.vhd
    The conditional-compilation constants. Selects ModelSim vs Quartus
    (G_MODELSIM), memory geometry (M9K 8 KiB / address widths / word count),
    word- vs byte-granularity, and the two PLL ratios: G_PLL_MUL / G_PLL_DIV for
    MCLK and G_PLL_MUL_DIV / G_PLL_DIV_DIV for DIVCLK. Read section 4 below
    before compiling.

const_package.vhd
    ISA constants -- opcodes, funct3/funct7 encodings, ALU operation codes.
    Uses VHDL-2008 sized bit-string literals, so the whole design must be
    compiled with -2008 (compile.do already does this).

aux_package.vhd
    Component declarations for every entity in the design, so the structural
    top level and the sub-blocks can instantiate one another.

CPU CORE (single-cycle, Harvard)
--------------------------------
RV32I_CORE.vhd
    Structural top level. Instantiates the five core stages, the bus interface,
    the interrupt FSM, the divider accelerator with its three clock-domain
    synchronisers, and the PLL. Also holds the reset-polarity select and the
    MCLK cycle counter (mclk_cnt_o) used for the IPC measurement.

IFETCH.VHD
    Program counter, the 8 KiB ITCM (altsyncram, M9K), and the next-PC select
    for sequential / branch / jal / jalr / interrupt-vector fetch. The ITCM has
    ENABLE_RUNTIME_MOD = YES with INSTANCE_NAME = ITCM so its contents can be
    rewritten over JTAG by the In-System Memory Content Editor.

IDECODE.VHD
    The 32 x 32 register file, immediate generation for all instruction
    formats, and the register-file write override used by the interrupt service
    protocol (writing tp with the return address, and clearing/setting GIE in
    gp bit 0). x2 (sp) is reset to 0x2000 -- see section 5.

CONTROL.VHD
    Main instruction decoder: produces ALUop, branch, jump, memory and
    register-write control from opcode/funct fields.

EXECUTE.VHD
    ALU, branch condition evaluation, and the RV32M multiplier (four lpm_mult
    instances mapping to four 9-bit embedded multipliers).

DMEMORY.VHD
    The 8 KiB DTCM (altsyncram, M9K), clocked on the falling edge of MCLK per
    project definition Figure 3 so that address generation and the memory
    access fit in one CPU cycle. Also carries ENABLE_RUNTIME_MOD = YES with
    INSTANCE_NAME = DTCM for ISMCE access.

MEMORY-MAPPED I/O
-----------------
bus_interface.vhd
    Address decode for the SFR region (0x2000-0x3FFC), peripheral chip selects,
    the write strobe distribution and the read-data multiplexer back to the CPU.
    Instantiates the GPIO block, the Basic Timer and the interrupt controller.

gpio.vhd
    The GPIO register block: LEDR, the six HEX display registers, and the SW /
    pushbutton inputs, at their assigned SFR addresses.

seg7.vhd
    Binary-to-seven-segment decoder. Instantiated six times (one per HEX digit)
    through a generate statement.

BASIC TIMER
-----------
BasicTimer.vhd
    Structural top of the timer. Wires the five sub-blocks together and exposes
    the control-register bit fields as named aliases (BTOUTMD, BTOUTEN, BTHOLD,
    BTSSEL, BTCLR, BTINT, CAPMD, CAPISEL). Registers the interrupt event so a
    combinational glitch cannot clock a phantom BTIFG.

bt_prescaler.vhd
    BTSSEL clock divider. Implemented as a clock ENABLE ("tick") rather than the
    4:1 clock multiplexer drawn in Figure 7 -- functionally identical, but it
    keeps the design on a single clock network so fmax stays analysable.

bt_counter.vhd
    BTCNT, the up-counter, plus the two compares against BTCL0 and BTCL1 that
    generate the EUQ0 / EUQ1 events.

bt_output_unit.vhd
    The PWM output. Per Figure 8 Mode 0 the output is set on EUQ1 and reset on
    EUQ0, so the high fraction is (BTCL0 - BTCL1) / BTCL0.

bt_capture.vhd
    Input capture: the CAPISEL source multiplexer, a two-flop synchroniser, edge
    detection per CAPMD, and the latch of BTCNT into BTCAPR.

bt_regs.vhd
    The timer's register file: BTCTL1, BTCTL2, BTCMPR0/1 and their latched
    shadows BTCL0/BTCL1, and BTCAPR. Handles the byte/word address decode.

INTERRUPT SUBSYSTEM
-------------------
intr_ctrl.vhd
    The interrupt controller: the IE (0x202C), IFG (0x202D) and TYPE (0x202E)
    registers, the pending term (IFG AND IE), the priority encoder, and the INTR
    output. TYPE is emitted already multiplied by four, so it is the byte address
    of the vector-table entry.

intr_fsm.vhd
    The CPU-side service protocol of project definition page 15: triggered by
    the INTA falling edge, it runs two cycles -- cycle 1 clears GIE, asserts
    INTA and captures TYPE from the data bus; cycle 2 clears the source flag and
    emulates the load of Mem[TYPE] and the jalr to it, with tp holding the
    return address. reti (jalr x0, 0(tp)) restores GIE.

DIVIDER ACCELERATOR
-------------------
divider.vhd
    The 32-cycle sequential divider producing Quotient and Residue, running in
    the DIVCLK domain.

div_stall_ctrl.vhd
    Detects a div/rem instruction, raises DIVENA, and holds the CPU stalled
    (freezing the PC) until the synchronised DIVBUSY has dropped.

cdc_sync.vhd
    The two-flip-flop clock-domain-crossing synchroniser of Figure 10b, used
    three times: the two 32-bit operands and DIVENA cross MCLK -> DIVCLK, and
    DIVBUSY crosses DIVCLK -> MCLK. Carries an AUTO_SHIFT_REGISTER_RECOGNITION
    OFF attribute -- without it Quartus merges the three instances into a
    RAM-based shift register, which is not a valid metastability barrier.

CLOCKING
--------
PLL.vhd
    altpll wrapper. c0 = MCLK (the CPU clock) and c1 = DIVCLK (the accelerator
    clock). Instantiated only when G_MODELSIM = 0.


================================================================================
2. TB/RV32IMscMCU
================================================================================

tb_RV32IMscMCU.vhd
    The single system testbench. It is benchmark-agnostic: it instantiates the
    complete MCU and leaves SW and PB undriven, so everything that differs
    between benchmarks (memory images, run length, board stimulus) lives in the
    .do files. The project definition names one testbench file, so the
    per-benchmark differences deliberately do not live here.

    It also produces the golden-model artefact. The DTCM is an altsyncram whose
    storage ModelSim ASE's "mem save" cannot reach, so the bench mirrors the
    memory -- pre-loaded from the same image the hardware memory is initialised
    from, then updated on every committed store -- and writes it out as DTCM.mem
    in the same one-word-per-line hex format as the RARS golden file.

    Finally it accumulates the two IPC counters (see section 6).


================================================================================
3. SIM/RV32IMscMCU
================================================================================

Besides the ModelSim *.do scripts this folder holds the benchmark memory images,
because nothing else can hold them: the submission may contain only the folders
named in Table 1, and both the .do scripts and the design's memory initialisers
read these files by path. Every file below is a required input -- no simulation
output or build artefact is shipped here.

compile.do              Shared compile step: creates the library, maps altera_mf,
                        and compiles all 24 design files plus the testbench with
                        -2008. Sourced by every runner; not run on its own.

run_<benchmark>.do      One runner per benchmark. Each stages that benchmark's
                        memory images, compiles, elaborates, loads waves.do when
                        running in the GUI, applies the benchmark's board
                        stimulus, runs, and dumps DTCM.mem.

waves.do                Report-quality wave layout: signals grouped under
                        dividers (CPU / interrupt protocol / IE-IFG-TYPE / Basic
                        Timer / accelerator / board I/O) and colour-coded.

mem/<benchmark>/        The memory images each runner stages: ITCM.hex, DTCM.hex,
                        the plain-text DTCM_init.txt used to pre-load the
                        testbench's DTCM mirror, and -- for rv32im_test1 only --
                        DTCM_golden.txt, the RARS post-run reference.

ITCM.hex, DTCM.hex      The images the memory initialisers read. IFETCH.VHD and
                        DMEMORY.VHD declare
                            init_file => "SIM/RV32IMscMCU/{ITCM,DTCM}.hex"
                        so these two files must be present for the design to
                        compile at all -- in Quartus especially, where no .do
                        script runs first to stage them. Each runner overwrites
                        them with its own benchmark's images before compiling,
                        so the copies shipped here are simply whichever
                        benchmark was built last.

                        The runners also stage DTCM_init.txt from mem/ into this
                        folder at run time, and the testbench writes DTCM.mem
                        here at the end of a run -- the golden-model artefact
                        named in project definition step 8.c.i. Neither is
                        shipped, since both are produced by running.

HOW TO RUN -- from the submission root (the folder holding DUT/ TB/ SIM/):

    vsim -c -do SIM/RV32IMscMCU/run_rv32im_test1.do

Available runners:

    run_rv32im_test1.do     RV32IM/test1  -- mul / div / rem, exercises the
                            accelerator; the only benchmark that terminates and
                            the only one with a RARS golden file
    run_gpio_test0.do       GPIO/test0    -- count up on LEDR and the HEX array
    run_gpio_test1.do       GPIO/test1    -- SW = 0x01, count up
    run_gpio_test2.do       GPIO/test2    -- SW = 0x02, count down
    run_intr_test1.do       Interrupt/test1 -- single KEY1 interrupt, the page-15
                            service protocol end to end
    run_intr_test2.do       Interrupt/test2 -- vector dispatch across KEY1/2/3
                            and the Basic Timer
    run_intr_test3.do       Interrupt/test3 -- the four programmable timer
                            intervals
    run_intr_test4.do       Interrupt/test4 -- PWM output and input capture


================================================================================
4. Quartus/RV32IMscMCU
================================================================================

RV32I_CORE.sdc          Timing constraints. Creates CLOCK_50 on clk_i, derives
                        the two PLL output clocks, derives clock uncertainty,
                        and declares MCLK and DIVCLK asynchronous -- every
                        crossing between them goes through cdc_sync, so timing
                        them against each other would report violations that the
                        synchronisers exist to make irrelevant.

stp_tot.stp             The Signal-Tap configuration used for hardware
                        validation: the CPU program flow, the INTR/INTA service
                        handshake, the IE/IFG/TYPE registers, the Basic Timer
                        datapath, the accelerator handshake and the board I/O.

RV32IMscMCU.sof         The programming file for the DE2-115 (EP4CE115F29C7).


================================================================================
5. BUILD SWITCH -- read this before compiling
================================================================================

cond_compilation_package.vhd, line 51, carries G_MODELSIM:

    G_MODELSIM = 0   Quartus / FPGA.  The PLL is instantiated (MCLK = 25 MHz,
                     DIVCLK = 150 MHz) and the reset is inverted, because KEY0 on
                     the DE2-115 reads '1' when it is NOT pressed while the
                     design uses an active-high reset.
                     >>> THIS IS THE SHIPPED VALUE. <<<

    G_MODELSIM = 1   ModelSim.  The PLL is bypassed (MCLK is driven directly by
                     clk_i), DIVCLK is generated by a simulation-only clock
                     process at six times the MCLK rate, and the reset is taken
                     active-high to match the testbench.

The two settings are mutually exclusive: with G_MODELSIM = 0 the PLL has no
simulation model bound, so the core cannot be simulated.

    To simulate  : set G_MODELSIM = 1, then run a .do file.
    To build     : set G_MODELSIM = 0, then compile in Quartus.

Both configurations compile without errors, as required.

A second note on tools: const_package.vhd uses VHDL-2008 sized bit-string
literals. compile.do passes -2008 automatically; in the Quartus GUI the VHDL
version must be set to VHDL 2008 (Settings -> VHDL Input).


================================================================================
6. VERIFICATION
================================================================================

6.1  Golden-model comparison
-----------------------------
Project definition steps 8.c.i (ModelSim) and 8.e.i (hardware) compare the RARS
reference against DTCM.mem / the ISMCE DTCM readback.

Of the benchmarks supplied with the assignment, only RV32IM/test1 ships a RARS
post-run golden, because it is the only program that terminates -- the GPIO and
interrupt benchmarks sit in an FSM loop forever, so there is no end-of-run state
to dump. run_rv32im_test1.do performs that comparison automatically and reports
PASS / FAIL; the result is PASS on all 1024 words.

The remaining seven benchmarks are checked behaviourally (LEDR / HEX / PWM /
interrupt sequencing observed in the waveform), and on hardware their ISMCE DTCM
readback is compared against the DTCM.mem produced by the same benchmark in
simulation -- a hardware-versus-simulation check rather than a RARS golden.

6.2  IPC
--------
LAB5 task definition clause 6.iii.b, referenced by project definition steps
8.c.iii and 8.e.iii:

    IPC = (CLKCNT_o - (STCNT_o + 4 + depth*FHCNT_o)) / CLKCNT_o
        =  InstructionCounter / CLKCNT_o

For a single-cycle core there are no flushes and no pipeline fill, so this
reduces to IPC = (CLKCNT - STCNT) / CLKCNT.

Both counters are accumulated in the TESTBENCH, not in the design. CLKCNT counts
clocks; STCNT counts cycles in which pc_o is held, which is what a divider stall
or an interrupt service does. pc_o is already a top-level output, so measuring
IPC required no hardware counter and no change to the architecture.

Measured on RV32IM/test1:

    CLKCNT = 643    STCNT = 130    retired = 513    IPC = 0.798

RARS reports 513 instructions executed for the same program, so the two sides of
the equation agree exactly and the IPC check passes.

STCNT breaks down as 16 stalling instructions (8 div + 8 rem) x 8 cycles each,
plus 2 cycles of edge effects. The 8 cycles per divide is the accelerator running
in its own 150 MHz DIVCLK domain; with the divider clocked at MCLK it would be 32
cycles per operation, giving STCNT = 514, CLKCNT = 1027 and IPC = 0.500. Moving
the accelerator into DIVCLK therefore lifts IPC from 0.50 to 0.80 on this
benchmark.

6.3  Hardware validation
------------------------
Project definition step 8.e, performed on the DE2-115 with ISMCE and Signal-Tap.
Both TCMs carry ENABLE_RUNTIME_MOD, so all eight benchmarks were run from a
single compilation, with ISMCE writing each benchmark's ITCM.hex and DTCM.hex
over JTAG.

    RV32IM/test1    Signal-Tap shows the program reaching its terminal loop with
                    mclk_cnt_o = 643 -- identical to the simulated cycle count --
                    and the ISMCE DTCM readback matches DTCM_golden.txt exactly.
    Interrupt/1-4   The page-15 service protocol, the full vector set
                    (10h / 14h / 18h / 1Ch), the programmable timer intervals,
                    the PWM switching points and the input capture were all
                    captured on hardware and agree with simulation.
    GPIO/0-2        Verified behaviourally on the board.

Full results, waveforms and analysis are in DOC/Final_report.pdf.
