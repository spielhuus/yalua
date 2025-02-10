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

# TESTS_CHAPTER_TWO = "FQ7F,SYW4,PBJ2,229Q,YD5X,ZF4X,JHB9,U9NS,J9HZ,7BUB,M5DY,9U5K,6JQW,96L6,6VJK,HMK4,G4RS,4CQQ,C4HZ,2XXW,J7PZ,UGM3,RZT7,"
TESTS_CHAPTER_TWO = "JHB9,J7PZ,ZF4X,96L6,2XXW,SYW4,6VJK,U9NS,9U5K,HMK4,M5DY,6JQW,PBJ2,229Q,RZT7,G4RS,C4HZ,J9HZ,7BUB,UGM3,YD5X,FQ7F,4CQQ"
TESTS_CHAPTER_FIVE = "5BVJ,J3BT,UDR7,98YD,27NA,CUP7,S9E8,9SHH"

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
	# last test is 2.11
	busted spec/testsuite/tree_spec.lua --tags $(TESTS_CHAPTER_TWO),$(TESTS_CHAPTER_FIVE)

suite:
	busted spec/testsuite/tree_spec.lua --exclude-tags "CT4Q,LX3P"

install: $(SOURCES) ## install the lua rock
	$(LUAROCKS) --lua-version 5.1 --tree $(LUA_TREE) make

clean: ## Remove temprorary files
	rm -rf $(LUA_TREE)

help: 
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


