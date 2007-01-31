# postprocessing

# FHS support (this is a hack and is going to be done by gstep-make!)

ifneq ($(FHS_INSTALL_ROOT),)

ifeq ($(findstring _64, $(GNUSTEP_TARGET_CPU)), _64)
FHS_LIB_DIR=$(FHS_INSTALL_ROOT)/lib64/
else
FHS_LIB_DIR=$(FHS_INSTALL_ROOT)/lib/
endif
FHS_SAX_DIR=$(FHS_LIB_DIR)sope-$(MAJOR_VERSION).$(MINOR_VERSION)/saxdrivers/

fhs-sax-dirs ::
	$(MKDIRS) $(FHS_SAX_DIR)

move-bundles-to-fhs :: fhs-sax-dirs
	@echo "moving bundles $(BUNDLE_INSTALL_DIR) to $(FHS_SAX_DIR) .."
	for i in $(BUNDLE_NAME); do \
          j="$(FHS_SAX_DIR)/$${i}$(BUNDLE_EXTENSION)"; \
	  if test -d $$j; then rm -r $$j; fi; \
	  mv "$(BUNDLE_INSTALL_DIR)/$${i}$(BUNDLE_EXTENSION)" $$j; \
	done

move-to-fhs :: move-bundles-to-fhs

after-install :: move-to-fhs

endif
