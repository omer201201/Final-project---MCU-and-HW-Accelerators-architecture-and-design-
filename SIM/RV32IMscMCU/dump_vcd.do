# dump_vcd.do -- generate a switching-activity VCD for Quartus PowerPlay (single-cycle)
# Usage in ModelSim:
#     cd C:/Users/ilay2/Desktop/LAB5/Lab5-RISCV/Lab5-VHDL
#     do SIM/dump_vcd.do
#
# Prereqs:
#   - G_MODELSIM = 1 in cond_compilation_package.vhd  (bypass PLL for sim)
#   - IFETCH.VHD / DMEMORY.VHD init_file -> test4/RV32IM .hex (richest activity)
#
# Output: SC_power.vcd  (feed to PowerPlay, map to the CORE instance)

# 1. fresh work library + map the Altera megafunction lib (for altsyncram)
if {[file exists work]} { vdel -all }
vlib work
vmap work work
vmap altera_mf C:/intelFPGA/20.1/modelsim_ase/altera/vhdl/altera_mf

# 2. compile the DUT in dependency order (VHDL-2008)
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

# 3. load the testbench (link altera_mf + lpm for altsyncram)
vsim -L altera_mf -L lpm work.tb_RV32I

# 4. open the VCD and record the whole core (the RV32I_CORE instance = CORE)
vcd file SC_power.vcd
vcd add -r /tb_rv32i/CORE/*

# 5. run ONLY the active window (test4 finishes ~273 us; avoid the idle self-loop
#    so the dynamic-power average is not diluted toward idle)
run 280 us

# 6. flush the VCD to disk
vcd flush
echo "==== VCD written: SC_power.vcd ===="
