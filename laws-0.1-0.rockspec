package = "laws"
version = "0.1-0"

description = {
	summary = "AWS Library for Lua";
	homepage = "https://github.com/james-callahan/laws";
	license = "MIT";
}

dependencies = {
	"lua";
	"luaossl";
}

source = {
	url = "https://github.com/james-callahan/laws/archive/v0.1.zip";
	dir = "laws-0.1";
}

build = {
	type = "builtin";
	modules = {
		["aws.v4"] = "aws/v4.lua";
	};
}
