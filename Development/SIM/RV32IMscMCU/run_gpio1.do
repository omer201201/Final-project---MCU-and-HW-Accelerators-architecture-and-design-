# run_gpio1.do -- full-core MMIO sim on benchmark GPIO/test1 (GPI: SW-driven up/down/hold)
# Usage (from the project root):
#     cd C:/Users/omer2/VHDL/Final_Project
#     do SIM/RV32IMscMCU/run_gpio1.do
# Prereq: G_MODELSIM = 1 in cond_compilation_package.vhd (bypass PLL for sim).

# 0. load the GPIO/test1 program+data images
file copy -force {Benchmark apps/GPIO/test1/bin/M9K-intel/ITCM.hex} SIM/RV32IMscMCU/ITCM.hex
file copy -force {Benchmark apps/GPIO/test1/bin/M9K-intel/DTCM.hex} SIM/RV32IMscMCU/DTCM.hex

# 1. fresh work library + map the Altera megafunction lib (for altsyncram)
if {[file exists work]} { vdel -all }
vlib work
vmap work work
vmap altera_mf C:/intelFPGA/20.1/modelsim_ase/altera/vhdl/altera_mf

# 2. compile the whole DUT in dependency order (VHDL-2008). PLL skipped (MODELSIM=1).
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
vcom -2008 TB/RV32IMscMCU/tb_core_gpio_test1.vhd

# 3. load the testbench (link altera_mf + lpm for altsyncram)
vsim -L altera_mf -L lpm work.tb_core_gpio_test1

# 4. key signals: the SW stimulus, the read, and the counter response
add wave -radix hexadecimal /tb_core_gpio_test1/clk
add wave -radix hexadecimal /tb_core_gpio_test1/rst
add wave -radix hexadecimal /tb_core_gpio_test1/SW
add wave -radix unsigned    /tb_core_gpio_test1/pc_o
add wave -radix hexadecimal /tb_core_gpio_test1/alu_res_o
add wave -radix hexadecimal /tb_core_gpio_test1/MemWrite_ctrl_o
add wave -radix hexadecimal /tb_core_gpio_test1/CORE/BUSIF/is_peripheral
add wave -radix unsigned    /tb_core_gpio_test1/LEDR
add wave -radix unsigned    /tb_core_gpio_test1/CORE/BUSIF/U_GPIO/ledr_q
add wave -radix hexadecimal /tb_core_gpio_test1/CORE/BUSIF/U_GPIO/hex_q

# 5. run; the self-checking process reports PASS/FAIL and stops the clock
run 15 us
wave zoom full
