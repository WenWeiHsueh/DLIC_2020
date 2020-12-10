ROOTDIR=$(PWD)
SRC=src
SIM=sim
BUILD=build
SYNDIR=syn
SCRIPTDIR=dc
REPORTDIR=report
TOP=testfixture

$(BUILD):
	mkdir -p $(BUILD)

$(SYNDIR):
	mkdir -p $(SYNDIR)
$(REPORTDIR):
	mkdir -p $(REPORTDIR)

rtl:$(BUILD)
	cd $(BUILD); \
	cp $(ROOTDIR)/$(SIM)/dat_grad/cnn_layer0_exp0.dat  $(ROOTDIR)/$(SIM)/dat_grad/cnn_layer0_exp1.dat ./; \
 	cp $(ROOTDIR)/$(SIM)/dat_grad/cnn_layer1_exp0.dat  $(ROOTDIR)/$(SIM)/dat_grad/cnn_layer1_exp1.dat ./; \
	cp $(ROOTDIR)/$(SIM)/dat_grad/cnn_layer2_exp.dat  $(ROOTDIR)/$(SIM)/dat_grad/cnn_sti.dat  ./; \
	ncverilog  $(ROOTDIR)/$(SIM)/$(TOP).v $(ROOTDIR)/$(SRC)/CONV.v $(ROOTDIR)/$(SRC)/PE_1d.v \
		$(ROOTDIR)/$(SRC)/convCtrl.v $(ROOTDIR)/$(SRC)/convDataPath.v $(ROOTDIR)/$(SRC)/fakeMem.v \
		$(ROOTDIR)/$(SRC)/maxPool_2x2.v \
	+incdir+$(ROOTDIR)/$(SRC) \
	+nc64bit \
	+access+r \
	+define+FSDB

syn0:$(BUILD)
	cd $(BUILD); \
	cp $(ROOTDIR)/$(SYNDIR)/CONV_syn.sdf .;\
	ncverilog  $(ROOTDIR)/$(SIM)/$(TOP).v $(ROOTDIR)/$(SYNDIR)/CONV_syn.v $(ROOTDIR)/$(SIM)/tsmc13_neg.v \
	+nc64bit \
	+access+r \
	+define+FSDB \
	+define+SDF

synthesize: $(BUILD) $(SYNDIR) $(REPORTDIR)
	cd $(BUILD);\
	cp $(ROOTDIR)/$(SCRIPTDIR)/synopsys_dc.setup ./.synopsys_dc.setup;\
	dc_shell -f $(ROOTDIR)/$(SCRIPTDIR)/synthesis.tcl

nWave:$(BUILD)
	cd $(BUILD);\
	nWave & 

clean:
	rm -rf $(BUILD)
