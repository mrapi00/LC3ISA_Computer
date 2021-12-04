//==============================================================================
// Datapath for PUnC LC3 Processor
//==============================================================================

`include "Memory.v"
`include "RegisterFile.v"
`include "Defines.v"

module PUnCDatapath(
	// External Inputs
	input  wire        clk,            // Clock
	input  wire        rst,            // Reset

	// DEBUG Signals
	input  wire [15:0] mem_debug_addr,
	input  wire [2:0]  rf_debug_addr,
	output wire [15:0] mem_debug_data,
	output wire [15:0] rf_debug_data,
	output wire [15:0] pc_debug_data,

	// Add more ports here
	input wire 			pc_ld,
	input wire 			pc_clr,
	input wire 			pc_inc,
	input wire [1:0] 	pc_sel,

	input wire 			ir_ld,
	input wire 			ir_clr,

	input wire 			mem_rd,
	input wire 			mem_wr,
	input wire [1:0] 	mem_r_addr_sel,
	input wire [1:0] 	mem_w_addr_sel,

	input wire [1:0] 	rf_w_data_sel,
	input wire 			rf_w_addr_sel,
	input wire 			rf_w_wr,
	
	input wire 			rf_r0_addr_sel,
	input wire 			rf_r0_rd,
	input wire 			rf_r1_rd,

	input wire 			temp_ld,

	input wire 			nzp_ld,
	input wire 			nzp_clr,

	input wire [1:0] 	alu_sel,
	input wire 			alu_first_val_sel,

	output wire 		nzp_true,
	output wire [15:0] 	ir_to_controller

);

	// Local Registers
	reg  [15:0] pc;
	reg  [15:0] ir;
	assign ir_to_controller = ir;

	reg  	[15:0] 		pc_w_data;

	reg 	[15:0]		ir_sext_10_0;
	reg 	[15:0]		ir_sext_8_0;
	reg 	[15:0]		ir_sext_5_0;
	reg 	[15:0] 		ir_sext_4_0;

	reg 	[15:0] 		temp;

	reg 	[15:0] 		mem_r_addr;
	reg 	[15:0] 		mem_w_addr;
	wire 	[15:0] 		mem_r_data;

	reg 	[2:0] 		rf_w_addr;
	reg 	[15:0]		rf_w_data;
	reg 	[2:0]		rf_r0_addr;
	wire 	[15:0]		rf_r0_data;
	wire 	[15:0]		rf_r1_data;

	reg n;	
	reg z; 
	reg p;
	assign nzp_true = (ir[11] & n) | (ir[10] & z) | (ir[9] & p);
  
	reg [15:0] alu_first_val;
	reg [15:0] alu_out;


	// Declare other local wires and registers here

	// Assign PC debug net
	assign pc_debug_data = pc;


	//----------------------------------------------------------------------
	// Memory Module
	//----------------------------------------------------------------------

	// 1024-entry 16-bit memory (connect other ports)
	Memory mem(
		.clk      (clk),
		.rst      (rst),
		.r_addr_0 (mem_r_addr),
		.r_addr_1 (mem_debug_addr),
		.w_addr   (mem_w_addr),
		.w_data   (rf_r0_data),
		.w_en     (mem_wr),
		.r_data_0 (mem_r_data),
		.r_data_1 (mem_debug_data)
	);

	//----------------------------------------------------------------------
	// Register File Module
	//----------------------------------------------------------------------

	// 8-entry 16-bit register file (connect other ports)
	RegisterFile rfile(
		.clk      (clk),
		.rst      (rst),
		.r_addr_0 (rf_r0_addr),
		.r_addr_1 (ir[8:6]),
		.r_addr_2 (rf_debug_addr),
		.w_addr   (rf_w_addr),
		.w_data   (rf_w_data),
		.w_en     (rf_w_wr),
		.r_data_0 (rf_r0_data),
		.r_data_1 (rf_r1_data),
		.r_data_2 (rf_debug_data)
	);

	//----------------------------------------------------------------------
	// Add all other datapath logic here
	//----------------------------------------------------------------------

	always @(*) begin //Sign Extend Circuit
		ir_sext_10_0 = {{5{ir[10]}},ir[10:0]};
		ir_sext_8_0 = {{7{ir[8]}},ir[8:0]};
		ir_sext_5_0 = {{10{ir[5]}},ir[5:0]};
		ir_sext_4_0 = {{11{ir[4]}},ir[4:0]};
	end

	always @(*) begin	//PC Muxes
		pc_w_data = 0;

		case (pc_sel)
			`PC_Data_Sel_PC_8_0: begin
				pc_w_data = pc + ir_sext_8_0;
			end
			`PC_Data_Sel_PC_10_0: begin
				pc_w_data = pc + ir_sext_10_0;
			end
			`PC_Data_Sel_RF_R1_Data: begin
				pc_w_data = rf_r1_data;
			end
		endcase
	end
	
	always @(*) begin	//DMEM Muxes
		//R_addr
		case (dmem_r_addr_sel)
			`DMem_R_Addr_Sel_PC : begin
				dmem_r_addr = pc;
			end
			`DMem_R_Addr_Sel_PC_8_0: begin
				dmem_r_addr = pc + ir_sext_8_0;
			end
			`DMem_R_Addr_Sel_RF_R0_Data: begin
				dmem_r_addr = rf_r0_data;
			end
			`DMem_R_Addr_Sel_RF_R1_5_0: begin
				dmem_r_addr = rf_r1_data + ir_sext_5_0;
			end
		endcase
		
		//W_addr
		case (dmem_w_addr_sel)
			`DMem_W_Addr_Sel_PC_8_0: begin
				dmem_w_addr = pc + ir_sext_8_0;
			end
			`DMem_W_Addr_Sel_Temp_Data: begin
				dmem_w_addr = temp;
			end
			`DMem_W_Addr_Sel_RF_R1_5_0: begin
				dmem_w_addr = rf_r1_data + ir_sext_5_0;
			end
		endcase
	end	
	
	always @(*) begin	//RF Muxes
		//rf_w_addr
		case (rf_w_addr_sel)
			`RF_W_Addr_Sel_R7: begin
				rf_w_addr = 3'b111;
			end
			`RF_W_Addr_Sel_11_9: begin
				rf_w_addr = ir[11:9];
			end
		endcase

		//rf_w_data
		case (rf_w_data_sel)
			`RF_W_Data_Sel_ALU: begin
				rf_w_data = alu_out;
			end
			`RF_W_Data_Sel_PC_8_0: begin
			  	rf_w_data = pc + ir_sext_8_0;
			end
			`RF_W_Data_Sel_DMem_R: begin
				rf_w_data = dmem_r_data;
			end
			`RF_W_Data_Sel_PC: begin
				rf_w_data = pc;
			end
		endcase

		//rf_r0_addr
		case (rf_r0_addr_sel)
			`rf_r0_Addr_Sel_11_9: begin
			  rf_r0_addr = ir[11:9];
			end
			`rf_r0_Addr_Sel_2_0: begin
			  rf_r0_addr = ir[2:0];
			end
		endcase
	end

	always @(*) begin	//ALU Muxes
		//alu_in_a_sel
		case (alu_in_a_sel)
			`ALU_In_A_Sel_Rp_Data: begin
			  alu_in_a = rf_r0_data;
			end
			`ALU_In_A_4_0: begin
			  alu_in_a = ir_sext_4_0;
			end
		endcase

		//alu_sel
		case (alu_sel)
			`ALU_Fn_Sel_PassA: begin
			  alu_out = alu_in_a;
			end
			`ALU_Fn_Sel_ADD: begin
			  alu_out = rf_r1_data + alu_in_a;
			end
			`ALU_Fn_Sel_AND: begin
			  alu_out = rf_r1_data & alu_in_a;
			end
			`ALU_Fn_Sel_NOT_B: begin
			  alu_out = ~rf_r1_data;
			end
		endcase
	end

	always @(posedge clk) begin //Sequential Logic

		//Temp
		if(temp_ld) begin
		  temp = dmem_r_data;
		end

		//IR
		if(ir_clr) begin
		  ir = 16'b0;
		end
		else if(ir_ld) begin
		ir = dmem_r_data;
		end

		//NZP
		if(nzp_clr) begin
		  n = 1'b0;
		  z = 1'b0;
		  p = 1'b0;
		end
		else if (nzp_ld) begin
		  n = rf_w_data[15];
		  z = rf_w_data == 0;
		  p = ~n & ~z; // NEED TO CHECK (MRAPI)
		end

		//PC
		if (pc_clr) begin
		  pc = 16'b0;
		end
		else if (pc_inc) begin
		  pc = pc + 1;
		end 
		else if(pc_ld) begin
		  pc = pc_w_data;
		end
	end
endmodule