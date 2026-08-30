# Single-cycle RV32IM (mul) smoke run in ModelSim -- no division.
# Loads Lab5 test1 (mul-only) images via IFETCH/DMEMORY init_file.
# Run from the project root:  do SIM/RV32IMscMCU/run_sc.do
onerror {resume}

if {[file exists work]} { vdel -all }
vlib work
vmap work work
vmap altera_mf C:/intelFPGA/20.1/modelsim_ase/altera/vhdl/altera_mf

# compile transferred DUT in dependency order (VHDL-2008); PLL skipped (G_MODELSIM=1)
vcom -2008 DUT/RV32IMscMCU/cond_compilation_package.vhd
vcom -2008 DUT/RV32IMscMCU/const_package.vhd
vcom -2008 DUT/RV32IMscMCU/aux_package.vhd
vcom -2008 DUT/RV32IMscMCU/IFETCH.VHD
vcom -2008 DUT/RV32IMscMCU/IDECODE.VHD
vcom -2008 DUT/RV32IMscMCU/CONTROL.VHD
vcom -2008 DUT/RV32IMscMCU/EXECUTE.VHD
vcom -2008 DUT/RV32IMscMCU/DMEMORY.VHD
vcom -2008 DUT/RV32IMscMCU/RV32I_CORE.vhd
vcom -2008 TB/RV32IMscMCU/tb_RV32I.vhd

vsim -L altera_mf -L lpm work.tb_RV32I

add wave -radix hexadecimal /tb_RV32I/*
run 50 us
wave zoom full

echo "@@ final PC    = [examine -radix hex /tb_RV32I/pc_o]"
echo "@@ final INSTR = [examine -radix hex /tb_RV32I/instruction_o]"

# batch mode: print result and quit; GUI: stay open with waves
if {[batch_mode]} { quit -f }
