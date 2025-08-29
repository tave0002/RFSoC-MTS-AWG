module clock_aligner #(parameter DWIDTH_bytes=32 )(
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TDATA" *)
    input [DWIDTH_bytes*8-1:0] S_AXIS_tdata, // Transfer Data (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TVALID" *)
    input S_AXIS_tvalid, // Transfer valid (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 S_AXIS TREADY" *)
    output reg S_AXIS_tready, // Transfer ready (optional)

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA" *)
    output reg [DWIDTH_bytes*8-1:0] M_AXIS_tdata, // Transfer Data (optional)
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *)
    output reg M_AXIS_tvalid, // Transfer valid (required)
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *)
    input M_AXIS_tready, // Transfer ready (optional)
    
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 data_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXIS:M_AXIS, ASSOCIATED_RESET aresetn" *)
    input data_aclk, //data transfer clock
    
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 sync_clk CLK" *)
    input sync_aclk,
    
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input aresetn
);

    always@(posedge data_aclk) begin
        if(aresetn) begin
            if(S_AXIS_tvalid && S_AXIS_tready) begin
                M_AXIS_tdata <= S_AXIS_tdata;
                M_AXIS_tvalid <= 1;
            end else begin
                M_AXIS_tvalid <= 0;
            end
        end else begin
            M_AXIS_tvalid <= 0;
            M_AXIS_tdata <= 0;
        end
    end

    always@(posedge sync_aclk) begin
       if(aresetn) begin
        S_AXIS_tready <= M_AXIS_tready;
       end else begin
        S_AXIS_tready <= 0;
       end
    end

endmodule