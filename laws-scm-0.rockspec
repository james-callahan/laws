package = "laws"
version = "scm-0"

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
	url = "git+https://github.com/james-callahan/laws.git";
}

build = {
	type = "builtin";
	modules = {
		["aws.v4"] = "aws/v4.lua";
	};
}
