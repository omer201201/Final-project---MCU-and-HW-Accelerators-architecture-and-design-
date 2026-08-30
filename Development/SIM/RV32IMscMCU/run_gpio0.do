# run_gpio0.do -- full-core MMIO sim on benchmark GPIO/test0 (GPO: LEDR + HEX0-5)
# Usage in ModelSim (from the project root):
#     cd C:/Users/omer2/VHDL/Final_Project
#     do SIM/RV32IMscMCU/run_gpio0.do
#
# Prereq: G_MODELSIM = 1 in cond_compilation_package.vhd (bypass PLL for sim).

# 0. load the GPIO/test0 program+data images into the paths the core init_file uses
file copy -force {Benchmark apps/GPIO/test0/bin/M9K-intel/ITCM.hex} SIM/RV32IMscMCU/ITCM.hex
file copy -force {Benchmark apps/GPIO/test0/bin/M9K-intel/DTCM.hex} SIM/RV32IMscMCU/DTCM.hex

# 1. fresh work library + map the Altera megafunction lib (for altsyncram)
if {[file exists work]} { vdel -all }
vlib work
vmap work work
vmap altera_mf C:/intelFPGA/20.1/modelsim_ase/altera/vhdl/altera_mf

# 2. compile the whole DUT in dependency order (VHDL-2008).
#    PLL.vhd is skipped: with MODELSIM=1 the PLL is not instantiated.
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
vcom -2008 TB/RV32IMscMCU/tb_core_gpio_test0.vhd

# 3. load the testbench (link altera_mf + lpm for altsyncram)
vsim -L altera_mf -L lpm work.tb_core_gpio_test0

# 4. key GPIO signals
add wave -radix hexadecimal /tb_core_gpio_test0/clk
add wave -radix hexadecimal /tb_core_gpio_test0/rst
add wave -radix unsigned    /tb_core_gpio_test0/pc_o
add wave -radix hexadecimal /tb_core_gpio_test0/instruction_o
add wave -radix hexadecimal /tb_core_gpio_test0/alu_res_o
add wave -radix hexadecimal /tb_core_gpio_test0/MemWrite_ctrl_o
add wave -radix unsigned    /tb_core_gpio_test0/LEDR
add wave -radix hexadecimal /tb_core_gpio_test0/HEX0
add wave -radix hexadecimal /tb_core_gpio_test0/HEX1
add wave -radix hexadecimal /tb_core_gpio_test0/HEX5
# raw digit values BEFORE seg7 encoding -> readable as 0,1,2,3,...,F
add wave -radix hexadecimal /tb_core_gpio_test0/CORE/BUSIF/U_GPIO/hex_q
add wave -radix unsigned    /tb_core_gpio_test0/CORE/BUSIF/U_GPIO/ledr_q

# 5. run; the self-checking process reports PASS/FAIL and stops the clock
run 20 us
wave zoom full
