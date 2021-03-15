ROOT_DIR					=$(PWD)
BUILD						  =build
BUILD_DIR				  =$(ROOT_DIR)/$(BUILD)
SRC_DIR					  =$(ROOT_DIR)/src
SIM_DIR					  =$(ROOT_DIR)/sim
SYN_DIR					  =$(ROOT_DIR)/syn
SCRIPT_DIR				=$(ROOT_DIR)/script
REPORT_DIR				=$(ROOT_DIR)/report
SV_DIR						=$(ROOT_DIR)/conf/simvision_conf
NC_DIR						=$(ROOT_DIR)/conf/nWave_conf

TB_TOP						=testfixture
TOP							 =CONV

SRC=$(shell ls $(SRC_DIR)/*.v)

TB_SRC=$(shell ls $(SIM_DIR)/dat_grad/*.dat)

.PHONY: init check rtl nw sv syn post clean gen_def

$(BUILD): 
	mkdir -p $(BUILD)

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
rtl: $(BUILD) gen_def
	cd $(BUILD_DIR); \
	cp $(TB_SRC) .; \
	ncverilog  $(SIM_DIR)/$(TB_TOP).v $(SRC) \
	+incdir+$(SRC_DIR) \
	+nc64bit \
	+access+r \
	+define+SHM_FILE=\"$(TOP).shm\" \
	+define+FSDB_FILE=\"$(TOP).fsdb\"

# View waveform using nWave
nw: $(BUILD)
	cp $(NC_DIR)/signal.rc $(BUILD_DIR); \
	cd $(BUILD_DIR); \
	nWave -f $(TOP).fsdb -sswr $(NC_DIR)/signal.rc +access+r +nc64bit &

# View waveform using simvision
sv: $(BUILD)
	cd $(BUILD_DIR); \
	simvision -64bit -waves -input $(SV_DIR)/signal.sv &

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
	rm -rf $(BUILD_DIR) $(SYN_DIR) $(REPORT_DIR) *.log
