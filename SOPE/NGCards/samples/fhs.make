# postprocessing

# FHS support (this is a hack and is going to be done by gstep-make!)

ifneq ($(FHS_INSTALL_ROOT),)

FHS_INCLUDE_DIR=$(FHS_INSTALL_ROOT)/include/
FHS_LIB_DIR=$(FHS_INSTALL_ROOT)/lib/
FHS_BIN_DIR=$(FHS_INSTALL_ROOT)/bin/

fhs-bin-dirs ::
	$(MKDIRS) $(FHS_BIN_DIR)

NONFHS_BINDIR="$(GNUSTEP_TOOLS)/$(GNUSTEP_TARGET_LDIR)"

move-tools-to-fhs :: fhs-bin-dirs
	@echo "moving tools from $(NONFHS_BINDIR) to $(FHS_BIN_DIR) .."
	for i in $(TOOL_NAME); do \
	  mv "$(NONFHS_BINDIR)/$${i}" $(FHS_BIN_DIR); \
	done

move-to-fhs :: move-tools-to-fhs

after-install :: move-to-fhs

endif
