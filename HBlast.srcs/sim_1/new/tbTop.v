//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.09.2018 19:26:53
// Design Name: 
// Module Name: tbTop
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
//*****************************************************************************
// (c) Copyright 2009 - 2010 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//*****************************************************************************
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor             : Xilinx
// \   \   \/     Version            : 4.0
//  \   \         Application        : MIG
//  /   /         Filename           : sim_tb_top.v
// /___/   /\     Date Last Modified : $Date: 2011/06/07 13:45:16 $
// \   \  /  \    Date Created       : Tue Sept 21 2010
//  \___\/\___\
//
// Device           : 7 Series
// Design Name      : DDR3 SDRAM
// Purpose          :
//                   Top-level testbench for testing DDR3.
//                   Instantiates:
//                     1. IP_TOP (top-level representing FPGA, contains core,
//                        clocking, built-in testbench/memory checker and other
//                        support structures)
//                     2. DDR3 Memory
//                     3. Miscellaneous clock generation and reset logic
//                     4. For ECC ON case inserts error on LSB bit
//                        of data from DRAM to FPGA.
// Reference        :
// Revision History :
//*****************************************************************************

`timescale 1ps/100fs

`define DDRTestData 0

module tbTop;


   //***************************************************************************
   // Traffic Gen related parameters
   //***************************************************************************
   parameter SIMULATION            = "TRUE";
   parameter PORT_MODE             = "BI_MODE";
   parameter DATA_MODE             = 4'b0010;
   parameter TST_MEM_INSTR_MODE    = "R_W_INSTR_MODE";
   parameter EYE_TEST              = "FALSE";
                                     // set EYE_TEST = "TRUE" to probe memory
                                     // signals. Traffic Generator will only
                                     // write to one single location and no
                                     // read transactions will be generated.
   parameter DATA_PATTERN          = "DGEN_ALL";
                                      // For small devices, choose one only.
                                      // For large device, choose "DGEN_ALL"
                                      // "DGEN_HAMMER", "DGEN_WALKING1",
                                      // "DGEN_WALKING0","DGEN_ADDR","
                                      // "DGEN_NEIGHBOR","DGEN_PRBS","DGEN_ALL"
   parameter CMD_PATTERN           = "CGEN_ALL";
                                      // "CGEN_PRBS","CGEN_FIXED","CGEN_BRAM",
                                      // "CGEN_SEQUENTIAL", "CGEN_ALL"
   parameter BEGIN_ADDRESS         = 32'h00000000;
   parameter END_ADDRESS           = 32'h00000fff;
   parameter PRBS_EADDR_MASK_POS   = 32'hff000000;

   //***************************************************************************
   // The following parameters refer to width of various ports
   //***************************************************************************
   parameter COL_WIDTH             = 10;
                                     // # of memory Column Address bits.
   parameter CS_WIDTH              = 1;
                                     // # of unique CS outputs to memory.
   parameter DM_WIDTH              = 1;
                                     // # of DM (data mask)
   parameter DQ_WIDTH              = 8;
                                     // # of DQ (data)
   parameter DQS_WIDTH             = 1;
   parameter DQS_CNT_WIDTH         = 1;
                                     // = ceil(log2(DQS_WIDTH))
   parameter DRAM_WIDTH            = 8;
                                     // # of DQ per DQS
   parameter ECC                   = "OFF";
   parameter RANKS                 = 1;
                                     // # of Ranks.
   parameter ODT_WIDTH             = 1;
                                     // # of ODT outputs to memory.
   parameter ROW_WIDTH             = 14;
                                     // # of memory Row Address bits.
   parameter ADDR_WIDTH            = 28;
                                     // # = RANK_WIDTH + BANK_WIDTH
                                     //     + ROW_WIDTH + COL_WIDTH;
                                     // Chip Select is always tied to low for
                                     // single rank devices
   //***************************************************************************
   // The following parameters are mode register settings
   //***************************************************************************
   parameter BURST_MODE            = "8";
                                     // DDR3 SDRAM:
                                     // Burst Length (Mode Register 0).
                                     // # = "8", "4", "OTF".
                                     // DDR2 SDRAM:
                                     // Burst Length (Mode Register).
                                     // # = "8", "4".
   parameter CA_MIRROR             = "OFF";
                                     // C/A mirror opt for DDR3 dual rank
   
   //***************************************************************************
   // The following parameters are multiplier and divisor factors for PLLE2.
   // Based on the selected design frequency these parameters vary.
   //***************************************************************************
   parameter CLKIN_PERIOD          = 2188;
                                     // Input Clock Period


   //***************************************************************************
   // Simulation parameters
   //***************************************************************************
   parameter SIM_BYPASS_INIT_CAL   = "FAST";
                                     // # = "SIM_INIT_CAL_FULL" -  Complete
                                     //              memory init &
                                     //              calibration sequence
                                     // # = "SKIP" - Not supported
                                     // # = "FAST" - Complete memory init & use
                                     //              abbreviated calib sequence

   //***************************************************************************
   // IODELAY and PHY related parameters
   //***************************************************************************
   parameter TCQ                   = 100;
   //***************************************************************************
   // IODELAY and PHY related parameters
   //***************************************************************************
   parameter RST_ACT_LOW           = 1;
                                     // =1 for active low reset,
                                     // =0 for active high.

   //***************************************************************************
   // Referece clock frequency parameters
   //***************************************************************************
   parameter REFCLK_FREQ           = 200.0;
                                     // IODELAYCTRL reference clock frequency
   //***************************************************************************
   // System clock frequency parameters
   //***************************************************************************
   parameter tCK                   = 1250;
                                     // memory tCK paramter.
                     // # = Clock Period in pS.
   parameter nCK_PER_CLK           = 4;
                                     // # of memory CKs per fabric CLK

   

   //***************************************************************************
   // Debug and Internal parameters
   //***************************************************************************
   parameter DEBUG_PORT            = "OFF";
                                     // # = "ON" Enable debug signals/controls.
                                     //   = "OFF" Disable debug signals/controls.
   //***************************************************************************
   // Debug and Internal parameters
   //***************************************************************************
   parameter DRAM_TYPE             = "DDR3";

    

  //**************************************************************************//
  // Local parameters Declarations
  //**************************************************************************//

  localparam real TPROP_DQS          = 0.00;
                                       // Delay for DQS signal during Write Operation
  localparam real TPROP_DQS_RD       = 0.00;
                       // Delay for DQS signal during Read Operation
  localparam real TPROP_PCB_CTRL     = 0.00;
                       // Delay for Address and Ctrl signals
  localparam real TPROP_PCB_DATA     = 0.00;
                       // Delay for data signal during Write operation
  localparam real TPROP_PCB_DATA_RD  = 0.00;
                       // Delay for data signal during Read operation

  localparam MEMORY_WIDTH            = 8;
  localparam NUM_COMP                = DQ_WIDTH/MEMORY_WIDTH;
  localparam ECC_TEST 		   	= "OFF" ;
  localparam ERR_INSERT = (ECC_TEST == "ON") ? "OFF" : ECC ;
  

  localparam real REFCLK_PERIOD = (1000000.0/(2*REFCLK_FREQ));
  localparam RESET_PERIOD = 200000; //in pSec  
  localparam real SYSCLK_PERIOD = tCK;
    
    

  //**************************************************************************//
  // Wire Declarations
  //**************************************************************************//
  reg                                sys_rst_n;
  wire                               sys_rst;


  reg                     sys_clk_i;
  wire                               sys_clk_p;
  wire                               sys_clk_n;
    

  reg clk_ref_i;

  
  wire                               ddr3_reset_n;
  wire [DQ_WIDTH-1:0]                ddr3_dq_fpga;
  wire [DQS_WIDTH-1:0]               ddr3_dqs_p_fpga;
  wire [DQS_WIDTH-1:0]               ddr3_dqs_n_fpga;
  wire [ROW_WIDTH-1:0]               ddr3_addr_fpga;
  wire [3-1:0]              ddr3_ba_fpga;
  wire                               ddr3_ras_n_fpga;
  wire                               ddr3_cas_n_fpga;
  wire                               ddr3_we_n_fpga;
  wire [1-1:0]               ddr3_cke_fpga;
  wire [1-1:0]                ddr3_ck_p_fpga;
  wire [1-1:0]                ddr3_ck_n_fpga;
    
  
  wire                               init_calib_complete;
  wire                               tg_compare_error;
  wire [(CS_WIDTH*1)-1:0] ddr3_cs_n_fpga;
    
  wire [DM_WIDTH-1:0]                ddr3_dm_fpga;
    
  wire [ODT_WIDTH-1:0]               ddr3_odt_fpga;
    
  
  reg [(CS_WIDTH*1)-1:0] ddr3_cs_n_sdram_tmp;
    
  reg [DM_WIDTH-1:0]                 ddr3_dm_sdram_tmp;
    
  reg [ODT_WIDTH-1:0]                ddr3_odt_sdram_tmp;
    

  
  wire [DQ_WIDTH-1:0]                ddr3_dq_sdram;
  reg [ROW_WIDTH-1:0]                ddr3_addr_sdram [0:1];
  reg [3-1:0]               ddr3_ba_sdram [0:1];
  reg                                ddr3_ras_n_sdram;
  reg                                ddr3_cas_n_sdram;
  reg                                ddr3_we_n_sdram;
  wire [(CS_WIDTH*1)-1:0] ddr3_cs_n_sdram;
  wire [ODT_WIDTH-1:0]               ddr3_odt_sdram;
  reg [1-1:0]                ddr3_cke_sdram;
  wire [DM_WIDTH-1:0]                ddr3_dm_sdram;
  wire [DQS_WIDTH-1:0]               ddr3_dqs_p_sdram;
  wire [DQS_WIDTH-1:0]               ddr3_dqs_n_sdram;
  reg [1-1:0]                 ddr3_ck_p_sdram;
  reg [1-1:0]                 ddr3_ck_n_sdram;
  
    

//**************************************************************************//

  //**************************************************************************//
  // Reset Generation
  //**************************************************************************//
  initial begin
    sys_rst_n = 1'b0;
    #RESET_PERIOD
      sys_rst_n = 1'b1;
   end

   assign sys_rst = RST_ACT_LOW ? sys_rst_n : ~sys_rst_n;

  //**************************************************************************//
  // Clock Generation
  //**************************************************************************//

  initial
    sys_clk_i = 1'b0;
  always
    sys_clk_i = #(CLKIN_PERIOD/2.0) ~sys_clk_i;

  assign sys_clk_p = sys_clk_i;
  assign sys_clk_n = ~sys_clk_i;

  initial
    clk_ref_i = 1'b0;
  always
    clk_ref_i = #REFCLK_PERIOD ~clk_ref_i;




  always @( * ) begin
    ddr3_ck_p_sdram      <=  #(TPROP_PCB_CTRL) ddr3_ck_p_fpga;
    ddr3_ck_n_sdram      <=  #(TPROP_PCB_CTRL) ddr3_ck_n_fpga;
    ddr3_addr_sdram[0]   <=  #(TPROP_PCB_CTRL) ddr3_addr_fpga;
    ddr3_addr_sdram[1]   <=  #(TPROP_PCB_CTRL) (CA_MIRROR == "ON") ?
                                                 {ddr3_addr_fpga[ROW_WIDTH-1:9],
                                                  ddr3_addr_fpga[7], ddr3_addr_fpga[8],
                                                  ddr3_addr_fpga[5], ddr3_addr_fpga[6],
                                                  ddr3_addr_fpga[3], ddr3_addr_fpga[4],
                                                  ddr3_addr_fpga[2:0]} :
                                                 ddr3_addr_fpga;
    ddr3_ba_sdram[0]     <=  #(TPROP_PCB_CTRL) ddr3_ba_fpga;
    ddr3_ba_sdram[1]     <=  #(TPROP_PCB_CTRL) (CA_MIRROR == "ON") ?
                                                 {ddr3_ba_fpga[3-1:2],
                                                  ddr3_ba_fpga[0],
                                                  ddr3_ba_fpga[1]} :
                                                 ddr3_ba_fpga;
    ddr3_ras_n_sdram     <=  #(TPROP_PCB_CTRL) ddr3_ras_n_fpga;
    ddr3_cas_n_sdram     <=  #(TPROP_PCB_CTRL) ddr3_cas_n_fpga;
    ddr3_we_n_sdram      <=  #(TPROP_PCB_CTRL) ddr3_we_n_fpga;
    ddr3_cke_sdram       <=  #(TPROP_PCB_CTRL) ddr3_cke_fpga;
  end
    

  always @( * )
    ddr3_cs_n_sdram_tmp   <=  #(TPROP_PCB_CTRL) ddr3_cs_n_fpga;
  assign ddr3_cs_n_sdram =  ddr3_cs_n_sdram_tmp;
    

  always @( * )
    ddr3_dm_sdram_tmp <=  #(TPROP_PCB_DATA) ddr3_dm_fpga;//DM signal generation
  assign ddr3_dm_sdram = ddr3_dm_sdram_tmp;
    

  always @( * )
    ddr3_odt_sdram_tmp  <=  #(TPROP_PCB_CTRL) ddr3_odt_fpga;
  assign ddr3_odt_sdram =  ddr3_odt_sdram_tmp;
    

// Controlling the bi-directional BUS

  genvar dqwd;
  generate
    for (dqwd = 1;dqwd < DQ_WIDTH;dqwd = dqwd+1) begin : dq_delay
      WireDelay #
       (
        .Delay_g    (TPROP_PCB_DATA),
        .Delay_rd   (TPROP_PCB_DATA_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dq
       (
        .A             (ddr3_dq_fpga[dqwd]),
        .B             (ddr3_dq_sdram[dqwd]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );
    end
    // For ECC ON case error is inserted on LSB bit from DRAM to FPGA
          WireDelay #
       (
        .Delay_g    (TPROP_PCB_DATA),
        .Delay_rd   (TPROP_PCB_DATA_RD),
        .ERR_INSERT (ERR_INSERT)
       )
      u_delay_dq_0
       (
        .A             (ddr3_dq_fpga[0]),
        .B             (ddr3_dq_sdram[0]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );
  endgenerate

  genvar dqswd;
  generate
    for (dqswd = 0;dqswd < DQS_WIDTH;dqswd = dqswd+1) begin : dqs_delay
      WireDelay #
       (
        .Delay_g    (TPROP_DQS),
        .Delay_rd   (TPROP_DQS_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dqs_p
       (
        .A             (ddr3_dqs_p_fpga[dqswd]),
        .B             (ddr3_dqs_p_sdram[dqswd]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );

      WireDelay #
       (
        .Delay_g    (TPROP_DQS),
        .Delay_rd   (TPROP_DQS_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dqs_n
       (
        .A             (ddr3_dqs_n_fpga[dqswd]),
        .B             (ddr3_dqs_n_sdram[dqswd]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );
    end
  endgenerate
    

    

  //===========================================================================
  //                         FPGA Memory Controller
  //===========================================================================

wire clk;
reg dataValid;
reg [31:0] address;
reg [31:0] data;
wire [10:0] highestScore;
wire processEnd;
wire readDataValid;
reg readData;
wire [31:0] o_readData;
  
  HBlast #
    (

     .SIMULATION                (SIMULATION),
     .COL_WIDTH                 (COL_WIDTH),
     .CS_WIDTH                  (CS_WIDTH),
     .DM_WIDTH                  (DM_WIDTH),
     .DQ_WIDTH                  (DQ_WIDTH),
     .DQS_CNT_WIDTH             (DQS_CNT_WIDTH),
     .DRAM_WIDTH                (DRAM_WIDTH),
     .ECC_TEST                  (ECC_TEST),
     .RANKS                     (RANKS),
     .ROW_WIDTH                 (ROW_WIDTH),
     .ADDR_WIDTH                (ADDR_WIDTH),
     .BURST_MODE                (BURST_MODE),
     .TCQ                       (TCQ),
    .DRAM_TYPE                 (DRAM_TYPE),
    .nCK_PER_CLK               (nCK_PER_CLK),
     .DEBUG_PORT                (DEBUG_PORT),
     .RST_ACT_LOW               (RST_ACT_LOW)
    )
   hbtop
     (

     .ddr3_dq              (ddr3_dq_fpga),
     .ddr3_dqs_n           (ddr3_dqs_n_fpga),
     .ddr3_dqs_p           (ddr3_dqs_p_fpga),

     .ddr3_addr            (ddr3_addr_fpga),
     .ddr3_ba              (ddr3_ba_fpga),
     .ddr3_ras_n           (ddr3_ras_n_fpga),
     .ddr3_cas_n           (ddr3_cas_n_fpga),
     .ddr3_we_n            (ddr3_we_n_fpga),
     .ddr3_reset_n         (ddr3_reset_n),
     .ddr3_ck_p            (ddr3_ck_p_fpga),
     .ddr3_ck_n            (ddr3_ck_n_fpga),
     .ddr3_cke             (ddr3_cke_fpga),
     .ddr3_cs_n            (ddr3_cs_n_fpga),
    
     .ddr3_dm              (ddr3_dm_fpga),
    
     .ddr3_odt             (ddr3_odt_fpga),
    
     
     .sys_clk_p            (sys_clk_p),
     .sys_clk_n            (sys_clk_n),
    
     .clk_ref_i            (clk_ref_i),
    
      .init_calib_complete (init_calib_complete),
      .sys_rst             (sys_rst),
	  
	  .ddr_user_clk(clk),
	  .rst(!sys_rst_n),
      .data(data),
      .address(address),
      .dataValid(dataValid),
      .readData(readData),
      .o_data(o_readData),
      .read_data_valid(readDataValid),
      .processEnd(processEnd)
     );

  //**************************************************************************//
  // Memory Models instantiations
  //**************************************************************************//

  genvar r,i;
  generate
    for (r = 0; r < CS_WIDTH; r = r + 1) begin: mem_rnk
      for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem
        ddr3_model u_comp_ddr3
          (
           .rst_n   (ddr3_reset_n),
           .ck      (ddr3_ck_p_sdram),
           .ck_n    (ddr3_ck_n_sdram),
           .cke     (ddr3_cke_sdram[r]),
           .cs_n    (ddr3_cs_n_sdram[r]),
           .ras_n   (ddr3_ras_n_sdram),
           .cas_n   (ddr3_cas_n_sdram),
           .we_n    (ddr3_we_n_sdram),
           .dm_tdqs (ddr3_dm_sdram[i]),
           .ba      (ddr3_ba_sdram[r]),
           .addr    (ddr3_addr_sdram[r]),
           .dq      (ddr3_dq_sdram[MEMORY_WIDTH*(i+1)-1:MEMORY_WIDTH*(i)]),
           .dqs     (ddr3_dqs_p_sdram[i]),
           .dqs_n   (ddr3_dqs_n_sdram[i]),
           .tdqs_n  (),
           .odt     (ddr3_odt_sdram[r])
           );
      end
    end
  endgenerate
  
  reg [31:0] ddr [0:99];
  
  initial
  begin
     ddr[0] = 32'h120d5698;
     ddr[1] = 32'h120d5698;
     ddr[2] = 32'h120d5698;            
     ddr[3] = {32{1'b1}}; 
     ddr[4] = {32{1'b1}};//{512{1'b1}};
     ddr[5] = {32{1'b1}}; 
     ddr[6] = {32{1'b1}}; 
     ddr[7] = {32{1'b1}}; 
     ddr[8] = 32'h120d5698; 
     ddr[9] = {32{1'b1}}; 
     ddr[10] = {32{1'b1}}; 
     ddr[11] = {32{1'b1}}; 
     ddr[12] = {32{1'b1}};  
     ddr[13] = {32{1'b1}}; 
     ddr[14] = {32{1'b1}}; 
     ddr[15] = {32{1'b1}}; 
     ddr[16] = {32{1'b1}}; 
     ddr[17] = {32{1'b1}};
          ddr[18] = {32{1'b1}};
          ddr[19] = {32{1'b1}};             
          ddr[20] = {32{1'b1}}; 
          ddr[21] = {32{1'b1}};//{512{1'b1}};
          ddr[22] = {32{1'b1}}; 
          ddr[23] = {32{1'b1}}; 
          ddr[24] = {32{1'b1}}; 
          ddr[25] = {32{1'b1}}; 
          ddr[26] = {32{1'b1}}; 
          ddr[27] = {32{1'b1}}; 
          ddr[28] = {32{1'b1}}; 
          ddr[29] = {32{1'b1}}; 
          ddr[30] = {32{1'b1}}; 
          ddr[31] = {32{1'b1}}; 
          ddr[32] = {32{1'b1}}; 
          ddr[33] = {32{1'b1}}; 
          ddr[34] = {32{1'b1}};
               ddr[35] = {32{1'b1}};
               ddr[36] = {32{1'b1}};             
               ddr[37] = {32{1'b1}}; 
               ddr[38] = {32{1'b1}};//{512{1'b1}};
               ddr[39] = {32{1'b1}}; 
               ddr[40] = {32{1'b1}}; 
               ddr[41] = {32{1'b1}}; 
               ddr[42] = {32{1'b1}}; 
               ddr[43] = {32{1'b1}}; 
               ddr[44] = {32{1'b1}}; 
               ddr[45] = {32{1'b1}}; 
               ddr[46] = 32'h120d5698; 
               ddr[47] = 32'h120d5698;
               ddr[48] = {32{1'b1}}; 
               ddr[49] = {32{1'b1}}; 
               ddr[50] = {32{1'b1}}; 
                  ddr[51] = {32{1'b1}};
                           ddr[52] = {32{1'b1}};             
                           ddr[53] = {32{1'b1}}; 
                           ddr[54] = {32{1'b1}};//{512{1'b1}};
                           ddr[55] = {32{1'b1}}; 
                           ddr[56] = {32{1'b1}}; 
                           ddr[57] = {32{1'b1}}; 
                           ddr[58] = {32{1'b1}}; 
                           ddr[59] = {32{1'b1}}; 
                           ddr[60] = {32{1'b1}}; 
                           ddr[61] = {32{1'b1}}; 
                           ddr[62] = {32{1'b1}}; 
                           ddr[63] = {32{1'b1}}; 
                           ddr[64] = 32'h1234abc0; ; 
                           ddr[65] = 32'h1234abcd; //32'h1234abc0;
                           ddr[66] = 32'h1234abcd; //1234abcd1234abcd1234abcd
                           ddr[67] = {32{1'b0}};
                           ddr[68] = {32{1'b0}};
                           ddr[69] = {32{1'b0}};
                            ddr[70] = {32{1'b0}};
                                         ddr[71] = {32{1'b0}};            
                                         ddr[72] = {32{1'b0}};
                                         ddr[73] = {32{1'b0}};//{512{1'b1}};
                                         ddr[74] = {32{1'b0}}; 
                                         ddr[75] = {32{1'b0}}; 
                                         ddr[76] = {32{1'b0}};
                                         ddr[77] = {32{1'b0}}; 
                                         ddr[78] = {32{1'b0}}; 
                                         ddr[79] = {32{1'b0}}; 
                                         ddr[80] = {32{1'b0}}; 
                                         ddr[81] = {32{1'b0}};
                                         ddr[82] = {32{1'b0}};
                                         ddr[83] = {32{1'b0}};
                                         ddr[84] = {32{1'b0}};
                                         ddr[85] = {32{1'b0}};
                                          ddr[86] = {32{1'b0}};            
                                                                                 ddr[87] = {32{1'b0}};
                                                                                 ddr[88] = {32{1'b0}};//{512{1'b1}};
                                                                                 ddr[89] = {32{1'b0}}; 
                                                                                 ddr[90] = {32{1'b0}}; 
                                                                                 ddr[91] = {32{1'b0}};
                                                                                 ddr[92] = {32{1'b0}}; 
                                                                                 ddr[93] = {32{1'b0}}; 
                                                                                 ddr[94] = {32{1'b0}}; 
                                                                                 ddr[95] = {32{1'b0}}; 
                                                                                 ddr[96] = {32{1'b0}};
                                                                                 ddr[97] = {32{1'b0}};
                                                                                 ddr[98] = {32{1'b0}};
                                                                                 ddr[99] = {32{1'b0}};
                                                                                 ddr[100] = {32{1'b0}};
  end
  
    reg [31:0] query [0:15];
  initial
  begin
  //'h1234abcd
     query[0] = 32'h1234abcd;
     query[1] = 32'h1234abcd;
     query[2] = 32'h1234abcd;            
     query[3] = {32{1'b0}}; 
     query[4] = {32{1'b0}}; 
     query[5] = {32{1'b0}}; 
     query[6] = {32{1'b0}}; 
     query[7] = {32{1'b0}}; 
     query[8] = {32{1'b0}}; 
     query[9] = {32{1'b0}}; 
     query[10] = {32{1'b0}}; 
     query[11] = {32{1'b0}};  
     query[12] = {32{1'b0}}; 
     query[13] = {32{1'b0}}; 
     query[14] = {32{1'b0}};  
     query[15] = {32{1'b0}}; 
     query[16] = {32{1'b0}}; 
  end
    
reg start;    
    
initial
begin
    start <= 0;
	wait(init_calib_complete);
	$display("DDR link-up");
	#50000;
	wrDB();
	wrQuerry();
	start <= 1;
end



task wrDDR;
input [31:0] addressIn;
input [31:0] dataIn;
begin
    @(posedge clk);
    dataValid <= 1;
    data <= dataIn;
    address <= addressIn;
    @(posedge clk);
    dataValid <= 0;
end
endtask

task wrDB;
    integer i;
    integer data;
begin
    data=0;
    for(i=0;i<100;i=i+2)
    begin
     $display("Write ddr:  %d and %d", i, i+1);
     wrDDR(64,ddr[i]);
     wrDDR(68,ddr[i+1]);
     #100000;
    end
end
endtask

task wrQuerry;
    integer data;
    integer i;
    integer addreesQuery;
begin
    addreesQuery =0;
    data=0;
    for(i=0;i<16;i=i+1)
    begin
     $display("Write query: %d", i);
     wrDDR(addreesQuery,query[i]);
     addreesQuery=addreesQuery+4;
     #100000;
    end
end
endtask

initial
begin
      wait(start);
      @(posedge clk);
      readData <= 1'b1;
      address <= 0;
      wait(readDataValid & o_readData[0] == 1);
      $display("Process ended");
      readData <= 1'b0;
      @(posedge clk);
      address <= 4;
      readData <= 1'b1;
      wait(readDataValid);
      readData <= 1'b0;
      $display("Highest score 1 %d",o_readData);
      address <= 16;
      readData <= 1'b1;
      wait(readDataValid);
      readData <= 1'b0;
      $display("Highest score 2 %d",o_readData);
      address <= 28;
      readData <= 1'b1;
      wait(readDataValid);
      readData <= 1'b0;
      $display("Highest score 3 %d",o_readData);
      address <= 40;
      readData <= 1'b1;
      wait(readDataValid);
      readData <= 1'b0;
      $display("Highest score 4 %d",o_readData);
      address <= 52;
      readData <= 1'b1;
      wait(readDataValid);
      readData <= 1'b0;
      $display("Highest score 5 %d",o_readData);
end
    
endmodule