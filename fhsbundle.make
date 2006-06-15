# FHS support (this is a hack and is going to be done by gstep-make!)

ifneq ($(FHS_INSTALL_ROOT),)

FHS_INCLUDE_DIR=$(FHS_INSTALL_ROOT)/include/
FHS_LIB_DIR=$(FHS_INSTALL_ROOT)/lib/
FHS_SOGOD_DIR=$(FHS_LIB_DIR)sogod-$(MAJOR_VERSION).$(MINOR_VERSION)/

#NONFHS_LIBDIR="$(GNUSTEP_LIBRARIES)/$(GNUSTEP_TARGET_LDIR)/"
#NONFHS_LIBNAME="$(LIBRARY_NAME)$(LIBRARY_NAME_SUFFIX)$(SHARED_LIBEXT)"
NONFHS_BINDIR="$(GNUSTEP_TOOLS)/$(GNUSTEP_TARGET_LDIR)"


fhs-sogod-dirs ::
	$(MKDIRS) $(FHS_SOGOD_DIR)

move-bundles-to-fhs :: fhs-sogod-dirs
	@echo "moving bundles $(BUNDLE_INSTALL_DIR) to $(FHS_SOGOD_DIR) .."
	for i in $(BUNDLE_NAME); do \
          j="$(FHS_SOGOD_DIR)/$${i}$(BUNDLE_EXTENSION)"; \
	  if test -d $$j; then rm -r $$j; fi; \
	  (cd $(BUNDLE_INSTALL_DIR); \
	    $(TAR) chf - --exclude=CVS --exclude=.svn --to-stdout \
            "$${i}$(BUNDLE_EXTENSION)") | \
          (cd $(FHS_SOGOD_DIR); $(TAR) xf -); \
	  rm -rf "$(BUNDLE_INSTALL_DIR)/$${i}$(BUNDLE_EXTENSION)";\
	done

#	  mv "$(BUNDLE_INSTALL_DIR)/$${i}$(BUNDLE_EXTENSION)" $$j; \

move-to-fhs :: move-bundles-to-fhs

after-install :: move-to-fhs

endif
