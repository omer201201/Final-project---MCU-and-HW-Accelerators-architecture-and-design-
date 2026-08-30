# run_gpio2.do -- full-core MMIO sim on benchmark GPIO/test2 (6-digit HEX + SW up/down/hold)
# Usage (from the project root):
#     cd C:/Users/omer2/VHDL/Final_Project
#     do SIM/RV32IMscMCU/run_gpio2.do
# Prereq: G_MODELSIM = 1 in cond_compilation_package.vhd (bypass PLL for sim).

file copy -force {Benchmark apps/GPIO/test2/bin/M9K-intel/ITCM.hex} SIM/RV32IMscMCU/ITCM.hex
file copy -force {Benchmark apps/GPIO/test2/bin/M9K-intel/DTCM.hex} SIM/RV32IMscMCU/DTCM.hex

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
vcom -2008 $D/bus_interface.vhd
vcom -2008 $D/divider.vhd
vcom -2008 $D/div_stall_ctrl.vhd
vcom -2008 $D/RV32I_CORE.vhd
vcom -2008 TB/RV32IMscMCU/tb_core_gpio_test2.vhd

vsim -L altera_mf -L lpm work.tb_core_gpio_test2

# key signals: SW stimulus + the SIX distinct HEX digits (pre-seg7) + count
add wave -radix hexadecimal /tb_core_gpio_test2/clk
add wave -radix hexadecimal /tb_core_gpio_test2/rst
add wave -radix hexadecimal /tb_core_gpio_test2/SW
add wave -radix unsigned    /tb_core_gpio_test2/pc_o
add wave -radix hexadecimal /tb_core_gpio_test2/alu_res_o
add wave -radix hexadecimal /tb_core_gpio_test2/CORE/BUSIF/is_peripheral
add wave -radix unsigned    /tb_core_gpio_test2/LEDR
add wave -radix unsigned    /tb_core_gpio_test2/CORE/BUSIF/U_GPIO/ledr_q
add wave -radix hexadecimal /tb_core_gpio_test2/CORE/BUSIF/U_GPIO/hex_q

run 40 us
wave zoom full
