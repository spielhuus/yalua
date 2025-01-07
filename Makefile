LUAROCKS=luarocks
LUACHECK=luacheck
LUA_TREE=.luarocks
LUA_FILES = $(wildcard *.lua) 
SPEC_FILES = $(wildcard ./spec/*.lua)
LUA_PATH=$(shell luarocks --lua-version 5.1 --tree $(LUA_TREE) path --lr-path)
LUA_CPATH=$(shell luarocks --lua-version 5.1 --tree $(LUA_TREE) path --lr-cpath)
LLS_URL="https://github.com/LuaLS/lua-language-server/releases/download/3.13.4/lua-language-server-3.13.4-linux-x64.tar.gz"
LLS_GZ=lua-language-server-3.13.4-linux-x64.tar.gz
LLS=.venv/bin/lua-language-server

.PHONY: test clean help

# all: test luacheck luals ## Run all the targets

# $(LLS):
# 	curl -L $(LLS_URL) -o /tmp/$(LLS_GZ)
# 	tar xfz /tmp/$(LLS_GZ) -C .venv
# 	rm /tmp/$(LLS_GZ)

luacheck: ## Run luackeck
	$(LUACHECK) .

# luals: $(LLS) ## Run language server checks.
# 	lua-language-server --configpath .luarc.json --logpath .ci/lua-ls/log --check .

test: $(LUA_FILES) $(SPEC_FILES) ## Run the tests
	#$(LUAROCKS) --lua-version 5.1 --tree $(LUA_TREE) test -- --exclude-tags "suite,json"
	#skipped test M5DY
	busted spec/testsuite/tree_spec.lua --tags "FQ7F,SYW4,PBJ2,229Q,JHB9,U9NS,J9HZ,7BUB,9U5K,6JQW,96L6,XXX6VJK,HMK4,XXXG4RS,4CQQ"

suite:
	busted spec/testsuite/tree_spec.lua --exclude-tags "C4HZ,PW8X,SM9W,U3C3"

install: $(SOURCES) ## install the lua rock
	$(LUAROCKS) --lua-version 5.1 --tree $(LUA_TREE) make

clean: ## Remove temprorary files
	rm -rf $(LUA_TREE)

help: 
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


