// -------------------------------------------------------------------------------------------------
// Copyright (C) 2023 Advanced Micro Devices, Inc
// SPDX-License-Identifier: MIT
// ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --
`timescale 1ns / 1ps

module DACRAMstreamer #( parameter DWIDTH = 512, parameter MEM_SIZE_BYTES = 131072, parameter ADDR_WIDTH = 32) ( //params here are defaults that can be edited in Vivado block design
  (* X_INTERFACE_PARAMETER = "MAX_BURST_LENGTH 256,NUM_WRITE_OUTSTANDING 0,NUM_READ_OUTSTANDING 1,READ_WRITE_MODE READ_ONLY,ADDR_WIDTH 32,DATA_WIDTH 512,HAS_BURST 1" *)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 AWADDR" *)
  output [ADDR_WIDTH-1:0] M_AXI_DDR4_awaddr, // Write address (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 AWLEN" *)
  output [7:0] M_AXI_DDR4_awlen, // Burst length (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 AWSIZE" *)
  output [2:0] M_AXI_DDR4_awsize, // Burst size (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 AWBURST" *)
  output [1:0] M_AXI_DDR4_awburst, // Burst type (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 AWREGION" *)
  output [3:0] M_AXI_DDR4_awregion, // Write address slave region (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 AWVALID" *)
  output M_AXI_DDR4_awvalid, // Write address valid (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 AWREADY" *)
  input M_AXI_DDR4_awready, // Write address ready (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 WDATA" *)
  output [DWIDTH-1:0] M_AXI_DDR4_wdata, // Write data (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 WVALID" *)
  output M_AXI_DDR4_wvalid, // Write valid (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 WREADY" *)
  input M_AXI_DDR4_wready, // Write ready (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 BRESP" *)
  input [1:0] M_AXI_DDR4_bresp, // Write response (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 BVALID" *)
  input M_AXI_DDR4_bvalid, // Write response valid (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 BREADY" *)
  output M_AXI_DDR4_bready, // Write response ready (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 ARADDR" *)
  output reg [ADDR_WIDTH-1:0] M_AXI_DDR4_araddr, // Read address (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 ARLEN" *)
  output [7:0] M_AXI_DDR4_arlen, // Burst length (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 ARSIZE" *)
  output [2:0] M_AXI_DDR4_arsize, // Burst size (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 ARBURST" *)
  output [1:0] M_AXI_DDR4_arburst, // Burst type (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI_DDR4 ARREGION" *)
  output [3:0] M_AXI_DDR4_arregion, // Read address slave region (optional)
  
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
  output reg M_AXI_DDR4_rready, // Read ready (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_clk CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF AXIS, ASSOCIATED_RESET axis_aresetn" *)
  input wire axis_clk,
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axis_aresetn RST" *)

  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 m_axi_aclk CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF M_AXI_DDR4, ASSOCIATED_RESET axis_aresetn" *)
  input m_axi_clk, 
  
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axis_aresetn RST" *)
  input  wire              axis_aresetn,
  output reg  [DWIDTH-1:0] axis_tdata,       // luckily rest of AXIS is inferred properly
  input  wire              axis_tready,
  output reg               axis_tvalid,
  

  // Control Input Parameters
  input enable );

  wire [ADDR_WIDTH-1:0] baseAddress;
  assign baseAddress = 40'h1000000000; //hardcoded for now but will try to add a param for it another day
  wire [ADDR_WIDTH-1:0] ramAddressLimit;
  M_AXI_DDR4_araddr = baseAddress; //initialise it at the starting address
  assign M_AXI_DDR4_wdata = 0;
  assign ramAddressLimit = baseAddress + MEM_SIZE_BYTES - M_AXI_DDR4_arlen*DWIDTH/8 -1; //want the limit to be the final memory address read before wrap around, not the actual last element in memory
  assign M_AXI_DDR4_arburst = 2'b01; //this is a parameter, setting it to 1 results in incrimental burst (e.g. moves to the next memory address for each burst transfer)
  assign M_AXI_DDR4_arlen = 8'd63; //burst length is 64 since it adds 1, not using full size since burst cannot overrun the 4KB memory guards 
  


  //the below bit gives you log2 of the DWIDTH param (since it also is only powers of 2 in bytes which is how the arsize param has to be formatted
  wire [8:0] dWidthByte;
  assign dWidthByte=DWIDTH/8; //data width in bytes
  assign M_AXI_DDR4_arsize[0] = dWidthByte[1]|dWidthByte[3]|dWidthByte[5]|dWidthByte[7];  //Sets the data transfer width to 512 bits
  assign M_AXI_DDR4_arsize[1] = dWidthByte[2]|dWidthByte[3]|dWidthByte[6]|dWidthByte[7];
  assign M_AXI_DDR4_arsize[2] = dWidthByte[7];

  always @(posedge axis_clk) begin //done this way since the AXIS and AXI bus run at the same speed and both are referenced to the DDR4 clock

    if (~axis_aresetn) begin
  	  axis_tvalid <= 0;
      M_AXI_DDR4_arvalid <= 0;
      M_AXI_DDR4_rready <= 0;
  	end else begin
      if(axis_tready) begin
        M_AXI_DDR4_rready <= 1'b1;
      end else begin
        M_AXI_DDR4_rready <= 1'b0; //should check if having two non blocked assignments of the same value is a legal move
      end

      if (enable) begin
      //For the below code, ensures that once a read starts, the "read address valid" signal goes low so the read address can be updated, turning it back on happens in the section of code that updates the actual address
      if(M_AXI_DDR4_arready) begin 
        M_AXI_DDR4_arvalid <= 1'b0;
      end 

      if(M_AXI_DDR4_rvalid & ~M_AXI_DDR4_rresp[1]) begin //might want to put in "& M_AXI_DDR4_rready" but based on my understanding of how it all works this should be fine. the rresp[1] checks if there has been an error
          axis_tdata <= M_AXI_DDR4_rdata;
          axis_tvalid <= 1'b1; //possible issue here with this perhaps missing the first data point
      end else begin
        axis_tvalid <= 1'b0;
      end

		  if(M_AXI_DDR4_rlast) begin
        if (M_AXI_DDR4_araddr >= ramAddressLimit) begin //NEED TO CHANGE ramAddressLimit and based on that can choose how to handle this
		      M_AXI_DDR4_araddr <= baseAddress;
        end else begin
          M_AXI_DDR4_araddr <= M_AXI_DDR4_araddr + M_AXI_DDR4_arlen*DWIDTH/8;
        end
        M_AXI_DDR4_arvalid <= 1'b1; //although it is non blocking, this at least ensures they execute 
		  end
  	end else begin
  	  axis_tvalid <= 0;
      M_AXI_DDR4_araddr <= baseAddress;
      M_AXI_DDR4_arvalid <= 1;
  	end
  end
end
endmodule
