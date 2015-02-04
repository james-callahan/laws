package = "laws"
version = "scm-0"

description= {
	summary = "AWS Library for Lua";
	license = "MIT/X11";
}

dependencies = {
	"lua";
	"luaossl";
}

source = {
	url = "git://github.com/chatid/laws.git";
}

build = {
	type = "builtin";
	modules = {
		["aws.v4"] = "aws/v4.lua";
	};
}
