=======================================================================================
  test4_modified  --  corrected variant of "Intrrupt-based IO / test4"
=======================================================================================

WHY THIS FOLDER EXISTS
----------------------
test4 as distributed cannot exercise the Basic Timer input-capture unit, and its two
array routines never execute. Those are application bugs, not MCU bugs -- they were
confirmed by disassembling the shipped bin/M9K-intel/ITCM.hex, not just by reading the
sources. This folder is a corrected copy so the capture path and the div/rem arrays can
actually be validated on hardware.

The original folder is untouched. Use this one only for the capture demo; report both.


WHAT WAS WRONG (evidence from the ORIGINAL binary)
--------------------------------------------------
1) div_arrays / rem_arrays never ran.

     0x440  02dec263  blt   t4,a3,0x464     <- guard is INVERTED
     0x444  000c2303  lw    t1,0(s8)
     ...
     0x460  001e8e93  addi  t4,t4,1
     0x464  00008067  ret                   <- and there is NO branch back

   Entered with t4=0 and a3=SIZE=10, "blt t4,a3" is true, so it jumps straight to the
   ret. Even with the guard corrected the body would run once, because the loop has no
   backward branch at all. divarr and remarr stayed all-zero.

2) The capture input never changed state.

     0x408  00700293  li t0,7     (capture_init)  -> BTCTL2 = 0x07
     0x41C  00700293  li t0,7     (capture)       -> BTCTL2 = 0x07

   BTCTL2 = 0x07 is CAPMD=01 (rising edge), CAPISEL=11 (=3, GND). Both writes select
   GND, so the capture source sat at '0' forever and no rising edge was ever produced.
   The source comment on the second one says "set the input signal to VCC", but the
   constant CAPMD1_CAPISEL2 (0x06) it needed was never defined in io_map.s.

3) capture_init disarmed the capture path it was supposed to arm.

     0x3F8  02400293  li t0,0x24   -> BTCTL1 = BTHOLD_BTCLR

   0x24 has BTINT=00, which undid the BTINT=2 that bt_capture_config had just set, so a
   capture event could no longer drive BTIFG. It also left BTHOLD=1, freezing BTCNT --
   so even a working capture would have measured zero elapsed time.

4) STATE3 fell through both branches. There was no jump after the div branch, so the
   rem branch ran on every pass too and "andi t4,a7,1" selected nothing.

5) (cosmetic, but it hides the KEY1 demo) FSM_START began with "li a0,0" +
   "call print2HEXsArr". The FSM loop is ~2 us, so a0 was re-zeroed and the display
   blanked continuously; the STATE1 count was never visible.


CHANGES MADE  (every edit is marked "# [MOD]" in the sources)
-------------------------------------------------------------
io_map.s     + .eqv CAPMD1_CAPISEL2  0x06     (rising edge, source = VCC)

01_func.s    capture_init : BTCTL1 = BTHOLD_BTCLR_BTINT2 (0x26) to clear the counter
                            with BTINT=2 still selected, arm CAPMD=rising/CAPISEL=GND,
                            then BTCTL1 = BTINT2 (0x02) to RELEASE the counter.
                            BTSSEL=0 -> one tick per SMCLK, so BTCAPR ends up holding
                            the elapsed CPU-cycle count directly.
             capture      : BTCTL2 = CAPMD1_CAPISEL2 (0x06) -- drives the source
                            '0'->'1', the rising edge the unit is armed for.
             div_arrays   : guard "blt"->"bge", and a "j for_l" back-edge added.
             rem_arrays   : same two fixes.

00_main.s    HEX clear moved out of FSM_START into main's init (runs once).
             "j END" added after the STATE3 div branch.

Nothing else was touched. print2*, intr_config, bt_cmp_config, bt_outcmp_config and
bt_capture_config are byte-identical in behaviour to the original.


HOW THE BINARY WAS BUILT
------------------------
bin/M9K-intel/{ITCM,DTCM}.hex were produced by a small RV32IM assembler written for
this project, NOT by RARS. It was validated by re-assembling the unmodified test2,
test3 and test4 sources and diffing against Ribo's own bin/M9K-intel images:

     test2   ITCM 121 words   0 mismatches    DATA 10 words   0 mismatches
     test3   ITCM 139 words   0 mismatches    DATA 10 words   0 mismatches
     test4   ITCM 296 words   0 mismatches    DATA 51 words   0 mismatches

Byte-for-byte identical on all three, including RARS pseudo-instruction expansions
(mv -> add rd,zero,rs; call -> auipc x6 + jalr x1; PC-relative la) and the flat
Harvard layout with .text and .data both based at 0.

This image: ITCM 303 words (0x000..0x4B8), DATA 51 words.


MEMORY MAP OF THIS IMAGE
------------------------
  ITCM                              DTCM
    0x000  main                       0x0000  interrupt vector table (8 words)
    0x134  KEY1_ISR                   0x0020  state
    0x170  KEY2_ISR                   0x0024  arr1 = 81..90
    0x1AC  KEY3_ISR                   0x004C  arr2 = 11..20
    0x1E8  BT_ISR                     0x0074  divarr  (10 words)
    0x230  UartRX_ISR                 0x009C  remarr  (10 words)
    0x234  UartTX_ISR                 0x00C4  runtime_div
                                      0x00C8  runtime_rem

  Vector table:  TYPE 0x10 -> 0x1E8 (BT)    0x14 -> 0x134 (KEY1)
                 TYPE 0x18 -> 0x170 (KEY2)  0x1C -> 0x1AC (KEY3)


EXPECTED BEHAVIOUR ON THE BOARD
-------------------------------
KEY1  Compare mode. a0 now accumulates and is displayed across HEX5..HEX0.
      Interval steps 1x, 1/2, 1/4, 1/8 of SEC_PERIOD as a7 advances.
      At MCLK=25MHz with BTSSEL=3 (/8) the base interval is ~6.4 s, not 1 s --
      SEC_PERIOD assumes SMCLK=20MHz and /1.

KEY2  Output compare / PWM on pwm_o. Period 500 ticks x 8 = 160 us = 6.25 kHz.
      Duty follows Figure 8 Mode 0: high fraction = (BTCL0-BTCL1)/BTCL0, i.e. the
      COMPLEMENT of the source comments except at 0.5. Unchanged from the original.

KEY3  Input capture -- this is what the folder is for. Now measures real elapsed
      SMCLK cycles across div_arrays / rem_arrays and stores the result via BT_ISR.

      Which branch runs is "a7 & 1" AFTER the ISR has incremented a7, so the FIRST
      KEY3 press from reset takes the REM branch and they alternate from there.
      a7 counts every key press, not just KEY3 -- press KEY3 twice to get both.

        odd  a7 : remarr = 4, 10, 5, 0, 10, 6, 2, 16, 13, 10   runtime_rem @ 0x00C8
        even a7 : divarr = 7, 6, 6, 6, 5, 5, 5, 4, 4, 4        runtime_div @ 0x00C4

      STATE3 keeps re-running for as long as state==3, so the values are recomputed
      every FSM pass and settle to a stable reading.

      Read them back with the In-System Memory Content Editor (instance DTCM).
      Those 20 values are a genuine golden-model comparison for the div/rem
      accelerator -- the only one of the four interrupt benchmarks that produces one.


KNOWN LIMITATION (inherited, deliberately NOT fixed)
----------------------------------------------------
The ISRs save no context. BT_ISR uses t1/t2/t3 and print2HEXsArr clobbers s1/s2, while
div_arrays is live in t1/t2/t3/s8/s9/s10. An interrupt landing inside div_arrays will
corrupt the result. In practice the only BT interrupt in STATE3 is the capture event
raised at the END of the routine, so it does not bite -- but pressing a KEY during the
measurement can. Fixing it means adding a stack save/restore, which is a much larger
deviation from Ribo's code than the bug fixes above.


BEFORE THE DEMO
---------------
This is a MODIFIED benchmark. Show the original test4 result as well, and tell the
instructor which findings drove the changes. The analysis of why the original cannot
exercise the capture unit is worth more in the report than the passing run.
