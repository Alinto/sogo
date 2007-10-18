# postprocessing

# FHS support (this is a hack and is going to be done by gstep-make!)

# NOTE: you need to define FHS_HEADER_FILES_INSTALL_DIR for one library

ifneq ($(FHS_INSTALL_ROOT),)

FHS_INCLUDE_DIR=$(FHS_INSTALL_ROOT)/include/
FHS_BIN_DIR=$(FHS_INSTALL_ROOT)/bin
FHS_LIB_DIR=$(CONFIGURE_FHS_INSTALL_LIBDIR)

NONFHS_LIBDIR="$(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR)/"
NONFHS_LIBNAME="$(LIBRARY_NAME)$(LIBRARY_NAME_SUFFIX)$(SHARED_LIBEXT)"
NONFHS_BINDIR="$(GNUSTEP_TOOLS)/$(GNUSTEP_TARGET_LDIR)"


fhs-header-dirs ::
	$(MKDIRS) $(FHS_INCLUDE_DIR)$(FHS_HEADER_FILES_INSTALL_DIR)

fhs-bin-dirs ::
	$(MKDIRS) $(FHS_BIN_DIR)


move-headers-to-fhs :: fhs-header-dirs
	@echo "moving headers to $(FHS_INCLUDE_DIR) .."
	mv $(GNUSTEP_HEADERS)$(FHS_HEADER_FILES_INSTALL_DIR)/*.h \
	  $(FHS_INCLUDE_DIR)$(FHS_HEADER_FILES_INSTALL_DIR)/

move-libs-to-fhs :: 
	@echo "moving libs to $(FHS_LIB_DIR) .."
	mv $(NONFHS_LIBDIR)/$(NONFHS_LIBNAME)* $(FHS_LIB_DIR)/

move-tools-to-fhs :: fhs-bin-dirs
	@echo "moving tools from $(NONFHS_BINDIR) to $(FHS_BIN_DIR) .."
	for i in $(TOOL_NAME); do \
	  mv "$(NONFHS_BINDIR)/$${i}" $(FHS_BIN_DIR); \
	done

move-to-fhs :: move-headers-to-fhs move-libs-to-fhs move-tools-to-fhs

after-install :: move-to-fhs

endif
