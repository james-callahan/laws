local awsv4 = require "aws.v4"

describe("Pass AWSv4 test suite", function()
	-- The test suite was obtained from http://docs.aws.amazon.com/general/latest/gr/samples/aws4_testsuite.zip
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

	local dir = "./spec/aws4_testsuite/"
	for i, test_name in ipairs {
		"get-header-key-duplicate";
		"get-header-value-order";
		"get-header-value-trim";
		"get-relative-relative";
		"get-relative";
		"get-slash-dot-slash";
		"get-slash-pointless-dot";
		"get-slash";
		"get-slashes";
		"get-space";
		"get-unreserved";
		"get-utf8";
		"get-vanilla-empty-query-key";
		"get-vanilla-query-order-key-case";
		"get-vanilla-query-order-key";
		"get-vanilla-query-order-value";
		"get-vanilla-query-unreserved";
		"get-vanilla-query";
		"get-vanilla-ut8-query";
		"get-vanilla";
		"post-header-key-case";
		"post-header-key-sort";
		"post-header-value-case";
		"post-vanilla-empty-query-value";
		-- These two have invalid whitespace in targets, so skip them
		--"post-vanilla-query-nonunreserved";
		--"post-vanilla-query-space";
		"post-vanilla-query";
		"post-vanilla";
		"post-x-www-form-urlencoded-parameters";
		"post-x-www-form-urlencoded";
	} do
		local req = read_file(dir..test_name..".req")
		local creq = read_file(dir..test_name..".creq")
		local sts = read_file(dir..test_name..".sts")
		local authz = read_file(dir..test_name..".authz")
		-- local sreq = read_file(dir..test_name..".sreq")
		it("passes test #" .. test_name:gsub("%-", "_"), function()
			-- http (lowercase) is not allowed... but amazon use it
			local method, target, str_headers, body = req:match("^(%S+) (.-) [Hh][Tt][Tt][Pp]/1.[01]\r\n(.-\r\n)\r\n(.*)")
			local path, query = target:match("([^%?]*)%??(.*)")
			path = path or target
			local headers = {
				["X-Amz-Date"] = false; -- test suite uses normal date header instead
			}
			for k, v in str_headers:gmatch("([^:]*): ?(.-)\r\n") do
				local old_v = headers[k:lower()]
				if old_v then
					-- The amazon testsuite seems to sort headers when the spec says it shouldn't
					-- As a hack, sort them here, so that tests pass
					local t = {}
					for val in old_v:gmatch("[^,]+") do
						t[#t+1] = val
					end
					t[#t+1] = v
					table.sort(t)
					v = table.concat(t, ",")
				end
				headers[k:lower()] = v
			end
			if body == "" then body = nil end
			local http_req, interim = awsv4.prepare_request {
				Region = "us-east-1";
				Service = "host";
				AccessKey = "AKIDEXAMPLE";
				SecretKey = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY";
				method = method;
				path = path;
				query = query;
				headers = headers;
				body = body;
				timestamp = 1315611360; -- Timestamp used by all tests
			}
			assert.same(creq:gsub("\r\n", "\n"), interim.CanonicalRequest)
			assert.same(sts:gsub("\r\n", "\n"), interim.StringToSign)
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
