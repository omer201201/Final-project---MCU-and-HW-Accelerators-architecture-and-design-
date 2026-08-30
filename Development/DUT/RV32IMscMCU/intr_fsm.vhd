--============================================================================
-- intr_fsm.vhd  -  2-cycle Interrupt Service FSM  (P4b, in the CPU control unit)
--
-- Implements "Protocol of Interrupt Service Process in a single-cycle CPU"
-- (project definition p.15). When INTR is asserted AND GIE (gp[0]) is set AND
-- the CPU is at an instruction boundary (not stalled), it runs a 2-cycle
-- service sequence, then returns to IDLE:
--
--   SVC1  (acknowledge + capture) -- "cycle 1" of the spec
--     - assert INTA           (handshake; controller drives TYPE on the DATA bus)
--     - capture TYPE           (the controller is a bus slave and cannot drive the
--                               ADDRESS bus, so TYPE arrives via the data bus and is
--                               latched into a dedicated register here)
--     - latch the return PC    (the instruction that was about to run)
--     - clear GIE (gp[0]<=0)   (block nested interrupts)
--   SVC2  (vector load + jump)   -- "cycle 2" of the spec
--     - the CPU (bus master) now drives the ADDRESS bus with the CAPTURED TYPE
--       and reads Mem[TYPE] = the ISR address on the data bus
--     - force PC <= Mem[TYPE]   (jump into the ISR)
--     - write tp (x4) <= return address
--
-- reti (the return) is NOT here: it is a normal `jalr x0,0(tp)` decoded in
-- CONTROL, which additionally sets GIE back to 1.
--
-- The FSM only PRODUCES control signals; the datapath (RV32I_CORE) muxes them:
--   svc_active  -> freeze normal PC/writes; select the interrupt datapath
--   vec_load    -> DTCM address = TYPE
--   set_pc      -> PC = vector data (Mem[TYPE])
--   write_tp    -> regfile write x4 = return addr
--   clr_gie     -> gp[0] <= 0
--============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity intr_fsm is
    port (
        clk_i          : in  std_logic;
        rst_i          : in  std_logic;
        -- status in
        intr_i         : in  std_logic;   -- INTR from the interrupt controller
        gie_i          : in  std_logic;   -- global interrupt enable = gp[0]
        can_take_i     : in  std_logic;   -- '1' at an instruction boundary (e.g. not pc_hold)
        -- control out (datapath overrides)
        inta_o         : out std_logic;   -- SVC1: INTA to the controller (active-high internally)
        svc_active_o   : out std_logic;   -- '1' during the whole service
        capture_o      : out std_logic;   -- SVC1: latch TYPE (off the data bus) + the return PC
        clr_gie_o      : out std_logic;   -- SVC1: gp[0] <= 0
        vec_load_o     : out std_logic;   -- SVC2: CPU drives memory address = captured TYPE
        set_pc_o       : out std_logic;   -- SVC2: PC <= vector (Mem[TYPE])
        write_tp_o     : out std_logic    -- SVC2: regfile x4 <= return address
    );
end entity intr_fsm;

architecture rtl of intr_fsm is
    type state_t is (IDLE, SVC1, SVC2);
    signal state : state_t := IDLE;
begin

    fsm : process (clk_i, rst_i)
    begin
        if rst_i = '1' then
            state <= IDLE;
        elsif rising_edge(clk_i) then
            case state is
                when IDLE =>
                    if intr_i = '1' and gie_i = '1' and can_take_i = '1' then
                        state <= SVC1;
                    end if;
                when SVC1 =>
                    state <= SVC2;
                when SVC2 =>
                    state <= IDLE;
            end case;
        end if;
    end process;

    svc_active_o   <= '1' when state /= IDLE else '0';
    -- SVC1: acknowledge + capture (TYPE arrives on the data bus)
    inta_o         <= '1' when state = SVC1 else '0';
    capture_o      <= '1' when state = SVC1 else '0';
    clr_gie_o      <= '1' when state = SVC1 else '0';
    -- SVC2: CPU drives the address bus with the captured TYPE, loads Mem[TYPE], jumps
    vec_load_o     <= '1' when state = SVC2 else '0';
    set_pc_o       <= '1' when state = SVC2 else '0';
    write_tp_o     <= '1' when state = SVC2 else '0';

end architecture rtl;
