# Unit test for the divider + synchronizer module (pure RTL, no Altera libs).
# Run from the project root:  do SIM/RV32IMscMCU/run_divider.do
onerror {resume}

if {[file exists work]} { vdel -all }
vlib work
vmap work work

vcom -2008 DUT/RV32IMscMCU/divider.vhd
vcom -2008 TB/RV32IMscMCU/tb_divider.vhd

vsim work.tb_divider

add wave -divider "slow domain"
add wave -radix unsigned /tb_divider/mclk
add wave -radix unsigned /tb_divider/divena
add wave -radix unsigned /tb_divider/dividend
add wave -radix unsigned /tb_divider/divisor
add wave -divider "fast domain / DUT"
add wave -radix unsigned /tb_divider/divclk
add wave            /tb_divider/DUT/state
add wave -radix unsigned /tb_divider/DUT/count
add wave -radix unsigned /tb_divider/DUT/rem_q
add wave -radix unsigned /tb_divider/DUT/dvnd_q
add wave -radix unsigned /tb_divider/DUT/quo_q
add wave -radix unsigned /tb_divider/DUT/dsor_q
add wave -divider "results"
add wave -radix unsigned /tb_divider/quotient
add wave -radix unsigned /tb_divider/residue
add wave -radix unsigned /tb_divider/divbusy

run -all
wave zoom full
if {[batch_mode]} { quit -f }
