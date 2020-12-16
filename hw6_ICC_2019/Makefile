ROOTDIR=$(PWD)
SRCDIR=src
SIMDIR=sim
BUILD=build
SYNDIR=syn
SCRIPTDIR=dc
REPORTDIR=report
TOP=testfixture

rtl:$(BUILD)
	cd $(BUILD); \
	cp $(ROOTDIR)/$(SIMDIR)/dat_grad/cnn_layer0_exp0.dat  $(ROOTDIR)/$(SIMDIR)/dat_grad/cnn_layer0_exp1.dat ./; \
 	cp $(ROOTDIR)/$(SIMDIR)/dat_grad/cnn_layer1_exp0.dat  $(ROOTDIR)/$(SIMDIR)/dat_grad/cnn_layer1_exp1.dat ./; \
	cp $(ROOTDIR)/$(SIMDIR)/dat_grad/cnn_layer2_exp.dat  $(ROOTDIR)/$(SIMDIR)/dat_grad/cnn_sti.dat  ./; \
	ncverilog  $(ROOTDIR)/$(SIMDIR)/$(TOP).v $(ROOTDIR)/$(SRCDIR)/CONV.v $(ROOTDIR)/$(SRCDIR)/PE_1d.v \
		$(ROOTDIR)/$(SRCDIR)/convCtrl.v $(ROOTDIR)/$(SRCDIR)/convDataPath.v $(ROOTDIR)/$(SRCDIR)/fakeMem.v \
		$(ROOTDIR)/$(SRCDIR)/maxPool_2x2.v \
	+incdir+$(ROOTDIR)/$(SRCDIR) \
	+nc64bit \
	+access+r \
	+define+FSDB

post:$(BUILD)
	cd $(BUILD); \
	cp $(ROOTDIR)/$(SYNDIR)/CONV_syn.sdf .;\
	ncverilog  $(ROOTDIR)/$(SIMDIR)/$(TOP).v $(ROOTDIR)/$(SYNDIR)/CONV_syn.v $(ROOTDIR)/$(SIMDIR)/tsmc13_neg.v \
	+nc64bit \
	+access+r \
	+define+FSDB \
	+define+SDF

syn: $(BUILD) $(SYNDIR) $(REPORTDIR)
	cd $(BUILD);\
	cp $(ROOTDIR)/$(SCRIPTDIR)/synopsys_dc.setup ./.synopsys_dc.setup;\
	dc_shell -f $(ROOTDIR)/$(SCRIPTDIR)/syn.tcl

wave:$(BUILD)
	cd $(BUILD);\
	nWave & 

clean:
	rm -rf $(BUILD)
