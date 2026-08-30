# ------------------------------------------------------------------------------
# compile.do -- shared compile step for every RV32IMscMCU benchmark run.
#
# Sourced by each run_*.do; not meant to be run on its own.
# Run every .do from the SUBMISSION ROOT (the folder holding DUT/ TB/ SIM/):
#     vsim -c -do SIM/RV32IMscMCU/run_<benchmark>.do
#
# Requires cond_compilation_package.vhd to have G_MODELSIM = 1 (its shipped
# value). With G_MODELSIM = 0 the PLL is instantiated and has no simulation
# model bound, so the core will not run.
# ------------------------------------------------------------------------------

if {[file exists work]} { vdel -all -lib work }
vlib work
vmap work work

# altsyncram / lpm models for the ITCM and DTCM megafunctions.
# MODEL_TECH points at ModelSim's own bin directory, so the Altera libraries
# shipped with Quartus sit next to it. Falls back to the default Quartus 20.1
# install path if that lookup fails.
if {[info exists env(MODEL_TECH)] && [file isdirectory "$env(MODEL_TECH)/../altera/vhdl/altera_mf"]} {
    vmap altera_mf "$env(MODEL_TECH)/../altera/vhdl/altera_mf"
} elseif {[file isdirectory "C:/intelFPGA/20.1/modelsim_ase/altera/vhdl/altera_mf"]} {
    vmap altera_mf "C:/intelFPGA/20.1/modelsim_ase/altera/vhdl/altera_mf"
} else {
    puts "WARNING: altera_mf library not found -- map it manually, e.g."
    puts "         vmap altera_mf <quartus>/modelsim_ase/altera/vhdl/altera_mf"
}

set D DUT/RV32IMscMCU
set T TB/RV32IMscMCU

# packages first, then leaf modules, then the structural top, then the testbench
vcom -2008 -quiet $D/cond_compilation_package.vhd
vcom -2008 -quiet $D/const_package.vhd
vcom -2008 -quiet $D/aux_package.vhd

vcom -2008 -quiet $D/IFETCH.VHD
vcom -2008 -quiet $D/IDECODE.VHD
vcom -2008 -quiet $D/CONTROL.VHD
vcom -2008 -quiet $D/EXECUTE.VHD
vcom -2008 -quiet $D/DMEMORY.VHD

vcom -2008 -quiet $D/seg7.vhd
vcom -2008 -quiet $D/gpio.vhd

vcom -2008 -quiet $D/bt_prescaler.vhd
vcom -2008 -quiet $D/bt_counter.vhd
vcom -2008 -quiet $D/bt_output_unit.vhd
vcom -2008 -quiet $D/bt_capture.vhd
vcom -2008 -quiet $D/bt_regs.vhd
vcom -2008 -quiet $D/BasicTimer.vhd

vcom -2008 -quiet $D/intr_ctrl.vhd
vcom -2008 -quiet $D/bus_interface.vhd

vcom -2008 -quiet $D/cdc_sync.vhd
vcom -2008 -quiet $D/divider.vhd
vcom -2008 -quiet $D/div_stall_ctrl.vhd
vcom -2008 -quiet $D/intr_fsm.vhd

vcom -2008 -quiet $D/RV32I_CORE.vhd

vcom -2008 -quiet $T/tb_RV32IMscMCU.vhd
