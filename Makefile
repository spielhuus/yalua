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
TESTS_CHAPTER_FIVE = "5BVJ,J3BT,UDR7,98YD,27NA,CUP7,xxxS9E8,9SHH"
TESTS_CHAPTER_SIX = "8G76,BEC7,93WF,U3C3,6HB6,P76L,5TYM,6WPF,Z9M4,XV9V,MJS9,6BCT,HMQ5,2LFX,5GBF,A2M4,4ZYM,6CK3,TL85,P94K,CC74,Q9WF,5NYZ,K527,9WXW,7FWL,JS2J,6LVF,6WLZ,S4JQ"
TESTS_CHAPTER_SEVEN = "CT4Q,C2DT,T4YY,9TFX,PRH3,FRK4,DFF7,QF4Y,4GC6,HS5T,xxx8UDB,NP9H,WZ62,7A4E,Q8AD,SSW6,5KJE,Q88A,xxx9MMW,87E4,DBG4,LQZ7,3GZX,LE5A,5C5M,L9U5"
TESTS_CHAPTER_EIGHT = "P2AD,W42U,M5C3,JQ4R,V9D5,Z67P,7T8X,B3HG,4QFQ,F8F9,A6F9,K858,S3PD,T5N4,5WE3,T26H,57H4,G992,M9B4,DWX9,TE2A,R4YG,735Y"
TESTS_CHAPTER_NINE = "UT92,9DXL,W4TN,M7A3,6ZKB,RTP8"
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
	busted spec/testsuite/tree_spec.lua --tags $(TESTS_CHAPTER_TWO),$(TESTS_CHAPTER_FIVE),$(TESTS_CHAPTER_SIX),$(TESTS_CHAPTER_SEVEN),$(TESTS_CHAPTER_EIGHT),$(TESTS_CHAPTER_NINE)

suite:
	busted spec/testsuite/tree_spec.lua --exclude-tags "CT4Q,LX3P"

install: $(SOURCES) ## install the lua rock
	$(LUAROCKS) --lua-version 5.1 --tree $(LUA_TREE) make

clean: ## Remove temprorary files
	rm -rf $(LUA_TREE)

help: 
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


