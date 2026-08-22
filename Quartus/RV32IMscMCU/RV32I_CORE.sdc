## ==========================================================================
## Timing constraints - RV32IMscMCU (single-clock) on DE2-115 / Cyclone IV E
## ==========================================================================

## 50 MHz board oscillator (CLOCK_50) arrives on top-level port clk_i.
## 20.000 ns period = 50 MHz.
create_clock -name CLOCK_50 -period 20.000 [get_ports clk_i]

## Let the Timing Analyzer create the PLL output clock(s) automatically
## (mclk = PLL c0). This is what lets it report fmax for the CPU clock domain.
derive_pll_clocks

## Add the recommended clock uncertainty for this device.
derive_clock_uncertainty
