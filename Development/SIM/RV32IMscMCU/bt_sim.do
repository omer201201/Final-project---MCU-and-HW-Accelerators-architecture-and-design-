# ------------------------------------------------------------------------------
# bt_sim.do -- ModelSim script for the Basic Timer peripheral
#
#   cd <project root>
#   vsim -c -do SIM/RV32IMscMCU/bt_sim.do          (batch, self-checking)
#   vsim     -do SIM/RV32IMscMCU/bt_sim.do         (GUI, with waves)
# ------------------------------------------------------------------------------

if {[file exists work]} { vdel -all -lib work }
vlib work
vmap work work

vcom -2008 -work work DUT/RV32IMscMCU/bt_prescaler.vhd
vcom -2008 -work work DUT/RV32IMscMCU/bt_counter.vhd
vcom -2008 -work work DUT/RV32IMscMCU/bt_output_unit.vhd
vcom -2008 -work work DUT/RV32IMscMCU/bt_capture.vhd
vcom -2008 -work work DUT/RV32IMscMCU/bt_regs.vhd
vcom -2008 -work work DUT/RV32IMscMCU/BasicTimer.vhd
vcom -2008 -work work TB/RV32IMscMCU/tb_BasicTimer.vhd

vsim -voptargs=+acc work.tb_BasicTimer

if {[batch_mode]} {
    onbreak {quit -f}
    onerror {quit -f}
} else {
    add wave -divider  "bus"
    add wave -radix hex  /tb_BasicTimer/clk_s
    add wave -radix hex  /tb_BasicTimer/rst_s
    add wave -radix hex  /tb_BasicTimer/cs_s
    add wave -radix hex  /tb_BasicTimer/we_s
    add wave -radix hex  /tb_BasicTimer/addr_s
    add wave -radix hex  /tb_BasicTimer/wdata_s
    add wave -radix hex  /tb_BasicTimer/rdata_s

    add wave -divider  "control"
    add wave -radix hex  /tb_BasicTimer/DUT/btctl1_s
    add wave -radix hex  /tb_BasicTimer/DUT/btctl2_s

    add wave -divider  "datapath"
    add wave -radix uns  /tb_BasicTimer/DUT/btcl0_s
    add wave -radix uns  /tb_BasicTimer/DUT/btcl1_s
    add wave -radix uns  /tb_BasicTimer/DUT/btcnt_s
    add wave -radix hex  /tb_BasicTimer/DUT/tick_s
    add wave -radix hex  /tb_BasicTimer/DUT/euq0_s
    add wave -radix hex  /tb_BasicTimer/DUT/euq1_s

    add wave -divider  "outputs"
    add wave -radix hex  /tb_BasicTimer/pwm_s
    add wave -radix hex  /tb_BasicTimer/btifg_s
    add wave -radix uns  /tb_BasicTimer/DUT/btcapr_s

    configure wave -timelineunits ns
}

run -all

if {[batch_mode]} { quit -f } else { wave zoom full }
