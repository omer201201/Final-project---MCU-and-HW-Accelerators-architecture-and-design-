# ------------------------------------------------------------------------------
# run_rv32im_test1.do  --  RV32IM/test1 - div/mul/rem, the one benchmark with a RARS golden
#
# Run from the SUBMISSION ROOT:   vsim -c -do SIM/RV32IMscMCU/run_rv32im_test1.do
# ------------------------------------------------------------------------------
set BM rv32im_test1
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
run 2 ms

# 5) take the end-of-run DTCM image -> SIM/RV32IMscMCU/DTCM.mem
force -deposit /tb_RV32IMscMCU/dump_req 1
run 10 ns

# 6) golden-model comparison (spec 8.c.i): RARS DTCM.h vs ModelSim DTCM.mem
#    Wrapped in a proc so Tcl does not echo intermediate command results.
proc compare_golden {goldfile memfile} {
    set fg [open $goldfile r] ; set g [split [string trim [read $fg]] "
"] ; close $fg
    set fm [open $memfile  r] ; set m [split [string trim [read $fm]] "
"] ; close $fm
    set n   [llength $g]
    set bad 0
    for {set i 0} {$i < $n} {incr i} {
        set gv [string tolower [string trim [lindex $g $i]]]
        set mv [string tolower [string trim [lindex $m $i]]]
        if {$gv ne $mv} {
            incr bad
            if {$bad <= 8} { puts [format "  MISMATCH word %4d : golden=%s  modelsim=%s" $i $gv $mv] }
        }
    }
    puts "=============================================="
    if {$bad == 0} {
        puts "RESULT: PASS  ($n/$n DTCM words match the RARS golden)"
    } else {
        puts "RESULT: FAIL  ($bad of $n DTCM words differ)"
    }
    puts "=============================================="
}
compare_golden SIM/RV32IMscMCU/mem/rv32im_test1/DTCM_golden.txt SIM/RV32IMscMCU/DTCM.mem

# Batch runs exit; a GUI run stays open so the waveform can be inspected.
if {[batch_mode]} { quit -f }
