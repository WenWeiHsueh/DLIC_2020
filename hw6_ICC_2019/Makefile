ROOT_DIR				=$(PWD)
BUILD           =build
BUILD_DIR 			=$(ROOT_DIR)/$(BUILD)
SRC_DIR					=$(ROOT_DIR)/src
SIM_DIR					=$(ROOT_DIR)/sim
SYN_DIR					=$(ROOT_DIR)/syn
SCRIPT_DIR			=$(ROOT_DIR)/script
REPORT_DIR			=$(ROOT_DIR)/report
SV_DIR          =$(ROOT_DIR)/conf/simvision_conf
NC_DIR          =$(ROOT_DIR)/conf/nWave_conf
TB_TOP   				=testfixture
TOP             =CONV

SRC=$(SRC_DIR)/$(TOP).v 				\
		$(SRC_DIR)/PE_1d.v 			  	\
		$(SRC_DIR)/convCtrl.v 			\
		$(SRC_DIR)/convDataPath.v   \
		$(SRC_DIR)/fakeMem.v 			  \
		$(SRC_DIR)/maxPool_2x2.v    \
		$(SRC_DIR)/def.v            

TB_SRC=$(SIM_DIR)/dat_grad/cnn_layer0_exp0.dat \
			 $(SIM_DIR)/dat_grad/cnn_layer0_exp1.dat \
			 $(SIM_DIR)/dat_grad/cnn_layer1_exp0.dat \
			 $(SIM_DIR)/dat_grad/cnn_layer1_exp1.dat \
			 $(SIM_DIR)/dat_grad/cnn_layer2_exp.dat  \
			 $(SIM_DIR)/dat_grad/cnn_sti.dat

.PHONY: init check rtl nw sv syn post clean gen_def

# Create folders
init: clean
	mkdir -p $(BUILD_DIR) $(SYN_DIR) $(REPORT_DIR)

# Generate header
gen_def:
	sh $(SRC_DIR)/gen_def.sh > $(SRC_DIR)/def.v

# Check HDL syntax
check:
	jg -superlint $(SCRIPT_DIR)/superlint.tcl &

# Run RTL simulation
rtl: gen_def
	cd $(BUILD_DIR); \
	cp $(TB_SRC) $(BUILD_DIR); \
	ncverilog  $(SIM_DIR)/$(TB_TOP).v $(SRC) \
	+incdir+$(SRC_DIR) \
	+nc64bit \
	+access+r \
	+define+SHM_FILE=\"$(TOP).shm\" \
	+define+FSDB_FILE=\"$(TOP).fsdb\"

# View waveform using nWave
nw:
	cp $(NC_DIR)/novas.rc $(BUILD_DIR); \
	cd $(BUILD_DIR); \
	nWave -f $(TOP).fsdb +access+r +nv64bit & 

# View waveform using simvision
sv:
	cd $(BUILD_DIR); \
	simvision -64bit -waves -input $(SV_DIR)/debug_base_config.sv &

# Run synthesize with Design Compiler
syn: $(BUILD)
	cd $(BUILD_DIR); \
	cp $(SCRIPT_DIR)/synopsys_dc.setup $(BUILD_DIR)/.synopsys_dc.setup; \
	nohup dc_shell -f $(SCRIPT_DIR)/synthesize.tcl &> $(ROOT_DIR)/nohup.log &

# Run gate-level simulation (nWave)
post: $(BUILD)
	cd $(BUILD_DIR); \
	cp $(SYN_DIR)/$(TOP)_syn.sdf $(BUILD_DIR); \
	ncverilog  $(SIM_DIR)/$(TB_TOP).v $(SYN_DIR)/$(TOP)_syn.v -v $(SIM_DIR)/tsmc13_neg.v \
	+nc64bit \
	+access+r \
	+define+SHM_FILE=\"$(TOP).shm\" \
	+define+FSDB_FILE=\"$(TOP).fsdb\" \
	+define+SDF \
	+define+SDFFILE=\"$(SYN_DIR)/$(TOP)_syn.sdf\" 

# Remove all files
clean:
	rm -rf $(BUILD_DIR) $(SYN_DIR) $(REPORT_DIR)
