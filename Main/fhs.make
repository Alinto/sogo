# postprocessing

# FHS support (this is a hack and is going to be done by gstep-make!)

ifneq ($(FHS_INSTALL_ROOT),)

FHS_INCLUDE_DIR=$(FHS_INSTALL_ROOT)/include/
FHS_LIB_DIR=$(FHS_INSTALL_ROOT)/lib/
FHS_SBIN_DIR=$(FHS_INSTALL_ROOT)/sbin/

fhs-bin-dirs ::
	$(MKDIRS) $(FHS_SBIN_DIR)

NONFHS_BINDIR="$(GNUSTEP_TOOLS)/$(GNUSTEP_TARGET_LDIR)"

move-daemons-to-fhs :: fhs-bin-dirs
	@echo "moving daemons from $(NONFHS_BINDIR) to $(FHS_SBIN_DIR) .."
	for i in $(TOOL_NAME); do \
	  mv "$(NONFHS_BINDIR)/$${i}" $(FHS_SBIN_DIR); \
	done

move-to-fhs :: move-daemons-to-fhs

after-install :: move-to-fhs

endif
