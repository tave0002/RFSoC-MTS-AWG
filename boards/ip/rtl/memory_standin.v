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



module memory_standin(/*include once I can access vivado*/);
   
    reg [39:0] memAddress;
    reg [511:0] dataBus;

    
    


endmodule