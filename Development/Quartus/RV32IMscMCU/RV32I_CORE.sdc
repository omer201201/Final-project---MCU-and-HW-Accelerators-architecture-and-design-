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

## ==========================================================================
## MCLK <-> DIVCLK : declare the two PLL domains asynchronous.
##
## derive_pll_clocks creates both PLL outputs: c0 = MCLK (CPU) and c1 = DIVCLK
## (divider accelerator). Without this declaration the Timing Analyzer pairs
## every MCLK launch edge with every DIVCLK latch edge and demands the crossing
## meet the worst pairing -- which reported -7.048 ns of setup slack on paths
## that are not meant to be timed at all.
##
## Every crossing between the two domains is already protected:
##   * operands (read_data1/2) and DIVENA cross MCLK -> DIVCLK through the
##     two-flop cdc_sync synchroniser of project definition Figure 10b;
##   * DIVBUSY crosses DIVCLK -> MCLK through the same synchroniser;
##   * Quotient/Residue cross DIVCLK -> MCLK unsynchronised, but are guaranteed
##     stable because div_stall_ctrl holds the CPU stalled until the
##     synchronised DIVBUSY has dropped -- the standard "synchronise the
##     control, let the settled data cross" handshake.
##
## Timing these paths as if they were synchronous would report violations that
## the synchronisers exist specifically to make irrelevant. Paths WITHIN each
## domain are still fully analysed.
## ==========================================================================
set_clock_groups -asynchronous \
    -group [get_clocks {*altpll*|*clk[0]}] \
    -group [get_clocks {*altpll*|*clk[1]}]
