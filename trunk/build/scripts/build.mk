# build.mk

STARTTIME:=$(shell date +"%s")

all: clean fetch configure build dist

clean:
	sudo rm -rf $(SVN_PATH)

fetch:
	$(SVN) checkout $(SVN_FULL_URL) $(SVN_PATH)

configure:
ifeq ($(CONFIGURE), 1)
	if [ ! -f $(SVN_PATH)/Makefile ]; then \
		sh -c "cd $(SVN_PATH); ./configure $(CONFIGURE_FLAGS)"; \
	fi
endif

build:
ifeq ($(XCODEBUILD), 1)
	sh -c "cd $(SVN_PATH); xcodebuild -target \"$(XCODE_TARGET)\" -configuration \"$(XCODE_CONFIG)\""
else
	sh -c "cd $(SVN_PATH) && $(MAKE) $(MAKE_TARGETS)"
endif

dist:
ifeq ($(DISTRIBUTE), 1)
	find $(SVN_PATH) -name "$(TARBALL)" -exec scp -c blowfish "{}" $(DISTRIBUTE_URL)/$(DISTBALL) \;

	if [ "$(POST_DISTRIBUTE_SCRIPT)" ]; then \
		sh -c "$(POST_DISTRIBUTE_SCRIPT) $(PROJECT) $(DISTBALL) $(STARTTIME)"; \
	fi
endif
