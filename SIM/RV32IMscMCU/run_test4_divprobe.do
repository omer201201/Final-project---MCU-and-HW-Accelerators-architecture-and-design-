# run_test4_divprobe.do -- instrumented root-cause probe for the div-array
#   memory mismatch on benchmark "Intrrupt-based IO/test4_modified".
#   Presses KEY3 twice (REM then DIV) and snapshots divarr per div_arrays pass,
#   flagging passes where an interrupt landed inside div_arrays.  Prereq: G_MODELSIM=1.
#     cd C:/Users/omer2/VHDL/Final_Project
#     vsim -c -do SIM/RV32IMscMCU/run_test4_divprobe.do

file copy -force {Benchmark apps/Intrrupt-based IO/test4_modified/bin/M9K-intel/ITCM.hex} SIM/RV32IMscMCU/ITCM.hex
file copy -force {Benchmark apps/Intrrupt-based IO/test4_modified/bin/M9K-intel/DTCM.hex} SIM/RV32IMscMCU/DTCM.hex

if {[file exists work]} { vdel -all }
vlib work
vmap work work
vmap altera_mf C:/intelFPGA/20.1/modelsim_ase/altera/vhdl/altera_mf

set D DUT/RV32IMscMCU
vcom -2008 $D/cond_compilation_package.vhd
vcom -2008 $D/const_package.vhd
vcom -2008 $D/aux_package.vhd
vcom -2008 $D/IFETCH.VHD
vcom -2008 $D/IDECODE.VHD
vcom -2008 $D/CONTROL.VHD
vcom -2008 $D/EXECUTE.VHD
vcom -2008 $D/DMEMORY.VHD
vcom -2008 $D/seg7.vhd
vcom -2008 $D/gpio.vhd
vcom -2008 $D/bt_prescaler.vhd
vcom -2008 $D/bt_counter.vhd
vcom -2008 $D/bt_output_unit.vhd
vcom -2008 $D/bt_capture.vhd
vcom -2008 $D/bt_regs.vhd
vcom -2008 $D/BasicTimer.vhd
vcom -2008 $D/intr_ctrl.vhd
vcom -2008 $D/bus_interface.vhd
vcom -2008 $D/divider.vhd
vcom -2008 $D/div_stall_ctrl.vhd
vcom -2008 $D/intr_fsm.vhd
vcom -2008 $D/RV32I_CORE.vhd
vcom -2008 TB/RV32IMscMCU/tb_core_test4_divprobe.vhd

vsim -L altera_mf -L lpm work.tb_core_test4_divprobe
onerror {quit -f}

run 90 us
quit -f
