PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
VERSION = 5.2.0
REVISION = 45
BIN_DIR = bin
BIN_TARGET = $(BIN_DIR)/eazy-linux-x86_64

.PHONY: install uninstall install-full compile-bin dist

install:
	install -Dm755 eazy $(DESTDIR)$(BINDIR)/eazy

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/eazy

install-full:
	./eazy --install

compile-bin:
	./tools/compilar-eazy.sh eazy $(BIN_TARGET)

dist:
	python3 tools/package-windows-demo.py dist/eazy-windows-demo-$(VERSION)-rev$(REVISION).zip
