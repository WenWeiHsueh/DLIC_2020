// This is generated automatically on 2021/03/16-01:04:01
// Check the # of bits for state registers !!!
// Check the # of bits for flag registers !!!

`ifndef __FLAG_DEF__
`define __FLAG_DEF__

// There're 8 flags in this design
`define F_GEN_IN_ADDR          	 0  
`define F_READ_IN_ENB          	 1  
`define F_CONV_RELU_ENB        	 2  
`define F_WRITE_CONV_ENB       	 3  
`define F_GEN_CONV_ADDR        	 4  
`define F_READ_CONV_ENB        	 5  
`define F_WRITE_POOL_ENB       	 6  
`define F_WRITE_FLAT_ENB       	 7  
`define FLAG_WIDTH             	 8  

// There're 7 states in this design
`define S_READY                	 0  
`define S_READ_WEIGHT          	 1  
`define S_READ_INPUT           	 2  
`define S_MULTIPLY             	 3  
`define S_ADD                  	 4  
`define S_WRITE                	 5  
`define S_FINISH               	 6  
`define S_INIT                 	 7'b0
`define STATE_WIDTH            	 7  

// Other macro in this design
`define IN_BUFFER_SIZE         	 8'd66
`define OUT_BUFFER_SIZE        	 8'd64
`define READ_MEM_DELAY         	 2'd2
`define EMPTY_ADDR             	 {32{1'b0}}
`define EMPTY_DATA             	 {20{1'b0}}
`define LOCAL_IDX_WIDTH        	 10 
`define DATA_WIDTH             	 20 

`endif
