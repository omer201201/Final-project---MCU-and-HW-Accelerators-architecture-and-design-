# ------------------------------------------------------------------------------
# run_gpio_test2.do  --  GPIO/test2 - SW=0x02 count down on HEX array
#
# Run from the SUBMISSION ROOT:   vsim -c -do SIM/RV32IMscMCU/run_gpio_test2.do
# ------------------------------------------------------------------------------
set BM gpio_test2
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
force -deposit /tb_RV32IMscMCU/SW 00000010
run 200 us

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
