# run_test2_intr.do -- full-core interrupt end-to-end on benchmark
#   "Intrrupt-based IO/test2" (KEY-driven). Prereq: G_MODELSIM=1.
#     cd C:/Users/omer2/VHDL/Final_Project
#     vsim -c -do SIM/RV32IMscMCU/run_test2_intr.do        (batch)

# 0. load the interrupt-test2 program+data images
file copy -force {Benchmark apps/Intrrupt-based IO/test2/bin/M9K-intel/ITCM.hex} SIM/RV32IMscMCU/ITCM.hex
file copy -force {Benchmark apps/Intrrupt-based IO/test2/bin/M9K-intel/DTCM.hex} SIM/RV32IMscMCU/DTCM.hex

# 1. fresh work library + Altera megafunction lib (altsyncram)
if {[file exists work]} { vdel -all }
vlib work
vmap work work
vmap altera_mf C:/intelFPGA/20.1/modelsim_ase/altera/vhdl/altera_mf

# 2. compile the whole DUT in dependency order (VHDL-2008)
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
vcom -2008 TB/RV32IMscMCU/tb_core_test2_intr.vhd

# 3. elaborate
vsim -L altera_mf -L lpm work.tb_core_test2_intr
onbreak {resume}
onerror {quit -f}

# 4. useful waves (GUI); harmless in batch
add wave -radix unsigned    /tb_core_test2_intr/pc_o
add wave -radix hexadecimal /tb_core_test2_intr/instruction_o
add wave -radix hexadecimal /tb_core_test2_intr/intr
add wave              /tb_core_test2_intr/CORE/svc_active_w
add wave -radix hex   /tb_core_test2_intr/CORE/type_captured_q
add wave -radix unsigned /tb_core_test2_intr/observed_state
add wave              /tb_core_test2_intr/PB

# 5. run to completion (the stim process stops the clock via sim_done)
run 12 us
quit -f
