LUAUNIT = /tmp/luaunit.lua
SETUP = -n -u NONE                                        \
	-c 'set rtp^=.'                                         \
	-c 'filetype on'                                        \
	-c 'luafile $(LUAUNIT)'                                 \
	-c "lua package.path = package.path..';'..'/tmp/?.lua'" \
	-c "source plugin/concertina.vim"

all: test lint

.PHONY: test
test: $(LUAUNIT)
	nvim $(SETUP) --headless -c 'luafile test/concerntina.lua' > /dev/null

.PHONY: lint
lint:
	luacheck lua/ test/

.PHONY: debug
debug:
	nvim $(SETUP) -c 'lua exec = require("test/helper").exec' -c 'lua lu = require("luaunit")'

$(LUAUNIT):
	curl -L https://raw.githubusercontent.com/bluebird75/luaunit/master/luaunit.lua -o $@
