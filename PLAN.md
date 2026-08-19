# RV32IM MCU — Project Workflow & Schedule

**Deadline:** Mon 31/08/2026 · **Team:** 2 (pairing now, split on the back third) · **Budget:** ~50 net hours (Wed 19 → Sun 30, 5 h/day; Fri 21 & 28 off)

**Status of this plan: LOCKED.** Mandatory scope only inside the timeframe. Bonuses are appended at the end as optional — attempt only if the mandatory system is finished and hardware-validated with time to spare.

---

## 1. Guiding principle — verify on hardware before advancing

We do **not** advance past a phase until it is proven on the real board. Every gate therefore leaves us with a **compiling, board-validated, submittable system** — that is our risk control. This matches the spec's dual verification (ModelSim golden compare **and** ISMCE/Signal-Tap hardware validation).

**The per-phase loop (non-negotiable):**
1. Edit HDL.
2. **ModelSim** — iterate fast until the phase's `DTCM.mem` == RARS `DTCM.h`.
3. **Quartus** — compile (one reused project), check no errors + fmax.
4. **Board** — program, run the app, **ISMCE** `DTCM.hex` == RARS `DTCM.hex`, **Signal-Tap** capture.
5. Screenshot for the report. **Only now advance.**

> **Debug in simulation, sign off on hardware. Never debug on the board** — hardware iteration is ~100× slower than sim. Sim finds the bug; hardware proves it's gone.

---

## 2. Ground truth

**Reuse from Lab5 (do NOT rebuild)** — `C:\Users\omer2\VHDL\Lab5-RISCV\Lab5-VHDL`:
- Structural RV32IM single-cycle core (`RV32I_CORE.vhd`): IFETCH(+ITCM), IDECODE(regfile), CONTROL, EXECUTE(ALU), DMEMORY(DTCM).
- Already **Harvard** (ITCM/DTCM separate). **PLL** already instantiated. Correct **`mul`** (`ALU_MUL`, low-32 — no `mulh*`, per forum).
- ModelSim `.do` + TB + golden `DTCM` flow. Proven Quartus PPA / Signal-Tap / ISMCE flow (screenshots exist).
- A pipelined core exists (`Lab5-VHDL_PIPELINED`) → base for the pipeline bonus.

**Genuinely new (the project):**
1. **BUSY stall** — clock-enable on PC (IFETCH) + regfile write (IDECODE); ALU becomes multicycle. *Build this generically — P4 reuses the same PC-hold spine.*
2. **Divider accelerator** — unsigned multicycle `div`/`rem`, fast **DIVCLK** domain + **CDC synchronizer** (Fig 10). Divide-by-zero → all ones (RISC-V convention).
3. **MMIO bus** — address decode: `alu_res ≥ 0x2000` (byte) → peripherals; read-data mux back.
4. **GPIO** — PORT_LEDR/HEX0-5/SW.
5. **Basic Timer** — compare / output-compare(PWM) / input-capture.
6. **KEY[3-1]** edge interrupts (KEY1→bit0, KEY2→bit1, KEY3→bit2; KEY0 = RESET).
7. **Interrupt controller** — IE/IFG/TYPE, 8-level priority, GIE gating, per-flag auto-clear rules — **plus the CPU service protocol** (INTR/INTA 2-cycle, TYPE→vector, save tp, `reti`) grafted into CONTROL + IFETCH.

**Binding facts from the student forum:** use Lab5 Part 1 core; `mul` only (signed, low-32); `div`/`rem` are CPU instructions with a BUSY stall (interrupt taken only after they retire); three separate PLL instances (MCLK/SMCLK/DIVCLK), integer-multiple so **no CDC needed between MCLK & SMCLK** and MCLK=SMCLK allowed in the single-cycle case; on-board hardware debounce (do NOT implement); each HEX independent 4-bit; TYPE already holds ×4 values.

---

## 3. Mandatory phases (inside the timeframe)

| # | Phase | Verify (sim → hardware) | Exit gate | Est. h |
|---|---|---|---|---|
| **P0** | Baseline & scaffolding: copy DUT/SIM/TB into project, `G_MODELSIM=1`, reproduce baseline | RV32IM/test1 | baseline passes in sim | 3 |
| **P1** | Core adapt: confirm memory-map params, add stall/enable hooks to PC + regfile | test1 no regression | hooks in | 3 |
| **HW rig** | One-time: Quartus project, pin-plan **all** board I/O, Signal-Tap base config, SDC (reuse Lab5 `qsf`/`sdc`/`stp`) | — | board rig ready | 3 |
| **P2a** | Divider as `div`/`rem` unit + generic BUSY freeze/hold (single clock) | RV32IM/test1 | sim DTCM == golden | 7 |
| **P2b** | Move divider to DIVCLK + Fig-10 CDC synchronizer | RV32IM/test1 | sim cross-domain pass; IPC sane | 5 |
| **P2 HW** | Validate test1 on board | ISMCE + Signal-Tap (div/mul) | board == golden, screenshot | 1.5 |
| **P3** | MMIO bus decode + GPIO (LEDR/HEX0-5/SW) | GPIO test0-2 | sim passes | 7 |
| **P3 HW** | Validate GPIO on board + **PPA #1** (MCU+GPIO) | eyeball + ISMCE + Signal-Tap | **FALLBACK CHECKPOINT** + PPA#1 saved | 2.5 |
| **P4a** | Basic Timer (compare/PWM/capture) + KEY[3-1] + IE/IFG | sim → board spot-check | flags/PWM behave | 8 |
| **P4b** | Interrupt controller + CPU service protocol (INTR/INTA/TYPE/GIE/`reti`) | Intr test1 | interrupt fires correctly | 9 |
| **P4 HW** | Validate Intr test1 on board | ISMCE + Signal-Tap | board == golden | 1.5 |
| **G2** | Full verify Intr test2/3 + **test4** on board + **PPA #2** (MCU+GPIO+Interrupt) | ISMCE + Signal-Tap | mandatory system done | 4 |
| **DOC** | Report — captured continuously, assembled at end | — | final.pdf | 6 |
| **PKG** | Zip packaging + clean-compile check (ModelSim **and** Quartus) | — | submitted | 2 |
| | **Mandatory total** | | | **~64–66** |

**Honest bottom line:** ~64–66 person-hours against ~50 solo-hours. The gap closes through pair-parallelism on the back third (one debugs P4, one captures PPA / writes report) and by treating Sun 30 as core work, not spare. **P4 (interrupts) is the crunch** — it's ~⅓ of the project and modifies the CPU itself. If it overruns, submit the **P3 fallback** (single-cycle MCU + GPIO + divider, board-validated).

---

## 4. Dated schedule

| Day | Date | Task (h) | Gate |
|---|---|---|---|
| Wed | 19 | P0 baseline (3) | RV32IM/test1 baseline passes |
| Thu | 20 | P1 stall hooks (2) · HW rig setup (3) | hooks in, rig ready |
| Fri | 21 | **off** | |
| Sat | 22 | P2a divider + BUSY (5) | stall freezes PC cleanly |
| Sun | 23 | P2a verify + P2b CDC start (5) | sim test1 == golden |
| Mon | 24 | P2b finish + **P2 HW validate** (5) | test1 on board == golden |
| Tue | 25 | P3 bus + GPIO (5) | GPIO passes in sim |
| Wed | 26 | **P3 HW validate + PPA#1** (5) | **fallback: GPIO MCU on board** |
| Thu | 27 | P4a timer + KEY + IE/IFG (5) | PWM/flags behave |
| Fri | 28 | **off** | |
| Sat | 29 | P4b controller + CPU protocol + HW test1 (5) | interrupt fires on board |
| Sun | 30 | **G2**: Intr test2/3 + test4 + PPA#2 + report — *split* (5) | mandatory system done |
| Mon | 31 | report polish + zip + upload (2) | submitted |

---

## 5. Graded artifacts (capture as you go)
- **Three PPA tables** (Area / Performance-fmax+critical path / Power) with mandatory Quartus screenshots: **PPA#1** at P3 (MCU+GPIO), **PPA#2** at G2 (MCU+GPIO+Interrupt), **PPA#3** at B2 (Pipelined — bonus only).
- Top-level block diagram, RTL Viewer, per-HDL-file description, numbered figures/tables with captions, **waveforms for test1–test4**, conclusions.

## 6. Submission
`208838417_209128677.zip` (id1 `208838417` < id2 `209128677`, uploaded by id1) → exactly six folders: **DUT, TB, SIM, DOC, Quartus**, each split `RV32IMscMCU` / `RV32IMpipelinedMCU` (pipelined only if bonus done). **Must compile cleanly in both ModelSim and Quartus** — hard gate. `DOC` contains `Readme.txt` + `Final_report.pdf`.

---

## 7. Bonus phases — OUTSIDE the timeframe (if we get there, we get there)

Not budgeted. Attempt only after the mandatory system is finished and hardware-validated. Priority order: **UART first (higher value, isolated), pipeline second.**

### B1 — UART / USART (bonus +20%) · ~15 h
- Adapt the **given** USART VHDL to UART mode: 1 start / 8 data / 1 stop, no parity, LSB-first.
- Independent TX/RX shift + buffer registers (UTCL/RXBUF/TXBUF), programmable baud, status/error flags, independent RX/TX interrupts wired into the interrupt controller.
- Verify: UART menu app (count on LEDs, count-down, clear, "I love my Negev" on KEY1, show menu) over **RS-232/FTDI** to a PC terminal (Tera Term / PuTTY).
- Adds UART to the `RV32IMscMCU` design.

### B2 — Pipelined core (bonus +10%) · ~12 h
- Start from `Lab5-VHDL_PIPELINED`.
- Convert the BUSY-stall into a **hazard/stall control unit**; add forwarding; **preserve interrupt precision**.
- Re-verify **all** benchmarks (sim + hardware). Capture **PPA #3** (third table row).
- Adds `RV32IMpipelinedMCU` to DUT / TB / SIM / Quartus.

---

## 8. Confirmations
- [x] Submission IDs confirmed → zip name `208838417_209128677.zip` (id1 `208838417` < id2 `209128677`).
- [x] FPGA board available for the whole project.
