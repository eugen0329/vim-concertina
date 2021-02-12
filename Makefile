SETUP = -n -u NONE                                             \
	-c 'set rtp^=.'                                              \
	-c 'filetype on'                                             \
	-c 'luafile luaunit.lua'                                     \
	-c "lua package.path = package.path .. ';' .. './lua/?.lua'" \
	-c "source plugin/concertina.vim"

.PHONY: test
test: luaunit.lua
	nvim --headless $(SETUP)  -c 'luafile test/concerntina.lua'  > /dev/null

.PHONY: debug
debug:
	nvim $(SETUP) -c 'lua exec = require("test/helper").exec' -c 'lua lu = require("luaunit")'

.PHONY: lint
lint:
	luacheck lua/ test/

luaunit.lua:
	curl -LO https://raw.githubusercontent.com/bluebird75/luaunit/master/luaunit.lua
