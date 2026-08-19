# run_test1.do -- full-core single-cycle RV32IM sim, running benchmark test1 (mul)
# Usage in ModelSim:
#     cd C:/Users/omer2/VHDL/Lab5-VHDL
#     do SIM/run_test1.do
#
# Prereqs:
#   - G_MODELSIM = 1 in cond_compilation_package.vhd  (bypass PLL)
#   - IFETCH.VHD / DMEMORY.VHD init_file paths point at test1/RV32IM .hex files
#     (each testN run requires re-pointing those two init_file paths)

# 1. fresh work library + map the Altera megafunction lib (for altsyncram)
if {[file exists work]} { vdel -all }
vlib work
vmap work work
vmap altera_mf C:/intelFPGA/20.1/modelsim_ase/altera/vhdl/altera_mf

# 2. compile the whole DUT in dependency order (VHDL-2008).
#    PLL.vhd is skipped: with MODELSIM=1 the PLL is not instantiated.
vcom -2008 DUT/cond_compilation_package.vhd
vcom -2008 DUT/const_package.vhd
vcom -2008 DUT/aux_package.vhd
vcom -2008 DUT/IFETCH.VHD
vcom -2008 DUT/IDECODE.VHD
vcom -2008 DUT/CONTROL.VHD
vcom -2008 DUT/EXECUTE.VHD
vcom -2008 DUT/DMEMORY.VHD
vcom -2008 DUT/RV32I_CORE.vhd
vcom -2008 TB/tb_RV32I.vhd

# 3. load the full-core testbench (link altera_mf + lpm for altsyncram)
vsim -L altera_mf -L lpm work.tb_RV32I

# 4. key signals for verifying mul end-to-end
add wave -radix hexadecimal /tb_rv32i/clk_i
add wave -radix hexadecimal /tb_rv32i/rst_i
add wave -radix unsigned    /tb_rv32i/pc_o
add wave -radix hexadecimal /tb_rv32i/instruction_o
add wave -radix decimal     /tb_rv32i/alu_res_o
add wave -radix hexadecimal /tb_rv32i/MemWrite_ctrl_o
add wave -radix unsigned    /tb_rv32i/dtcm_addr_o
add wave -radix decimal     /tb_rv32i/dtcm_data_wr_o

# 5. run long enough for the 8-iteration loop to finish (100ns clock)
run 50 us
wave zoom full

# 6. list memory instances so we can dump DTCM for the golden compare
echo "==== memory instances (for DTCM dump) ===="
mem list
