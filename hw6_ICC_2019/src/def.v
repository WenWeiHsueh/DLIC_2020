// This is generated automatically on 2021/03/16-00:40:07
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

// There're 11 states in this design
`define S_IDLE_0               	 0  
`define S_GEN_IN_ADDR          	 1  
`define S_READ_IN              	 2  
`define S_CONV_RELU            	 3  
`define S_WRITE_CONV           	 4  
`define S_CHECK_FINISH         	 5  
`define S_GEN_CONV_ADDR        	 6  
`define S_READ_CONV            	 7  
`define S_WRITE_POOL           	 8  
`define S_WRITE_FLAT           	 9  
`define S_FINISH               	 10 
`define S_INIT                 	 11'b0
`define STATE_WIDTH            	 11 

// Other macro in this design
`define IN_BUFFER_SIZE         	 8'd66
`define OUT_BUFFER_SIZE        	 8'd64
`define READ_MEM_DELAY         	 2'd2
`define EMPTY_ADDR             	 {12{1'b0}}
`define EMPTY_DATA             	 {20{1'b0}}
`define LOCAL_IDX_WIDTH        	 16 
`define DATA_WIDTH             	 20 

`endif
