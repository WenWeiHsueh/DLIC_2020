// This is generated automatically on 2021/09/17-00:04:10
`ifndef __FLAG_DEF__
`define __FLAG_DEF__

// There're 6 interrupt flags in this design
`define INT_WAIT               	 0  
`define INT_READ_W             	 1  
`define INT_READ               	 2  
`define INT_OPT                	 3  
`define INT_WRITE              	 4  
`define INT_END                	 5  
`define INT_FLAG_W             	 6  

// There're 6 output flags in this design
`define CMD_WAIT               	 0  
`define CMD_READ_W             	 1  
`define CMD_READ               	 2  
`define CMD_OPT                	 3  
`define CMD_WRITE              	 4  
`define CMD_END                	 5  
`define CMD_FLAG_W             	 6  

// There're 6 states in this design
`define S_WAIT                 	 0  
`define S_READ_W               	 1  
`define S_READ                 	 2  
`define S_OPT                  	 3  
`define S_WRITE                	 4  
`define S_END                  	 5  
`define S_ZVEC                 	 6'b0
`define STATE_W                	 6  

// Macro from template
`define BUF_SIZE               	 9  
`define DATA_WIDTH             	 32 
`define ADDR_WIDTH             	 32 
`define EMPTY_WORD             	 32'b0
`define EMPTY_ADDR             	 32'b0

// Self-defined macro
`define CNT_W                  	 4  
`define GLB_CNT_W              	 5  
`define IMG_SIZE               	 28 

`endif
