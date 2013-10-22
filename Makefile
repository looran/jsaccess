PREFIX=/usr/local
BINDIR=$(PREFIX)/bin

all:
	@echo "Run \"sudo make install\" to install jstore"
	@echo "Run \"scp -r jsa user@webserver:/var/www/htdocs/\" to install jsa on your web server"

install:
	install -m 0755 jstore.sh $(BINDIR)/jstore
