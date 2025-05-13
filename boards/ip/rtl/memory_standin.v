//Author: Tom Avent (tomavent122@gmail.com)
//Date: 12/05/2025
//Purpose: Act as a module to send and receive AXI-protocol formatted data packets for use in test benching
/*general plan of how to do it.
        - First this is mimicing the DDR4 ram, so need to be able to "access" lots of memory
        - Plan is when the address valid signal from DAACRAMStreamer goes high, take the address value in
        - Then just pad the 512 bits that will be read out on the bus by using the 40 to make some random number using lots of gates or addition
        - Then plug this header onto the memory address and put it on the output bus
        - Then each sucsessive clock cycle of the burst just add 1 to the total data value so I can see it changing
        - Obviously meanwhile obaying all the important axi protocols
        - Then rince and repeat
        - Remember you'll need to take a clock input as well
        - Use Vivado to generate the actual IO ports and remove the ones we don't need
*/

module memory_standin((* X_INTERFACE_PARAMETER = "MAX_BURST_LENGTH 256,NUM_WRITE_OUTSTANDING 0,NUM_READ_OUTSTANDING 1,READ_WRITE_MODE WRITE_ONLY,ADDR_WIDTH 40, DATA_WIDTH 512,HAS_BURST 1" *)
  //note, actuall address width od the ddr4 is 32 bits but there is an interconnect that drops the 40 down to 32 in the real design, to avoid complication I'm just making this 40 as well  


  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_mem ARADDR" *)
  input [ADDR_WIDTH-1:0] S_AXI_mem_araddr, // Read address (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_mem ARLEN" *)
  input [7:0] S_AXI_mem_arlen, // Burst length (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_mem ARSIZE" *)
  input [2:0] S_AXI_mem_arsize, // Burst size (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_mem ARBURST" *)
  input [1:0] S_AXI_mem_arburst, // Burst type (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_mem ARVALID" *)
  input S_AXI_mem_arvalid, // Read address valid (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_mem ARREADY" *)
  output S_AXI_mem_arready, // Read address ready (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_mem RDATA" *)
  output [DATA_WIDTH-1:0] S_AXI_mem_rdata, // Read data (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_mem RRESP" *)
  output [1:0] S_AXI_mem_rresp, // Read response (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_mem RLAST" *)
  output S_AXI_mem_rlast, // Read last beat (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_mem RVALID" *)
  output S_AXI_mem_rvalid, // Read valid (optional)
  
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_mem RREADY" *)
  input S_AXI_mem_rready, // Read ready (optional)

  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
  (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF M_AXI_DDR4, ASSOCIATED_RESET s_axi_rstn" *)
  input wire s_axi_aclk; //naming this way will let vivado infer this is a clock interface, see https://docs.amd.com/r/2022.2-English/ug1118-vivado-creating-packaging-custom-ip/Inferring-Clock-and-Reset-Interfaces
  
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 s_axi_rstn RST" *)
  input wire s_axi_rstn;

);
   //These reg will drive the outputs, doing it this way means I can use shorter variables names in the actual operation
    reg [ADDR_WIDTH-1:0] memAddress;
    reg [DATA_WIDTH-1:0] dataBus;
    reg arready;
    reg [1:0] rresp;
    reg rlast;
    reg rvalid;
    reg [7:0] burstCount; //when a valid signal comes in, set equal to arlen and then decriment on each clock transfer
    reg [7:0] requestedBursts; //reference value for how many total bursts were requested
    reg [2:0] burstSize;
    reg [DATA_WIDTH-1:0] dummyData; //to be used as the data pulled from memory

    assign S_AXI_mem_arready=arready;
    assign S_AXI_mem_rresp[1:0]=rresp[1:0];
    assign S_AXI_mem_rlast=rlast; 
    assign S_AXI_mem_rvalid=rvalid;

    initial begin
      burstCount=0;
      arready=0;
      rresp=0; //00 means no error
      rlast=0;
      rvalid=0;
      dataBus=0;
      memAddress=0;
    end

    always @(posedge s_axi_aclk) begin
      if(~s_axi_rstn) begin
        dataBus<=0;
        memAddress<=0;
        arready<=0;
        rvalid<=0;
      end else begin
        if(burstCount== 8'b00000000) begin
          arready=1'b1; //if the count is at 0, then 
          if(S_AXI_mem_arvalid) begin
            memAddress<=S_AXI_mem_araddr;
            burstSize[2:0]<=S_AXI_mem_arsize[2:0];
            //check if we actually got the incrimental burst signal
            if(S_AXI_mem_arburst == 2'b01) begin
              burstCount<=S_AXI_mem_arlen+1; //the +1 is part of the read request axi protocol
              requestedBursts<=S_AXI_mem_arlen+1;
            end else begin
              burstCount<=8'b00000001;
              requestedBursts <= 8'b00000001;
            end
            arready=0; //once the data is loaded in, set ready to receive new as 0
          end
        end else begin
          if(burstCount==requestedBursts) begin
            //pad the top of data bus
          end else begin
            //incriment value on data bus by 1
          end        
        end
      end


    end

endmodule