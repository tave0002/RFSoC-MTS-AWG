`timescale 1ns / 1ps

module dacram_testbench;
    //all wires required to connect the DACRAMStreamer and memory standin along with registers to drive some IOs
    wire [39:0] araddr;
    wire [7:0] arlen;
    wire [2:0] arsize;
    wire [1:0] arburst;
    wire arvalid;
    wire arready;
    wire [511:0] rdata;
    wire [1:0] rresp;
    wire rvalid;
    wire rready;
    wire rlast;
    wire [511:0] tdata;
    wire tvalid;
    
    reg tready;
    reg enable;
    reg clk;
    reg aresetn;
    
    //values used for testbenching
    integer counter;
    integer errorCount;
    
    DACDDR4streamer tbstreamer(
        .M_AXI_DDR4_araddr(araddr),
        .M_AXI_DDR4_arlen(arlen),
        .M_AXI_DDR4_arsize(arsize),
        .M_AXI_DDR4_arburst(arburst),
        .M_AXI_DDR4_arvalid(arvalid),
        .M_AXI_DDR4_arready(arready),
        .M_AXI_DDR4_rdata(rdata),
        .M_AXI_DDR4_rresp(rresp),
        .M_AXI_DDR4_rlast(rlast),
        .M_AXI_DDR4_rvalid(rvalid),
        .M_AXI_DDR4_rready(rready),
        .axis_clk(clk),
        .m_axi_clk(clk),
        .axis_aresetn(aresetn),
        .axis_tready(tready),
        .axis_tvalid(tvalid),
        .axis_tdata(tdata),
        .enable(enable)
    );  

    memory_standin tbmem(
        .S_AXI_mem_araddr(araddr),
        .S_AXI_mem_arlen(arlen),
        .S_AXI_mem_arsize(arsize),
        .S_AXI_mem_arburst(arburst),
        .S_AXI_mem_arvalid(arvalid),
        .S_AXI_mem_arready(arready),
        .S_AXI_mem_rdata(rdata),
        .S_AXI_mem_rresp(rresp),
        .S_AXI_mem_rlast(rlast),
        .S_AXI_mem_rvalid(rvalid),
        .S_AXI_mem_rready(rready),
        .s_axi_aclk(clk),
        .s_axi_rstn(aresetn)        
    );

    initial begin
        tready=0;
        enable=0;
        clk=0;
        aresetn=0; //start in reset state
        counter=0;
        errorCount=0;
    end

    //clock signal
    always begin
        #1.67 //300MHz clock, idk if this actually matters but I'm just gonna do it to be safe
        clk=~clk;
    end

    always @(posedge clk) begin //makes it easier to keep track of times
        if(counter==10) begin
            aresetn<=1; //everything is left in reset and not enables for first 10 clock cycles
        end

        if(counter==20) begin
            enable<=1;
        end

        if(counter==30) begin
            tready<=1;
        end

        if(counter==170) begin //should have executed at last 2 full bursts by this point and in the middle of a third, this checks if it pauses correctly
            tready<=0;
        end

        if (counter==180) begin //checks that it then resumes correctly
            tready<=1;
        end

        if(counter==240) begin //should be starting a fresh burst by now
            enable<=0; //honestly thinking about it not sure what will happen here, I think it will finish the previous transfer and then go back to the start
        end

        if (counter==250) begin
            enable<=1;
        end

        if (counter==260) begin
            aresetn <= 0;
        end

        if (counter==270) begin
            aresetn <= 1;
        end
        
        if (counter==300) begin
            enable <= 0;
        end
         
        if(counter==350) begin
            enable <= 1;
        end
        
        if (counter>390) begin
            aresetn<=0;
            $finish;
        end
        counter=counter+1;
    end

endmodule