//IP Name: DACRAMStreamer
//Original Authors:
  // -------------------------------------------------------------------------------------------------
  // Copyright (C) 2023 Advanced Micro Devices, Inc
  // SPDX-License-Identifier: MIT
  // ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --
//Modifications made by: Tom Avent
//Last Modified: 27/05/2025

//Purpose: The original DACRAMStreamer was a custom RTL IP made for the MTS overlay where it streamed data from a block of BRAM into the RFDC IP block to generate waveforms
//  this modified version performs a similar task but for the DDR4 SDRAM (MIG) Controller IP, with the aim of achiving the same streaming rate but with a much deeper memory.
//  THis uses the AXI-4 protocol to request data from the DDR4 and places said data on the axis data bus

`timescale 1ns / 1ps

module DACRAMstreamerDev #( parameter DWIDTH = 512, parameter MEM_SIZE_BYTES = 131072, parameter ADDR_WIDTH = 40) ( //params here are defaults that can be edited in Vivado block design
  (* X_INTERFACE_PARAMETER = "MAX_BURST_LENGTH 256,NUM_WRITE_OUTSTANDING 0,NUM_READ_OUTSTANDING 1,READ_WRITE_MODE READ_ONLY,ADDR_WIDTH 40,DATA_WIDTH 512,HAS_BURST 1" *)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 ARADDR" *)
  output reg [ADDR_WIDTH-1:0] M_AXI_DDR4_araddr, // Read address (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 ARLEN" *)
  output [7:0] M_AXI_DDR4_arlen, // Burst length (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 ARSIZE" *)
  output [2:0] M_AXI_DDR4_arsize, // Burst size (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 ARBURST" *)
  output [1:0] M_AXI_DDR4_arburst, // Burst type (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 ARVALID" *)
  output reg M_AXI_DDR4_arvalid, // Read address valid (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 ARREADY" *)
  input M_AXI_DDR4_arready, // Read address ready (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 RDATA" *)
  input [DWIDTH-1:0] M_AXI_DDR4_rdata, // Read data (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 RRESP" *)
  input [1:0] M_AXI_DDR4_rresp, // Read response (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 RLAST" *)
  input M_AXI_DDR4_rlast, // Read last beat (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 RVALID" *)
  input M_AXI_DDR4_rvalid, // Read valid (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 RREADY" *)
  output wire M_AXI_DDR4_rready, // Read ready (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_clk CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF AXIS, ASSOCIATED_RESET axis_aresetn" *)
  input wire axis_clk,
 
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 m_axi_aclk CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF M_AXI_DDR4, ASSOCIATED_RESET axis_aresetn" *)
  input m_axi_clk, 
  
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axis_aresetn RST" *)
  //The rest of the axis ports are automatically infered by vivado
  input  wire              axis_aresetn,
  output reg  [DWIDTH-1:0] axis_tdata,       
  input  wire              axis_tready,
  output reg               axis_tvalid,
  
  input wire enable //a user controlled input that allows the user to suspend the data transaction and update the memory 
  );

  //memory parameters
  wire [ADDR_WIDTH-1:0] baseAddress;
  wire [ADDR_WIDTH-1:0] ramAddressLimit;
  assign baseAddress = 40'h1000000000; //TODO: make an editable param in vivado
  assign ramAddressLimit = baseAddress + MEM_SIZE_BYTES - M_AXI_DDR4_arlen*DWIDTH/8 -1; //want the limit to be the final memory address read before wrap around, not the actual last element in memory
  assign M_AXI_DDR4_arburst = 2'b01; //this is a parameter, setting it to 1 results in incrimental burst (e.g. moves to the next memory address for each burst transfer)
  assign M_AXI_DDR4_arlen = 8'd63; //Not using max possible burst size since this would overrun the 4KB memory guards 
  assign M_AXI_DDR4_rready=axis_tready & axis_aresetn; //This way the actual important signal is passed directly along so no clock edge delay but doesn't stay on if disabled

  //burst legth parameters
  wire [8:0] dWidthByte;
  assign dWidthByte=DWIDTH/8; //data width in bytes
  assign M_AXI_DDR4_arsize[0] = dWidthByte[1]|dWidthByte[3]|dWidthByte[5]|dWidthByte[7];  //Sets the data transfer width to 512 bits, this line and below gives you log2 of the DWIDTH param (since it also is only powers of 2 in bytes which is how the arsize param has to be formatted 
  assign M_AXI_DDR4_arsize[1] = dWidthByte[2]|dWidthByte[3]|dWidthByte[6]|dWidthByte[7];
  assign M_AXI_DDR4_arsize[2] = dWidthByte[7];

  //misc parameters
  reg startFlag; //used to set arvalid again once reset or ~enable is deasserted


  initial begin
    M_AXI_DDR4_araddr = baseAddress; //initialise it at the starting address
    M_AXI_DDR4_arvalid = 0;
    axis_tdata=0;
    axis_tvalid=0;
    startFlag=1;
  end
    

  always @(posedge axis_clk) begin //done this way since the AXIS and AXI bus run at the same speed and both are referenced to the DDR4 clock
    if (~axis_aresetn) begin
  	  M_AXI_DDR4_araddr <= baseAddress;
      M_AXI_DDR4_arvalid <= 0;
      axis_tdata <= 0;
      axis_tvalid<=0;
      startFlag <= 1;
  	end else begin 
      if (enable | (M_AXI_DDR4_rready & M_AXI_DDR4_rvalid)) begin //ensures if enable is turned off then the transaction finishes
        
        //set arvalid high to begin the transactions
        if (startFlag & enable) begin
          M_AXI_DDR4_arvalid <= 1;
          startFlag <= 0;
        end
        
        //Ensures once the address is read the arvalid is set low in accordance with axi-4 protocol
        if(M_AXI_DDR4_arready & M_AXI_DDR4_arvalid) begin 
          M_AXI_DDR4_arvalid <= 1'b0;
        end 

        //Loading in the new address once current burst is complete
        if(M_AXI_DDR4_rlast & enable) begin 
          if (M_AXI_DDR4_araddr >= ramAddressLimit) begin //functionality of this not yet tested, should set the ramAddressLimit low for a testbench and test the wrap around works as intended
		        M_AXI_DDR4_araddr <= baseAddress;
          end else begin
            M_AXI_DDR4_araddr <= M_AXI_DDR4_araddr + M_AXI_DDR4_arlen*DWIDTH/8;
          end
          M_AXI_DDR4_arvalid <= 1'b1; 
		    end

        //Place rdata on the axis data bus when a read is in progress
        if(M_AXI_DDR4_rready & M_AXI_DDR4_rvalid) begin 
          axis_tdata <= M_AXI_DDR4_rdata;
          axis_tvalid<=1;
        end else begin
          axis_tvalid<=0;
        end
        
        //If the transaction is still in progress, will finish but setting arvalid low ensures a new one won't start
        if(~enable) begin 
          M_AXI_DDR4_araddr <= baseAddress;
          M_AXI_DDR4_arvalid <=0;
        end

      //enable low and no transaction in progress
      end else begin
        M_AXI_DDR4_araddr <= baseAddress;
        M_AXI_DDR4_arvalid <= 0;
        axis_tvalid<=0;
        axis_tdata<=0;
        startFlag <= 1;
  	  end
  end
end
endmodule
