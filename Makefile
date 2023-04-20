.SECONDARY:
.PRECIOUS:

.SECONDEXPANSION:
.ONESHELL:
SHELL = /usr/bin/qsh
.SHELLFLAGS = -ec

LIBRARY				 ?= SKINVDEMO
TGTRLS         ?= *current
DEBUG					 ?= 1

ifneq (,$(BUILDLIB))
LIBRARY=$(BUILDLIB)
endif

# Make sure LIBRARY has been set and doesn't have any blanks
ifneq (1,$(words [$(LIBRARY)]))
$(error LIBRARY variable is not set correctly. Set to a valid library name and try again)
endif
ifeq (,$(LIBRARY))
$(error LIBRARY variable is not set correctly. Set to a valid library name and try again)
endif

ILIBRARY      := /qsys.lib/$(LIBRARY).lib
RPGINCDIR     := 'src/rpglesrc'
RPGINCDIR     := incdir($(RPGINCDIR))
BNDDIR        :=
CL_OPTS       :=
RPG_OPTS      := option(*noseclvl)
PGM_OPTS      :=
SQL_OPTS			:= commit(*none) option(*sys)
OWNER         := qpgmr
USRPRF        := *user
BNDSRVPGM			:=
PGM_ACTGRP		:= INVOICE
SRVPGM_ACTGRP := *caller

SETLIBLIST    := liblist | grep ' USR' | while read lib type; do liblist -d $$lib; done; liblist -a $(LIBRARY)
TMPSRC        := tmpsrc
ISRCFILE      := $(ILIBRARY)/$(TMPSRC).file
SRCFILE       := srcfile($(LIBRARY)/$(TMPSRC)) srcmbr($(TMPSRC))
SRCFILE2      := $(LIBRARY)/$(TMPSRC)($(TMPSRC))
SRCFILE3      := file($(LIBRARY)/$(TMPSRC)) mbr($(TMPSRC))
PRDLIB        := $(LIBRARY)
TGTCCSID      := *job
DEVELOPER     ?= $(USER)
MAKE          := make
LOGFILE       = $(CURDIR)/tmp/$(@F).txt
OUTPUT        = >$(LOGFILE) 2>&1

# Remove compile listings from previous `make`
$(shell test -d $(CURDIR)/tmp || mkdir $(CURDIR)/tmp; rm $(CURDIR)/tmp/*.txt >/dev/null 2>&1)

#
# Set variables for adding in a debugging view if desired
#

ifeq ($(DEBUG), 1)
	DEBUG_OPTS     := dbgview(*list)
	SQL_DEBUG_OPTS := dbgview(*list)
	CPP_OPTS       := $(CPP_OPTS) output(*print)
else
	DEBUG_OPTS     := dbgview(*none)
	SQL_DEBUG_OPTS := dbgview(*none)
	CPP_OPTS       := $(CPP_OPTS) optimize(40) output(*none)
	RPG_OPTS       := $(RPG_OPTS) optimize(*full)
endif

define MSGF_OBJS
	INVMSGF.msgf 
endef
define DSPF_OBJS
	ITMINQD.file INVENTD.file INVINQD.file INVINQ2D.file
endef
define PRTF_OBJS
	INVOICE.ovl INVOICE.file
endef	
define PGM_OBJS
	ITMINQR.pgm INVENTR.pgm INVINQR.pgm 
	INVOICE.srvpgm INVENT2R.pgm INVINQ2R.pgm INVDNLR.pgm
endef	
define TABLE_OBJS
	CTRLDTA.file CUSTMAS.file INVDET.file INVHDR.file ITEMMAS.file UNITS.file
endef
define BNDDIR_OBJS
	INVOICE.bnddir QHTTPSVR.bnddir
endef	

MSGF_OBJS 	:= $(addprefix $(ILIBRARY)/, $(MSGF_OBJS))
TABLE_OBJS 	:= $(addprefix $(ILIBRARY)/, $(TABLE_OBJS))
DSPF_OBJS 	:= $(addprefix $(ILIBRARY)/, $(DSPF_OBJS))
PRTF_OBJS		:= $(addprefix $(ILIBRARY)/, $(PRTF_OBJS))
BNDDIR_OBJS	:= $(addprefix $(ILIBRARY)/, $(BNDDIR_OBJS))
PGM_OBJS 		:= $(addprefix $(ILIBRARY)/, $(PGM_OBJS))

define SRCF_OBJS
	QDDSSRC.file QRPGLESRC.file QSQLSRC.file QSRVSRC.file
endef
SRCF_OBJS := $(addprefix $(ILIBRARY)/, $(SRCF_OBJS))

TARGETS := $(MSGF_OBJS) $(BNDDIR_OBJS) $(TABLE_OBJS) $(DSPF_OBJS) $(PRTF_OBJS)

INVINQ2R.pgm_deps			:= $(addprefix $(ILIBRARY)/, INVOICE.srvpgm INVINQ2D.file)
INVENT2R.pgm_deps			:= $(addprefix $(ILIBRARY)/, INVOICE.srvpgm INVENTD.file ITMINQR.pgm)
INVDNLR.pgm_deps			:= $(addprefix $(ILIBRARY)/, INVOICE.srvpgm)
INVOICE.module_deps   := $(MSGF_OBJS) $(PRTF_OBJS)
INVOICE.srvpgm_deps   := $(addprefix $(ILIBRARY)/, INVOICE.module)
INVENTR.pgm_deps   		:= $(addprefix $(ILIBRARY)/, INVENTD.file ITMINQR.pgm)
INVINQR.pgm_deps   		:= $(addprefix $(ILIBRARY)/, INVINQD.file)
ITMINQR.pgm_deps			:= $(addprefix $(ILIBRARY)/, ITMINQD.file)

.PHONY: all clean srcpf

all: $(MSGF_OBJS) $(TABLE_OBJS) $(DSPF_OBJS) $(PRTF_OBJS) $(BNDDIR_OBJS) $(PGM_OBJS) |$(ILIBRARY) 

srcpf: $(SRCF_OBJS) | $(ILIBRARY)

clean:
	rm -f $(PGM_OBJS) $(BNDDIR_OBJS) $(MSGF_OBJS) $(ILIBRARY)/*.MODULE
	rm -rf $(ISRCFILE) $(SRCF_OBJS) 
	rm -rf $(PRTF_OBJS) $(DSPF_OBJS)
	system "dltf file($(LIBRARY)/CTRLDTA)" || true
	system "dltf file($(LIBRARY)/CUSTMAS)" || true
	system "dltf file($(LIBRARY)/INVDET)" || true
	system "dltf file($(LIBRARY)/INVHDR)" || true
	system "dltf file($(LIBRARY)/ITEMMAS)" || true
	system "dltf file($(LIBRARY)/UNITS)" || true
	system "dltf file($(LIBRARY)/OVERLAY)" || true
	rm -rf tmp

$(ILIBRARY): | tmp
	-system -v 'crtlib lib($(LIBRARY)) type(*PROD)'
	system -v "chgobjown obj($(LIBRARY)) objtype(*lib) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)) objtype(*lib) user(*public) aut(*use) replace(*yes)"

$(ISRCFILE): | $(ILIBRARY)
	-system -v 'crtsrcpf rcdlen(250) $(SRCFILE3)'

tmp:
	mkdir $(CURDIR)/tmp	

#
#  Specific rules for objects that don't follow the "cookbook" rules, below.
#

$(ILIBRARY)/QHTTPSVR.bnddir: | $(ILIBRARY)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(rm -rf '$(@)'
	system -v "crtbnddir bnddir($(LIBRARY)/$(basename $(@F)))"
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)"
	system -v "addbnddire bnddir($(LIBRARY)/$(basename $(@F))) obj((qhttpsvr/qzhbcgi *srvpgm))") $(OUTPUT)

$(ILIBRARY)/INVOICE.bnddir: | $(ILIBRARY)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(rm -rf '$(@)'
	system -v "crtbnddir bnddir($(LIBRARY)/$(basename $(@F)))"
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)"
	system -v "addbnddire bnddir($(LIBRARY)/$(basename $(@F))) obj((*libl/invoice *srvpgm))") $(OUTPUT)

$(ILIBRARY)/QRPGLESRC.file: | $(ILIBRARY)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(rm -f '$(@)'
	system -v 'crtsrcpf file($(LIBRARY)/$(basename $(@F))) rcdlen(112)'
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)"
	for MBR in INVOICE_H; do
	  system -v "addpfm file($(LIBRARY)/$(basename $(@F))) mbr($${MBR}) srctype(rpgle)"; \
	  cat "src/rpglesrc/$${MBR}.rpgleinc" | Rfile -wQ "$(LIBRARY)/$(basename $(@F))($${MBR})"; \
	done
	for MBR in INVDNLR INVENTR INVENT2R INVINQ INVINQ2R ITMINQR; do
	  system -v "addpfm file($(LIBRARY)/$(basename $(@F))) mbr($${MBR}) srctype(rpgle)"; \
	  cat "src/rpglesrc/$${MBR}.rpgle" | Rfile -wQ "$(LIBRARY)/$(basename $(@F))($${MBR})"; \
	done
	for MBR in INVOICE; do
	  system -v "addpfm file($(LIBRARY)/$(basename $(@F))) mbr($${MBR}) srctype(sqlrpgle)"; \
	  cat "src/rpglesrc/$${MBR}.sqlrpgle" | Rfile -wQ "$(LIBRARY)/$(basename $(@F))($${MBR})"; \
	done) $(OUTPUT)

$(ILIBRARY)/QDDSSRC.file: | $(ILIBRARY)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(rm -f '$(@)'
	system -v 'crtsrcpf file($(LIBRARY)/$(basename $(@F))) rcdlen(92)'
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)"
	for MBR in INVENTD INVINQD INVINQ2D ITMINQD; do
	  system -v "addpfm file($(LIBRARY)/$(basename $(@F))) mbr($${MBR}) srctype(dspf)"; \
	  cat "src/ddssrc/$${MBR}.dspf" | Rfile -wQ "$(LIBRARY)/$(basename $(@F))($${MBR})"; \
	done
	for MBR in INVOICE; do
	  system -v "addpfm file($(LIBRARY)/$(basename $(@F))) mbr($${MBR}) srctype(prtf)"; \
	  cat "src/ddssrc/$${MBR}.prtf" | Rfile -wQ "$(LIBRARY)/$(basename $(@F))($${MBR})"; \
	done) $(OUTPUT)
	
$(ILIBRARY)/QSRVSRC.file: | $(ILIBRARY)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(rm -f '$(@)'
	system -v 'crtsrcpf file($(LIBRARY)/$(basename $(@F))) rcdlen(92)'
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)"
	for MBR in INVOICE; do
	  system -v "addpfm file($(LIBRARY)/$(basename $(@F))) mbr($${MBR}) srctype(bnd)"; \
	  cat "src/srvsrc/$${MBR}.bnd" | Rfile -wQ "$(LIBRARY)/$(basename $(@F))($${MBR})"; \
	done) $(OUTPUT)
	
$(ILIBRARY)/QSQLSRC.file: | $(ILIBRARY)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(rm -f '$(@)'
	system -v 'crtsrcpf file($(LIBRARY)/$(basename $(@F))) rcdlen(92)'
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)"
	for MBR in CTRLDTA CUSTMAS INVDET INVHDR ITEMMAS UNITS; do
	  system -v "addpfm file($(LIBRARY)/$(basename $(@F))) mbr($${MBR}) srctype(sql)"; \
	  cat "src/sqlsrc/$${MBR}.table" | Rfile -wQ "$(LIBRARY)/$(basename $(@F))($${MBR})"; \
	done) $(OUTPUT)

$(ILIBRARY)/INVMSGF.msgf: | tmp $$($$*.msgf_deps) $(ILIBRARY)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(rm -rf '$(@)'
	$(SETLIBLIST)
	system -v "crtmsgf msgf($(LIBRARY)/INVMSGF) text('Invoice demo message file')"
	system -v "addmsgd msgid(inv1001) msgf($(LIBRARY)/INVMSGF) msg('Customer &1 not found!') seclvl('SQL State &2 occurred retrieving customer &1 from the CUSTMAS table.') sev(10) fmt((*DEC 4 0) (*CHAR 5))"
	system -v "addmsgd msgid(inv1002) msgf($(LIBRARY)/INVMSGF) msg('Invoice &1 not found!') seclvl('SQL State &3 occurred retrieving invoice &1 with create date &2 from the INVHDR table.') sev(10) fmt((*DEC 7 0) (*DEC 8 0) (*CHAR 5))"
	system -v "addmsgd msgid(inv1003) msgf($(LIBRARY)/INVMSGF) msg('SQL State &1 opening invoice list.') seclvl('SQL State &1 occurred when opening a filtered invoice list. See previous messages in job log for more information.') sev(30) fmt((*CHAR 5))"
	system -v "addmsgd msgid(inv1004) msgf($(LIBRARY)/INVMSGF) msg('SQL State &1 retreiving an invoice.') seclvl('SQL State &1 occurred when retrieving an invoice from a filtered invoice list.') sev(30) fmt((*CHAR 5))"
	system -v "addmsgd msgid(inv1005) msgf($(LIBRARY)/INVMSGF) msg('Incorrect state to save invoice.') seclvl('It is not possible to save an invoice to disk until after you''ve loaded/created one and added items to it.') sev(30)"
	system -v "addmsgd msgid(inv1006) msgf($(LIBRARY)/INVMSGF) msg('SQL State &1 replacing previous detail rows.') seclvl('Attempting to do a DELETE against the previous detail rows, received state &1. See previous messages in job log.') sev(30) fmt((*CHAR 5))"
	system -v "addmsgd msgid(inv1007) msgf($(LIBRARY)/INVMSGF) msg('Unable to save details for invoice &1.') seclvl('Invoice &1 create date &2 received SQL state &4 attempting to insert &3 rows.') sev(30) fmt((*DEC 7 0) (*DEC 8 0) (*BIN 4) (*CHAR 5))"
	system -v "addmsgd msgid(inv1008) msgf($(LIBRARY)/INVMSGF) msg('Unable to save header for invoice &1.') seclvl('Invoice &1 create date &2 received SQL state &3 attempting to update/insert the header.') sev(30) fmt((*DEC 7 0) (*DEC 8 0) (*CHAR 5))"
	system -v "addmsgd msgid(inv1009) msgf($(LIBRARY)/INVMSGF) msg('Unable to mark invoice &1 paid.') seclvl('Invoice &1 create date &2 received SQL state &3 attempting to mark it paid. See previous messages in job log.') sev(30) fmt((*DEC 7 0) (*DEC 8 0) (*CHAR 5))"
	system -v "addmsgd msgid(inv1010) msgf($(LIBRARY)/INVMSGF) msg('Unable to update customer last paid date.') seclvl('Invoice &1 create date &2 received SQL state &4 attempting to update customer last paid date to &3. See previous messages in job log.') sev(30) fmt((*DEC 7 0) (*DEC 8 0) (*DEC 8 0) (*CHAR 5))"
	system -v "addmsgd msgid(inv1011) msgf($(LIBRARY)/INVMSGF) msg('Unable to delete invoice &1.') seclvl('Invoice &1 create date &2 received SQL state &3 attempting to delete its rows.') sev(30) fmt((*DEC 7 0) (*DEC 8 0) (*CHAR 5))"
	system -v "addmsgd msgid(inv1012) msgf($(LIBRARY)/INVMSGF) msg('Item &1 not found.') seclvl('Unable to find item number &1 in the ITEMMAS table.') sev(10) fmt((*DEC 5 0))"
	system -v "addmsgd msgid(inv1013) msgf($(LIBRARY)/INVMSGF) msg('SQL State &2 attempting to read item &1.') seclvl('Attempting to read item &1 from the ITEMMAS table, received SQL State &2. See previous messages in job log.') sev(30) fmt((*DEC 5 0) (*CHAR 5))"
	system -v "addmsgd msgid(inv1014) msgf($(LIBRARY)/INVMSGF) msg('Price &2 not valid for item &1.') seclvl('Item &1 does not allow a price of &2. Check the MINPRC and MAXPRC columns in the ITEMMAS table.') sev(10) fmt((*DEC 5 0) (*DEC 9 3))"
	system -v "addmsgd msgid(inv1015) msgf($(LIBRARY)/INVMSGF) msg('SQL state &3 looking up price &2 for item &1.') seclvl('Received SQL state &3 while attempting to check a price of &2 for item number &1 in the ITEMMAS table. See previous messages in job log.') sev(30) fmt((*DEC 5 0) (*DEC 9 3) (*CHAR 5))"
	system -v "addmsgd msgid(inv1016) msgf($(LIBRARY)/INVMSGF) msg('Line number &1 exceeds the capacity of an invoice.') seclvl('There can be a maximum of &2 line items on an invoice. You attempted to add line &1, which exceeds that maximum.') sev(40) fmt((*BIN 4) (*BIN 4))"
	system -v "addmsgd msgid(inv1017) msgf($(LIBRARY)/INVMSGF) msg('Unit of measure &1 is not known.') seclvl('The unit of measure &1 does not exist in the UNITS table.') sev(10) fmt((*CHAR 1))"
	system -v "addmsgd msgid(inv1018) msgf($(LIBRARY)/INVMSGF) msg('SQL State &2 occurred retrieving UOM &1 from UNITS.') seclvl('When trying to read UOM code &1 from the UNITS table, received SQL state &2. See previous messages in job log.') sev(30) fmt((*CHAR 1) (*CHAR 5))"
	system -v "addmsgd msgid(inv1019) msgf($(LIBRARY)/INVMSGF) msg('Terms code &1 is unknown.') seclvl(*NONE) sev(30) fmt((*CHAR 1))") $(OUTPUT)

#
#  Standard "cookbook" recipes for building objects
#
$(ILIBRARY)/%.module: src/clsrc/%.clle | $(ISRCFILE) $$($$*.module_files) $$($$*.module_spgms)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	($(SETLIBLIST)
	cat '$(<)' | Rfile -wQ '$(SRCFILE2)'
	system -v "crtclmod module($(LIBRARY)/$(*F)) $(SRCFILE) $(CL_OPTS) tgtrls($(TGTRLS)) $(DEBUG_OPTS)") $(OUTPUT)
	
$(ILIBRARY)/%.module: src/rpglesrc/%.rpgle $$($$*.module_deps) | $(ISRCFILE)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	($(SETLIBLIST)
	cat '$(<)' | Rfile -wQ '$(SRCFILE2)'
	system -v "crtrpgmod module($(LIBRARY)/$(*F)) $(SRCFILE) $(RPGINCDIR) $(RPG_OPTS) tgtrls($(TGTRLS)) $(DEBUG_OPTS)") $(OUTPUT)
	
$(ILIBRARY)/%.module: src/rpglesrc/%.sqlrpgle $$($$*.module_deps) | $(ISRCFILE)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	($(SETLIBLIST)
	cat '$(<)' | Rfile -wQ '$(SRCFILE2)'
	system -v "crtsqlrpgi obj($(LIBRARY)/$(*F)) $(SRCFILE) compileopt('$(subst ','',$(RPGINCDIR)) $(subst ','',$(RPG_OPTS))') $(SQL_OPTS) tgtrls($(TGTRLS)) $(SQL_DEBUG_OPTS) objtype(*module) rpgppopt(*lvl2)") $(OUTPUT)
	
$(ILIBRARY)/%.pnlgrp: src/pnlsrc/%.pnlgrp | $$($$*.pnlgrp_deps) $(ISRCFILE)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	($(SETLIBLIST)
	cat '$(<)' | Rfile -wQ '$(SRCFILE2)'
	system -v "crtpnlgrp pnlgrp($(LIBRARY)/$(*F)) $(SRCFILE)"
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)") $(OUTPUT)

$(ILIBRARY)/%.cmd: src/cmdsrc/%.cmd $$($$*.cmd_deps) | $(ISRCFILE)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	($(SETLIBLIST)
	cat '$(<)' | Rfile -wQ '$(SRCFILE2)'
	system -v 'crtcmd cmd($(LIBRARY)/$(*F)) $(SRCFILE) pgm(*libl/$(*F)) prdlib($(PRDLIB))'
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)") $(OUTPUT)

$(ILIBRARY)/%.pgm: $$($$*.pgm_deps) $(ILIBRARY)/%.module | $(ILIBRARY)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	($(SETLIBLIST)
	system -v 'dltpgm pgm($(LIBRARY)/$(*F))' || true
	system -v 'crtpgm pgm($(LIBRARY)/$(*F)) module($(foreach MODULE, $(notdir $(filter %.module, $(^))), ($(LIBRARY)/$(basename $(MODULE))))) entmod(*pgm) $(PGM_OPTS) actgrp($(PGM_ACTGRP)) tgtrls($(TGTRLS)) bndsrvpgm($(foreach SRVPGM, $(notdir $(filter %.srvpgm, $(|))), ($(basename $(SRVPGM))))) $(BNDDIR) $($(@F)_opts) usrprf($(USRPRF))'
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)") $(OUTPUT)
			
$(ILIBRARY)/%.srvpgm: src/srvsrc/%.bnd $$($$*.srvpgm_deps) | $(ISRCFILE)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(rm -rf '$(@)'
	cat '$(<)' | Rfile -wQ '$(SRCFILE2)'
	$(SETLIBLIST)
	system -v 'dltsrvpgm srvpgm($(LIBRARY)/$(*F))' || true
	system -v 'crtsrvpgm srvpgm($(LIBRARY)/$(*F)) module($(foreach MODULE, $(notdir $(filter %.module, $(^))), ($(LIBRARY)/$(basename $(MODULE))))) $(SRCFILE) $(PGM_OPTS) actgrp($(SRVPGM_ACTGRP)) tgtrls($(TGTRLS)) bndsrvpgm($(foreach SRVPGM, $(notdir $(filter %.srvpgm, $(^))), ($(basename $(SRVPGM))))) $($(@F)_opts) $(BNDDIR) usrprf($(USRPRF))'
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)") $(OUTPUT)

$(ILIBRARY)/%.file: src/ddssrc/%.dspf | $$($$*.file_deps) $(ISRCFILE)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(rm -rf '$(@)'
	cat '$(<)' | Rfile -wQ '$(SRCFILE2)'
	$(SETLIBLIST)
	system -v 'crtdspf file($(LIBRARY)/$(*F)) $(SRCFILE)'
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)") $(OUTPUT)

$(ILIBRARY)/%.file: src/ddssrc/%.prtf | $$($$*.file_deps) $(ISRCFILE)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(rm -rf '$(@)'
	cat '$(<)' | Rfile -wQ '$(SRCFILE2)'
	$(SETLIBLIST)
	system -v 'crtprtf file($(LIBRARY)/$(*F)) $(SRCFILE)'
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)") $(OUTPUT)

$(ILIBRARY)/%.file: src/sqlsrc/%.table | $$($$*.file_deps) $(ISRCFILE)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(cat '$(<)' | Rfile -wQ '$(SRCFILE2)'
	$(SETLIBLIST)
	system -v 'runsqlstm $(SRCFILE) commit(*none) naming(*sys) dftrdbcol($(LIBRARY)) $(SQL_DEBUG_OPTS) tgtrls($(TGTRLS))'
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)") $(OUTPUT)

$(ILIBRARY)/%.ovl: src/overlay/%.ovl | $$($$*.ovl_deps)
	@$(info Creating $(@))touch -C 1208 $(LOGFILE)
	(rm -rf '$(@)' $(ILIBRARY)/OVERLAY.file
	$(SETLIBLIST)
	system -v "crtpf file($(LIBRARY)/OVERLAY) rcdlen(32766) lvlchk(*no) mbr(*none) maxmbrs(*nomax)"
	system -v "cpyfrmstmf fromstmf('$(<)') tombr('$(ILIBRARY)/OVERLAY.file/INVOICE.mbr') mbropt(*add) cvtdta(*none) endlinfmt(*fixed) tabexpn(*no)"
	system -v "crtovl ovl($(LIBRARY)/$(basename $(@F))) file($(LIBRARY)/OVERLAY) mbr(INVOICE) datatype(*afpds)"
	system -v "chgobjown obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) newown($(OWNER)) curownaut(*revoke)"
	system -v "grtobjaut obj($(LIBRARY)/$(basename $(@F))) objtype(*$(subst .,,$(suffix $(@F)))) user(*public) aut(*use) replace(*yes)"
	system -v "dltf file($(LIBRARY)/OVERLAY)") $(OUTPUT)
