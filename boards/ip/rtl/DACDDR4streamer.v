//IP Name: DACDDR4streamer
//Original Authors:
  // -------------------------------------------------------------------------------------------------
  // Copyright (C) 2023 Advanced Micro Devices, Inc
  // SPDX-License-Identifier: MIT
  // ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --
//Modifications made by: Tom Avent
//Last Modified: 14/07/2025

//Purpose: The original DACRAMStreamer was a custom RTL IP made for the MTS overlay where it streamed data from a block of BRAM into the RFDC IP block to generate waveforms
//  this modified version performs a similar task but for the DDR4 SDRAM (MIG) Controller IP, with the aim of achiving the same streaming rate but with a much deeper memory.
//  This uses the AXI-4 protocol to request data from the DDR4 and places said data on the M_AXIS data bus.
//  Please note in accordance with Vivados address managment system kilo, mega, and gigabytes are 1024, 1024^2, 1024^3 bytes respectivly

`timescale 1ns / 1ps

module DACDDR4streamer #( parameter DWIDTH = 512, parameter MEM_SIZE_kBYTES = 524288, parameter ADDR_WIDTH = 40, parameter START_ADDR = 40'h1000000000) ( //params here are defaults that can be edited in Vivado block design
  (* X_INTERFACE_PARAMETER = "MAX_BURST_LENGTH 256,NUM_WRITE_OUTSTANDING 0,NUM_READ_OUTSTANDING 1,READ_WRITE_MODE READ_ONLY,ADDR_WIDTH 40,DATA_WIDTH 512,HAS_BURST 1" *)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *)
  output reg [ADDR_WIDTH-1:0] M_AXI_araddr, // Read address (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARLEN" *)
  output [7:0] M_AXI_arlen, // Burst length (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARSIZE" *)
  output [2:0] M_AXI_arsize, // Burst size (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARBURST" *)
  output [1:0] M_AXI_arburst, // Burst type (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *)
  output reg M_AXI_arvalid, // Read address valid (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *)
  input M_AXI_arready, // Read address ready (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RDATA" *)
  input [DWIDTH-1:0] M_AXI_rdata, // Read data (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RRESP" *) //at some point this should be used to check if the read was actually sucsessful
  input [1:0] M_AXI_rresp, // Read response (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RLAST" *)
  input M_AXI_rlast, // Read last beat (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RVALID" *)
  input wire M_AXI_rvalid, // Read valid (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RREADY" *)
  output reg M_AXI_rready, // Read ready (optional)
 
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF M_AXI:M_AXIS, ASSOCIATED_RESET aresetn" *)
  input wire aclk, 
  
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
  input wire aresetn,
  //rest of M_AXIS is infered from this
  output reg [DWIDTH-1:0] M_AXIS_tdata,       
  input  wire M_AXIS_tready,
  output reg M_AXIS_tvalid,
  
  input wire enable, //a user controlled input that allows the user to suspend the data transaction and update the memory 
  input wire fifo_almost_full
  );

  //memory parameters
  reg [ADDR_WIDTH-1:0] ramAddressLimit;
  reg [DWIDTH-1:0] dataRegister;
  integer incrimentAddress;
  
  //burst parameters
  assign M_AXI_arburst = 2'b01; //this is a parameter, setting it to 1 results in incrimental burst (e.g. moves to the next memory address for each burst transfer)
  assign M_AXI_arlen = 8'd63; //Not using max possible burst size since this would overrun the 4KB memory guards 

  
  //burst size parameters
  wire [7:0] burstSizeByte;
  assign burstSizeByte = DWIDTH/8;
  assign M_AXI_arsize[0] = burstSizeByte[1] | burstSizeByte[3] | burstSizeByte[5] | burstSizeByte[7];  
  assign M_AXI_arsize[1] = burstSizeByte[2] | burstSizeByte[3] | burstSizeByte[6] | burstSizeByte[7];
  assign M_AXI_arsize[2] = burstSizeByte[4] | burstSizeByte[5] | burstSizeByte[6] | burstSizeByte[7];

  //misc parameters
  reg startFlag; //used to set arvalid again once reset or ~enable is deasserted
  reg rlastFlag; //set high when rlast goes high, prevents several memory address jumps, 0 means rlast has noit been asserted, 1 means has been
  integer fullCounter;
  

  initial begin
    ramAddressLimit <= START_ADDR + (MEM_SIZE_kBYTES*1024) - (8*DWIDTH);//full expression is 64*DWIDTH/8 but this simplifies things
    M_AXI_araddr <= START_ADDR; //initialise it at the starting address
    M_AXI_arvalid <= 0;
    M_AXIS_tdata <= 0;
    M_AXIS_tvalid <= 0;
    startFlag <= 1;
    rlastFlag <= 0; 
    fullCounter <= 0;
    incrimentAddress <= 8*DWIDTH; //again this is meant to be 64*DWIDTH/8 but the actual expression is more simple
    dataRegister <= 0;
    M_AXI_rready <= 0;
  end
    

  always @(posedge aclk) begin //done this way since the M_AXIS and AXI bus run at the same speed and both are referenced to the DDR4 clock
    if (~aresetn) begin
  	  M_AXI_araddr <= START_ADDR;
      M_AXI_arvalid <= 0;
      M_AXIS_tdata <= 0;
      M_AXIS_tvalid<=0;
      startFlag <= 1;
      M_AXI_rready <= 0;
      rlastFlag <= 0;
      dataRegister <= 0;
  	end else begin 
        if(enable | (M_AXI_rready & M_AXI_rvalid)) begin
          M_AXI_rready <= M_AXIS_tready & (~fifo_almost_full)  ; //determin if it is ready to read a value by confirming that the FIFO isn't almost full and that it is actually ready to receive values 

          //set arvalid high to begin the transactions
          if (startFlag & enable) begin
            M_AXI_arvalid <= 1;
            startFlag <= 0;
          end

          //check if the fifo almost full flag is high. This handles a very spesific edge case when fifo_almost_full goes high 1 clock cycle before rlast, this is a very bodge fix. Need to come up with something better
          if(fifo_almost_full) begin
            fullCounter <= fullCounter + 1;
          end else begin
            fullCounter <= 0;
          end

          //Ensures once the address is read the arvalid is set low in accordance with axi-4 protocol
          if(M_AXI_arready & M_AXI_arvalid) begin 
            M_AXI_arvalid <= 1'b0;
          end 

          //Loading in the new address once current burst is complete
          if(M_AXI_rlast & enable & ~rlastFlag) begin 
            if (M_AXI_araddr >= ramAddressLimit) begin 
		          M_AXI_araddr <= START_ADDR;
            end else begin
              M_AXI_araddr <= M_AXI_araddr + incrimentAddress;
            end
            M_AXI_arvalid <= 1'b1; 
            rlastFlag <= 1;
          end else if (~M_AXI_rlast) begin
            rlastFlag <= 0;
          end

          //Place rdata on the M_AXIS data bus when a read is in progress
          if((M_AXI_rready | (fullCounter===1 & M_AXI_rlast)) & M_AXI_rvalid) begin //this is really dodgy, again need to fix
            dataRegister <= M_AXI_rdata;
            M_AXIS_tdata <= dataRegister;
            M_AXIS_tvalid<=1;
          end else begin
            M_AXIS_tvalid<=0;
          end

          //If the transaction is still in progress, will finish but setting arvalid low ensures a new one won't start
          if(~enable) begin 
            M_AXI_araddr <= START_ADDR;
            M_AXI_arvalid <=0;
          end
        end else begin
          M_AXI_araddr <= START_ADDR;
          M_AXI_arvalid <= 0;
          M_AXIS_tvalid<=0;
          startFlag <= 1;
          M_AXI_rready <= 0;
          rlastFlag <= 0;
        end
  end
end
endmodule