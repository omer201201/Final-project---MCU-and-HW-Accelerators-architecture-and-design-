onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /tb_rv32i/clk_i
add wave -noupdate -radix hexadecimal /tb_rv32i/rst_i
add wave -noupdate -color Yellow -itemcolor Yellow /tb_rv32i/CORE/IFE/rst_q
add wave -noupdate -color Cyan -itemcolor Cyan -radix unsigned -childformat {{/tb_rv32i/mclk_cnt_o(15) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(14) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(13) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(12) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(11) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(10) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(9) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(8) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(7) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(6) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(5) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(4) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(3) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(2) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(1) -radix hexadecimal} {/tb_rv32i/mclk_cnt_o(0) -radix hexadecimal}} -subitemconfig {/tb_rv32i/mclk_cnt_o(15) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(14) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(13) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(12) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(11) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(10) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(9) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(8) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(7) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(6) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(5) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(4) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(3) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(2) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(1) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal} /tb_rv32i/mclk_cnt_o(0) {-color Cyan -height 15 -itemcolor Cyan -radix hexadecimal}} /tb_rv32i/mclk_cnt_o
add wave -noupdate -radix hexadecimal /tb_rv32i/pc_o
add wave -noupdate -color Blue -itemcolor Blue -radix hexadecimal /tb_rv32i/instruction_o
add wave -noupdate -radix hexadecimal /tb_rv32i/RegWrite_ctrl_o
add wave -noupdate -radix hexadecimal /tb_rv32i/MemWrite_ctrl_o
add wave -noupdate -radix hexadecimal /tb_rv32i/Branch_ctrl_o
add wave -noupdate -radix hexadecimal /tb_rv32i/read_data1_o
add wave -noupdate -radix hexadecimal /tb_rv32i/read_data2_o
add wave -noupdate -radix hexadecimal /tb_rv32i/write_data_o
add wave -noupdate -radix hexadecimal /tb_rv32i/alu_res_o
add wave -noupdate -radix hexadecimal /tb_rv32i/brTaken_o
add wave -noupdate -radix hexadecimal /tb_rv32i/dtcm_addr_o
add wave -noupdate -radix hexadecimal /tb_rv32i/dtcm_data_wr_o
add wave -noupdate -radix hexadecimal /tb_rv32i/dtcm_data_rd_o
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/clk_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/rst_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/addr_gen_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/Branch_ctrl_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/brTaken_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/Jal_ctrl_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/Jalr_ctrl_i
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/alu_res_i
add wave -noupdate -expand -group IFETCH -color Magenta -itemcolor Magenta -radix hexadecimal /tb_rv32i/CORE/IFE/pc_o
add wave -noupdate -expand -group IFETCH -color Blue -itemcolor Blue -radix hexadecimal /tb_rv32i/CORE/IFE/pc_plus4_o
add wave -noupdate -expand -group IFETCH -color Cyan -itemcolor Cyan -radix hexadecimal /tb_rv32i/CORE/IFE/next_pc_w
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/instruction_o
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/pc_plus4_q
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/pc_plus4_r
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/itcm_addr_w
add wave -noupdate -expand -group IFETCH -radix hexadecimal /tb_rv32i/CORE/IFE/brTaken_w
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/clk_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/rst_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/pc_plus4_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/instruction_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/dtcm_data_rd_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/alu_res_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/RegDst_ctrl_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/RegWrite_ctrl_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/MemtoReg_ctrl_i
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/read_data1_o
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/read_data2_o
add wave -noupdate -expand -group IDECODE -color Blue -itemcolor Blue -radix hexadecimal /tb_rv32i/CORE/ID/SignExt_o
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/write_data_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/opc_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/rs1_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/rs2_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/rd_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/Iimm_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/Simm_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/SBimm_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/Uimm_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/UJimm_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/SignExt_Iimm_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/SignExt_Simm_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/SignExt_SBimm_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/SignExt_Uimm_w
add wave -noupdate -expand -group IDECODE -radix hexadecimal /tb_rv32i/CORE/ID/SignExt_UJimm_w
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane
add wave -noupdate -radix hexadecimal -childformat {{/tb_rv32i/CORE/ID/RF_q(0) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(1) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(2) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(3) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(4) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(5) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(6) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(7) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(8) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(9) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(10) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(11) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(12) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(13) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(14) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(15) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(16) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(17) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(18) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(19) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(20) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(21) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(22) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(23) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(24) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(25) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(26) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(27) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(28) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(29) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(30) -radix hexadecimal} {/tb_rv32i/CORE/ID/RF_q(31) -radix hexadecimal}} -expand -subitemconfig {/tb_rv32i/CORE/ID/RF_q(0) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(1) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(2) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(3) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(4) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(5) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(6) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(7) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(8) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(9) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(10) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(11) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(12) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(13) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(14) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(15) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(16) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(17) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(18) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(19) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(20) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(21) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(22) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(23) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(24) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(25) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(26) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(27) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(28) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(29) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(30) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/ID/RF_q(31) {-height 15 -radix hexadecimal}} /tb_rv32i/CORE/ID/RF_q
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/instruction_i
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/RegDst_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/ALUSrc_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/MemtoReg_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/RegWrite_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/MemRead_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/MemWrite_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/Branch_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/Jal_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/Jalr_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/UpperIm_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/ALUOp_ctrl_o
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/Rtype_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/Itype_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/Stype_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/SBtype_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/Utype_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/UJtype_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/lb_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/lh_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/lw_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/lbu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/lhu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/lwu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/ld_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/sb_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/sh_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/sw_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/st_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/beq_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/bne_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/blt_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/bge_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/bltu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/bgeu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/branch_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/jal_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/jalr_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/add_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/addi_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/and_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/andi_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/or_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/ori_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/sll_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/slli_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/sra_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/srai_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/srl_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/srli_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/sub_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/xor_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/xori_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/auipc_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/lui_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/slt_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/slti_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/sltu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/sltiu_w
add wave -noupdate -expand -group CONTROL -radix hexadecimal /tb_rv32i/CORE/CTL/opc_w
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/read_data1_i
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/read_data2_i
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/UpperIm_ctrl_i
add wave -noupdate -expand -group EXECUTE -radix hexadecimal -childformat {{/tb_rv32i/CORE/EXE/ALUOp_ctrl_i(4) -radix hexadecimal} {/tb_rv32i/CORE/EXE/ALUOp_ctrl_i(3) -radix hexadecimal} {/tb_rv32i/CORE/EXE/ALUOp_ctrl_i(2) -radix hexadecimal} {/tb_rv32i/CORE/EXE/ALUOp_ctrl_i(1) -radix hexadecimal} {/tb_rv32i/CORE/EXE/ALUOp_ctrl_i(0) -radix hexadecimal}} -subitemconfig {/tb_rv32i/CORE/EXE/ALUOp_ctrl_i(4) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/EXE/ALUOp_ctrl_i(3) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/EXE/ALUOp_ctrl_i(2) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/EXE/ALUOp_ctrl_i(1) {-height 15 -radix hexadecimal} /tb_rv32i/CORE/EXE/ALUOp_ctrl_i(0) {-height 15 -radix hexadecimal}} /tb_rv32i/CORE/EXE/ALUOp_ctrl_i
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/ALUSrc_ctrl_i
add wave -noupdate -expand -group EXECUTE -color {Violet Red} -itemcolor {Violet Red} -radix hexadecimal /tb_rv32i/CORE/EXE/pc_i
add wave -noupdate -expand -group EXECUTE -color Navy -itemcolor Navy -radix hexadecimal /tb_rv32i/CORE/EXE/sign_extend_i
add wave -noupdate -expand -group EXECUTE -color Cyan -itemcolor Cyan -radix hexadecimal /tb_rv32i/CORE/EXE/addr_gen_o
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/sub_res_w
add wave -noupdate -expand -group EXECUTE -color Magenta -itemcolor Magenta -radix hexadecimal /tb_rv32i/CORE/EXE/ain_w
add wave -noupdate -expand -group EXECUTE -color Blue -itemcolor Blue -radix hexadecimal /tb_rv32i/CORE/EXE/bin_w
add wave -noupdate -expand -group EXECUTE -color Cyan -itemcolor Cyan -radix hexadecimal /tb_rv32i/CORE/EXE/alu_res_o
add wave -noupdate -expand -group EXECUTE -color {Medium Spring Green} -itemcolor {Medium Spring Green} -radix hexadecimal /tb_rv32i/CORE/EXE/brTaken_o
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/ltu_res_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/eq_res_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/msbneq_res_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/brTaken_w
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/alu_res_r
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/brl_shl_s1_r
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/brl_shl_s2_r
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/brl_shl_s3_r
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/brl_shl_s4_r
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/brl_shr_s1_r
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/brl_shr_s2_r
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/brl_shr_s3_r
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/brl_shr_s4_r
add wave -noupdate -expand -group EXECUTE -radix hexadecimal /tb_rv32i/CORE/EXE/brl_shr_pad_r
TreeUpdate [SetDefaultTree]
quietly WaveActivateNextPane
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32i/CORE/MEM/clk_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32i/CORE/MEM/rst_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32i/CORE/MEM/dtcm_addr_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32i/CORE/MEM/dtcm_data_wr_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32i/CORE/MEM/MemRead_ctrl_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32i/CORE/MEM/MemWrite_ctrl_i
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32i/CORE/MEM/dtcm_data_rd_o
add wave -noupdate -expand -group DMEMORY -radix hexadecimal /tb_rv32i/CORE/MEM/wrclk_w
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {52700000 ps} 1} {{Cursor 2} {52799569 ps} 1}
quietly wave cursor active 1
configure wave -namecolwidth 314
configure wave -valuecolwidth 194
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {52345291 ps} {53965184 ps}
bookmark add wave bookmark2 {{36 ps} {116 ps}} 0
bookmark add wave bookmark3 {{0 ps} {1 ns}} 0
