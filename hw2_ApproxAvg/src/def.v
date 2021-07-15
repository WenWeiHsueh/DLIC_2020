// This is generated automatically on 2021/07/15-11:56:16
`ifndef __FLAG_DEF__
`define __FLAG_DEF__

// There're 3 interrupt flags in this design
`define INT_WAIT               	 0  
`define INT_READ               	 1  
`define INT_OUTP               	 2  
`define INT_FLAG_W             	 3  

// There're 3 output flags in this design
`define CMD_WAIT               	 0  
`define CMD_READ               	 1  
`define CMD_OUTP               	 2  
`define CMD_FLAG_W             	 3  

// There're 4 states in this design
`define S_WAIT                 	 0  
`define S_READ                 	 1  
`define S_OUTP                 	 2  
`define S_END                  	 3  
`define S_ZVEC                 	 4'b0
`define STATE_W                	 4  

// Other macro in this design
`define EMPTY_ADDR             	 {12{1'b0}}
`define EMPTY_DATA             	 {20{1'b0}}
`define LOCAL_IDX_WIDTH        	 16 
`define DATA_WIDTH             	 20 
`define CNT_W                  	 16 

`endif
