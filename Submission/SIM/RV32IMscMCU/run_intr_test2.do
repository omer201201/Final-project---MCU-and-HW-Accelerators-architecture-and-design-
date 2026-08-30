# ------------------------------------------------------------------------------
# run_intr_test2.do  --  Intrrupt-based IO/test2 - KEY1/2/3 interrupts
#
# Run from the SUBMISSION ROOT:   vsim -c -do SIM/RV32IMscMCU/run_intr_test2.do
# ------------------------------------------------------------------------------
set BM intr_test2
set M  SIM/RV32IMscMCU/mem/$BM

# 1) load this benchmark's memory images (the DUT's altsyncram init_file points
#    at SIM/RV32IMscMCU/{ITCM,DTCM}.hex) and the plain-text image the testbench
#    uses to pre-load its DTCM shadow.
file copy -force $M/ITCM.hex      SIM/RV32IMscMCU/ITCM.hex
file copy -force $M/DTCM.hex      SIM/RV32IMscMCU/DTCM.hex
file copy -force $M/DTCM_init.txt SIM/RV32IMscMCU/DTCM_init.txt

# 2) compile
do SIM/RV32IMscMCU/compile.do

# 3) elaborate
vsim -L altera_mf -L lpm -voptargs=+acc work.tb_RV32IMscMCU
onbreak {quit -f}
onerror {quit -f}

if {![batch_mode]} {
    # Full colour-coded, grouped wave set, loaded BEFORE the run so everything is
    # recorded from t=0. Do NOT "restart" to add waves afterwards: restart clears
    # every force, including the board stimulus applied below, and the benchmark
    # would then run with the wrong inputs.
    do SIM/RV32IMscMCU/waves.do
}

# 4) benchmark-specific stimulus + run
# PB is std_logic_vector(2 downto 0); ModelSim reads a bare number for a vector
# as a BINARY string, so values are given as binary. KEYs are active-low, so
# released = 111 and pressing bit N drives that one bit to 0.
proc press {bit} {
    set v [list 1 1 1]
    lset v [expr {2 - $bit}] 0
    force -deposit /tb_RV32IMscMCU/PB [join $v ""]
    run 600 ns
    force -deposit /tb_RV32IMscMCU/PB 111
    run 600 ns
}
run 5 us
press 0 ; run 20 us
press 1 ; run 20 us
press 2 ; run 30 us

# 5) take the end-of-run DTCM image -> SIM/RV32IMscMCU/DTCM.mem
force -deposit /tb_RV32IMscMCU/dump_req 1
run 10 ns

puts "=============================================="
puts "DTCM.mem written. NOTE: this benchmark ships no RARS post-run golden"
puts "(its program never terminates), so verification here is behavioural --"
puts "inspect the waveform / LEDR / HEX outputs. Only rv32im_test1 has a"
puts "golden file for an automatic compare."
puts "=============================================="

# Batch runs exit; a GUI run stays open so the waveform can be inspected.
if {[batch_mode]} { quit -f }
