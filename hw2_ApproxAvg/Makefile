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
	ncverilog  $(ROOTDIR)/$(SIM)/$(TOP).v $(ROOTDIR)/$(SRC)/CS.v \
	+incdir+$(ROOTDIR)/$(SRC) \
	+nc64bit \
	+access+r \
	+define+FSDB

syn0:$(BUILD)
	cd $(BUILD); \
	cp $(ROOTDIR)/$(SYNDIR)/CS_syn.sdf .;\
	ncverilog  $(ROOTDIR)/$(SIM)/$(TOP).v $(ROOTDIR)/$(SYNDIR)/CS_syn.v $(ROOTDIR)/$(SIM)/tsmc13_neg.v \
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
