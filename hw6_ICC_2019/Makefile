ROOT_DIR				=$(PWD)
SRC_DIR					=$(ROOT_DIR)/src
SIM_DIR					=$(ROOT_DIR)/sim
SYN_DIR					=$(ROOT_DIR)/syn
SCRIPTDIR				=$(ROOT_DIR)/dc
REPORTDIR				=$(ROOT_DIR)/report
BUILD						=$(ROOT_DIR)/build
SV_DIR          =$(ROOT_DIR)/sv_conf
NC_DIR          =$(ROOT_DIR)/nc_conf
TOP							=testfixture

SRC=$(SRC_DIR)/CONV.v 					\
		$(SRC_DIR)/PE_1d.v 			  	\
		$(SRC_DIR)/convCtrl.v 			\
		$(SRC_DIR)/convDataPath.v   \
		$(SRC_DIR)/fakeMem.v 			  \
		$(SRC_DIR)/maxPool_2x2.v

TB_SRC=$(SIM_DIR)/dat_grad/cnn_layer0_exp0.dat \
			 $(SIM_DIR)/dat_grad/cnn_layer0_exp1.dat \
			 $(SIM_DIR)/dat_grad/cnn_layer1_exp0.dat \
			 $(SIM_DIR)/dat_grad/cnn_layer1_exp1.dat \
			 $(SIM_DIR)/dat_grad/cnn_layer2_exp.dat  \
			 $(SIM_DIR)/dat_grad/cnn_sti.dat

init:
	mkdir -p $(BUILD) $(SRC_DIR) $(SIM_DIR) $(SYN_DIR) $(SCRIPTDIR) $(REPORTDIR) $(SV_DIR)

check:
	jg -superlint dc/superlint.tcl &

rtl:
	cd $(BUILD); \
	cp $(TB_SRC) .; \
	ncverilog  $(SIM_DIR)/$(TOP).v $(SRC) \
	+incdir+$(SRC_DIR) \
	+nc64bit \
	+access+r \
	+define+FSDB

post: $(BUILD)
	cd $(BUILD); \
	cp $(SYN_DIR)/CONV_syn.sdf .; \
	ncverilog  $(SIM_DIR)/$(TOP).v $(SYN_DIR)/CONV_syn.v $(SIM_DIR)/tsmc13_neg.v \
	+nc64bit \
	+access+r \
	+define+FSDB \
	+define+SDF

syn: $(BUILD) $(SYN_DIR) $(REPORTDIR)
	cd $(BUILD); \
	cp $(SCRIPTDIR)/synopsys_dc.setup ./.synopsys_dc.setup; \
	dc_shell -f $(SCRIPTDIR)/syn.tcl

nw:
	cp $(NC_DIR)/novas.rc $(BUILD); \
	cd $(BUILD); \
	nWave -f CONV.fsdb +access+r +nv64bit & 

sv:
	cd $(BUILD); \
	simvision -64bit -waves -input $(SV_DIR)/sv_cf.sv &

clean:
	rm -rf $(BUILD)/*
