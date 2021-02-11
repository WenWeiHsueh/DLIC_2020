ROOTDIR=$(PWD)
SRCDIR=src
SIMDIR=sim
BUILD=build
SYNDIR=syn
SCRIPTDIR=dc
REPORTDIR=report
TOP=conv_tb

rtl:$(BUILD)
	cd $(BUILD); \
	cp $(ROOTDIR)/$(SIMDIR)/golden.hex $(ROOTDIR)/$(SIMDIR)/input.hex ./;\
	ncverilog  $(ROOTDIR)/$(SIMDIR)/$(TOP).v $(ROOTDIR)/$(SRCDIR)/conv.v $(ROOTDIR)/$(SRCDIR)/bram_sim.v \
	+incdir+$(ROOTDIR)/$(SRCDIR) \
	+nc64bit \
	+access+r \
	+define+FSDB

post:$(BUILD)
	cd $(BUILD); \
	cp $(ROOTDIR)/$(SIMDIR)/golden.hex $(ROOTDIR)/$(SIMDIR)/input.hex ./;\
	cp $(ROOTDIR)/$(SYNDIR)/conv_syn.sdf .;\
	ncverilog  $(ROOTDIR)/$(SIMDIR)/$(TOP).v $(ROOTDIR)/$(SYNDIR)/conv_syn.v $(ROOTDIR)/$(SRCDIR)/bram_sim.v -v $(ROOTDIR)/$(SIMDIR)/tsmc13_neg.v \
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
