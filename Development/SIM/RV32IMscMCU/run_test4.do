# run_test4.do -- full-core single-cycle RV32IM sim, running benchmark test4
# Usage in ModelSim:
#     cd C:/Users/ilay2/Desktop/LAB5/Lab5-RISCV/Lab5-VHDL
#     do SIM/run_test4.do
#
# Prereqs:
#   - G_MODELSIM = 1 in cond_compilation_package.vhd  (bypass PLL)
#   - IFETCH.VHD  init_file -> test4/RV32IM .../ITCM.hex
#   - DMEMORY.VHD init_file -> test4/RV32IM .../DTCM.hex
#     (BOTH must point at test4)
#
# Reference (RARS golden):
#   InstructionCounter = 2734 , end-PC = 0x04C (76) , CLKCNT @ end = 2735
#   IPC = 2734 / 2735 = 0.9996 ~= 1

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

# 4. apply the full grouped wave layout (IFETCH/IDECODE/CONTROL/EXECUTE/DMEMORY)
#    and log every signal so nothing shows "No Data" after the run.
do SIM/RV32I.do
log -r /*

# 5. run from t=0. test4 finishes ~273 us; 500 us leaves margin (end self-loop is harmless).
run 500 us
wave zoom full

# 6. list memory instances so we can dump DTCM for the golden compare
echo "==== memory instances (for DTCM dump) ===="
mem list
