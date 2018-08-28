local awsv4 = require "aws.v4"

describe("Pass AWSv4 test suite", function()
	-- The test suite was obtained from https://docs.aws.amazon.com/general/latest/gr/samples/aws-sig-v4-test-suite.zip
	-- sha1sum of the test suite .zip is c66ea06884dad4348558e93380c8bf91e8551a6f
	-- Information about it can be found at http://docs.aws.amazon.com/general/latest/gr/signature-v4-test-suite.html
	local function read_file(path)
		local fd, err, code = io.open(path, "rb")
		if fd == nil then
			if code == 2 then -- not found
				return nil
			else
				error(err)
			end
		end
		local contents = assert(fd:read"*a")
		fd:close()
		return contents
	end

	local dir = "./spec/aws-sig-v4-test-suite/"
	for _, test_name in ipairs {
		"get-header-key-duplicate";
		"get-header-value-multiline";
		"get-header-value-order";
		"get-header-value-trim";
		"get-unreserved";
		"get-utf8";
		"get-vanilla";
		"get-vanilla-empty-query-key";
		"get-vanilla-query";
		"get-vanilla-query-order-key";
		"get-vanilla-query-order-key-case";
		"get-vanilla-query-order-value";
		"get-vanilla-query-unreserved";
		"get-vanilla-utf8-query";
		"normalize-path/get-relative";
		"normalize-path/get-relative-relative";
		"normalize-path/get-slash";
		"normalize-path/get-slash-dot-slash";
		"normalize-path/get-slashes";
		"normalize-path/get-slash-pointless-dot";
		"normalize-path/get-space";
		"post-header-key-case";
		"post-header-key-sort";
		"post-header-value-case";
		"post-sts-token/post-sts-header-after";
		"post-sts-token/post-sts-header-before";
		"post-vanilla";
		"post-vanilla-empty-query-value";
		"post-vanilla-query";
		"post-x-www-form-urlencoded";
		"post-x-www-form-urlencoded-parameters";
	} do
		local filename = test_name:match("[^/]+$")
		local req = read_file(dir..test_name.."/"..filename..".req")
		;(req and it or pending)("passes test #" .. test_name:gsub("%-", "_"), function()
			local creq = read_file(dir..test_name.."/"..filename..".creq")
			local sts = read_file(dir..test_name.."/"..filename..".sts")
			local authz = read_file(dir..test_name.."/"..filename..".authz")
			-- local sreq = read_file(dir..test_name..".sreq")

			local method, target, pos = req:match("^(%S+) (.-) HTTP/1.[01]()")
			local path, query = target:match("([^%?]*)%??(.*)")
			path = path or target
			local str_headers, body = req:match("^\n(.-\n)\n(.*)", pos)
			str_headers = str_headers or req:sub(pos+1) .. "\n"
			local headers = {
				["X-Amz-Date"] = false; -- test suite uses normal date header instead
			}
			for k, v in str_headers:gmatch("([^%s:]+): *(.-)\n%f[%z%w]") do
				v = v:gsub("\n +", ",")
				local old_v = headers[k:lower()]
				if old_v then
					v = old_v .. "," .. v
				end
				headers[k:lower()] = v
			end
			if body == "" then body = nil end
			local http_req, interim = awsv4.prepare_request {
				Region = "us-east-1";
				Service = "service";
				AccessKey = "AKIDEXAMPLE";
				SecretKey = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY";
				method = method;
				path = path;
				query = query;
				headers = headers;
				body = body;
				timestamp = 1440938160; -- Timestamp used by all tests
			}
			assert.truthy(http_req)
			assert.same(creq, interim.CanonicalRequest)
			assert.same(sts, interim.StringToSign)
			assert.same(authz, interim.Authorization)
		end)
	end
end)

describe("Path canonicalisation is correct", function()
	it("Handles . and .. correctly", function()
		assert.same("/", awsv4.canonicalise_path "/")
		assert.same("/", awsv4.canonicalise_path "/.")
		assert.same("/", awsv4.canonicalise_path "/./foo/../")
		assert.same("/bar", awsv4.canonicalise_path "/foo/../foo/./../bar")
		assert.same("/..foo", awsv4.canonicalise_path "/..foo")
		assert.same("/bar/.foo", awsv4.canonicalise_path "/./bar/.foo")
	end)
	it("Can't get above top dir", function()
		assert.same("/foo", awsv4.canonicalise_path "/../foo")
	end)
	it("Escapes correctly", function()
		assert.same("/foo", awsv4.canonicalise_path "/%66oo")
		-- for aws, space must be %20, not +
		assert.same("/%20", awsv4.canonicalise_path "/ ")
	end)
end)

describe("port is handled correctly", function()
	it("is appended to Host", function()
		assert.same("host.us-east-1.amazonaws.com", (awsv4.prepare_request {
			Region = "us-east-1";
			Service = "host";
			AccessKey = "AKIDEXAMPLE";
			SecretKey = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY";
			method = "GET";
		}).headers.Host)
		assert.same("host.us-east-1.amazonaws.com", (awsv4.prepare_request {
			Region = "us-east-1";
			Service = "host";
			AccessKey = "AKIDEXAMPLE";
			SecretKey = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY";
			method = "GET";
			port = 443;
		}).headers.Host)
		assert.same("host.us-east-1.amazonaws.com", (awsv4.prepare_request {
			Region = "us-east-1";
			Service = "host";
			AccessKey = "AKIDEXAMPLE";
			SecretKey = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY";
			method = "GET";
			port = 80;
			tls = false
		}).headers.Host)
		assert.same("host.us-east-1.amazonaws.com:1234", (awsv4.prepare_request {
			Region = "us-east-1";
			Service = "host";
			AccessKey = "AKIDEXAMPLE";
			SecretKey = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY";
			method = "GET";
			port = 1234;
		}).headers.Host)
		assert.same("host.us-east-1.amazonaws.com:8080", (awsv4.prepare_request {
			Region = "us-east-1";
			Service = "host";
			AccessKey = "AKIDEXAMPLE";
			SecretKey = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY";
			method = "GET";
			port = 8080;
			tls = false
		}).headers.Host)
	end)
end)
