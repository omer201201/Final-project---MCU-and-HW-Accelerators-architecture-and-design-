# ------------------------------------------------------------------------------
# waves.do -- report-quality wave layout: grouped under headers and colour-coded.
#
#   do SIM/RV32IMscMCU/waves.do
#
# Colour key
#   Cyan        CPU / program flow
#   Orange      interrupt handshake (INTR / INTA / service)
#   Magenta     interrupt controller registers (IE / IFG / TYPE)
#   Spring      Basic Timer datapath and PWM
#   Violet      divider accelerator + the DIVCLK crossing
#   Wheat       board I/O
#
# Signals are only recorded from the moment they are added, so add these BEFORE
# the run you want to capture (see the per-test recipe in the project notes).
# ------------------------------------------------------------------------------
set TB /tb_RV32IMscMCU

delete wave *
configure wave -namecolwidth 260
configure wave -valuecolwidth 110
configure wave -timelineunits us

# ============================== CPU ==========================================
add wave -divider "===== CPU ====="
add wave -color Cyan   -itemcolor Cyan   -radix unsigned    $TB/CORE/mclk_w
add wave -color Cyan   -itemcolor Cyan   -radix unsigned    $TB/pc_o
add wave -color Cyan   -itemcolor Cyan   -radix hexadecimal $TB/instruction_o
add wave -color Cyan   -itemcolor Cyan   -radix unsigned    $TB/mclk_cnt_o
add wave -color Red    -itemcolor Red                       $TB/CORE/stall_w

# ================= INTERRUPT SERVICE PROTOCOL (spec p.15) ====================
add wave -divider "===== INTERRUPT PROTOCOL ====="
add wave -color Orange -itemcolor Orange                    $TB/CORE/intr_w
add wave -color Orange -itemcolor Orange                    $TB/CORE/inta_w
add wave -color Gold   -itemcolor Gold                      $TB/CORE/svc_active_w
add wave -color Gold   -itemcolor Gold   -radix hexadecimal $TB/CORE/type_captured_q
add wave -color Gold   -itemcolor Gold   -radix unsigned    $TB/CORE/return_pc_q
add wave -color Salmon -itemcolor Salmon                    $TB/CORE/reti_w
# GIE is gp[0]. Add the whole gp vector -- an indexed path such as gp_w(0) is
# silently dropped by "add wave". Expand it in the wave window (click the +) and
# watch bit 0: that IS the global interrupt enable. If INTR is high but nothing
# is ever serviced, this is the first signal to check.
add wave -color Red    -itemcolor Red    -radix binary      $TB/CORE/gp_w

# ==================== INTERRUPT CONTROLLER REGISTERS ========================
add wave -divider "===== IE / IFG / TYPE ====="
add wave -color Magenta -itemcolor Magenta -radix binary      $TB/CORE/BUSIF/U_INTR/ie_reg
add wave -color Magenta -itemcolor Magenta -radix binary      $TB/CORE/BUSIF/U_INTR/ifg_reg
add wave -color Magenta -itemcolor Magenta -radix hexadecimal $TB/CORE/BUSIF/U_INTR/type_reg
add wave -color Plum    -itemcolor Plum    -radix binary      $TB/CORE/BUSIF/U_INTR/pend
add wave -color Plum    -itemcolor Plum    -radix binary      $TB/CORE/BUSIF/U_INTR/src_i

# ============================ BASIC TIMER ===================================
add wave -divider "===== BASIC TIMER ====="
add wave -color {Spring Green} -itemcolor {Spring Green} -radix hexadecimal $TB/CORE/BUSIF/U_TIMER/btctl1_s
add wave -color {Spring Green} -itemcolor {Spring Green} -radix hexadecimal $TB/CORE/BUSIF/U_TIMER/btctl2_s
add wave -color {Spring Green} -itemcolor {Spring Green} -radix unsigned    $TB/CORE/BUSIF/U_TIMER/btcnt_s
add wave -color Green          -itemcolor Green          -radix unsigned    $TB/CORE/BUSIF/U_TIMER/btcl0_s
add wave -color Green          -itemcolor Green          -radix unsigned    $TB/CORE/BUSIF/U_TIMER/btcl1_s
add wave -color Green          -itemcolor Green          -radix unsigned    $TB/CORE/BUSIF/U_TIMER/btcapr_s
add wave -color Khaki          -itemcolor Khaki                             $TB/CORE/BUSIF/U_TIMER/euq0_s
add wave -color Khaki          -itemcolor Khaki                             $TB/CORE/BUSIF/U_TIMER/euq1_s
add wave -color Yellow         -itemcolor Yellow                            $TB/pwm
add wave -color Yellow         -itemcolor Yellow                            $TB/btifg

# ============ DIVIDER ACCELERATOR + DIVCLK CROSSING (Fig 9 / 10b) ===========
add wave -divider "===== ACCELERATOR (DIVCLK) ====="
add wave -color Violet    -itemcolor Violet                    $TB/CORE/divclk_w
add wave -color Violet    -itemcolor Violet                    $TB/CORE/divena_w
add wave -color Turquoise -itemcolor Turquoise                 $TB/CORE/divbusy_raw_w
add wave -color Turquoise -itemcolor Turquoise                 $TB/CORE/divbusy_w
add wave -color Violet    -itemcolor Violet    -radix unsigned $TB/CORE/div_ain_w
add wave -color Violet    -itemcolor Violet    -radix unsigned $TB/CORE/div_bin_w
add wave -color White     -itemcolor White     -radix unsigned $TB/CORE/quotient_w
add wave -color White     -itemcolor White     -radix unsigned $TB/CORE/residue_w

# ============================= BOARD I/O ====================================
add wave -divider "===== BOARD I/O ====="
add wave -color Wheat -itemcolor Wheat -radix binary      $TB/SW
add wave -color Wheat -itemcolor Wheat -radix binary      $TB/PB
add wave -color Coral -itemcolor Coral -radix hexadecimal $TB/LEDR
add wave -color Tan   -itemcolor Tan   -radix hexadecimal $TB/HEX0
add wave -color Tan   -itemcolor Tan   -radix hexadecimal $TB/HEX1
add wave -color Tan   -itemcolor Tan   -radix hexadecimal $TB/HEX2
add wave -color Tan   -itemcolor Tan   -radix hexadecimal $TB/HEX3
add wave -color Tan   -itemcolor Tan   -radix hexadecimal $TB/HEX4
add wave -color Tan   -itemcolor Tan   -radix hexadecimal $TB/HEX5
