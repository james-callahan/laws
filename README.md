# LAWS

A [Lua](http://www.lua.org/) library for interacting with [AWS (Amazon Web Services)](https://aws.amazon.com/).

## Dependencies

  - [luaossl](http://25thandclement.com/~william/projects/luaossl.html)


## Modules

### `aws.v4`

Implements the [AWS Signature v4](http://docs.aws.amazon.com/general/latest/gr/sigv4_signing.html) algorithm.
This can be used to sign requests to a variety of Amazon services.

#### `aws.v4.canonicalise_path`

```lua
CanonicalURI = canonicalise_path(path)
```

Canonicalises the given string argument according to the v4 signature rules for paths:

  - Removes redundant path components, e.g. `..` and `.`
  - Ensures (only) the correct characters are escaped


#### `aws.v4.canonicalise_query_string`

```lua
CanonicalQueryString = canonicalise_query_string(query)
```

Canonicalises the given string argument according to the v4 signature rules for query strings:

  - Ensures (only) the correct characters are escaped
  - Query arguments are sorted


#### `aws.v4.derive_signing_key`

```lua
kSigning = derive_signing_key(kSecret, Date, Region, Service)
```

Derives the signing key as specified in http://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html
Uses a SHA256 HMAC.


#### `aws.v4.prepare_request`

```lua
request, extra = prepare_request(tbl)
```

Prepares a signed HTTP(S) request.

Currently does not support Authentication parameters in the query string.


The fields of `tbl` are:

Field                   | Type                          | Description
------------------------|-------------------------------|-----------------------
`.Domain`               | `string\|nil`                 | The domain to hit, defaults to `"amazonaws.com"`
`.Region`               | `string`                      | The Amazon region. e.g. `"us-east-1"`
`.Service`              | `string`                      | The Amazon service. e.g. `"kinesis"`
`.method`               | `string`                      | e.g. `"GET"`
`.CanonicalURI`         | `string\|nil`                 | A pre-canonicalised path. If not provided `.path` will be canonicalised
`.path`                 | `string\|nil`                 | The path of your request. Not used if `.CanonicalURI` is specified. If not provided or empty, defaults to `"/"`
`.CanonicalQueryString` | `string\|nil`                 | A pre-canonicalised query-string. If not provided `.query` will be canonicalised
`.query`                | `string\|nil`                 | The query string for your request. Not used if `.CanonicalQueryString` is specified. Not required.
`.headers`              | `{string:string\|false}\|nil` | Table of string key/value pairs to use as signed headers in the request. A value of `false` prevents the header from being automatically filled in. Keys will be normalised to Title-Case; behaviour on duplicates is undefined.
`.body`                 | `string\|nil`                 | Request body
`.AccessKey`            | `string`                      | Your Amazon access key.
`.SigningKey`           | `string\|nil`                 | A pre-derived signing key, if one is not provided, it will be derived from `.SecretKey`
`.SecretKey`            | `string\|nil`                 | Your Amazon secret key, only required if you do not specify `.SigningKey`
`.timestamp`            | `number\|nil`                 | When request should be signed for as a unix timestamp. defaults to `os.time()` i.e. now
`.tls`                  | `boolean\|nil`                | A truthy value will use HTTPS, false indicates HTTP. defaults to `true`
`.port`                 | `number\|nil`                 | TCP port for request. defaults to `443` for HTTPS or `80` for HTTP

The returned `request` object has fields:

Field       | Type              | Description
------------|-------------------|-----------------------------------------------
`.url`      | `string`          | URL representing the Host,
`.host`     | `string`          | Host to connect to. e.g. `"kinesis.us-east-1.amazonaws.com"`
`.port`     | `number`          | TCP port to connect to. e.g. `443`
`.tls`      | `boolean`         | Should SSL/TLS be used to connect? e.g. `true`
`.method`   | `string`          | e.g. `"GET"`
`.target`   | `string`          | The target (the part between method and `HTTP/`) ready to be used in a HTTP request. i.e. path and query string
`.headers`  | `{string:string}` | Table of headers
`.body`     | `string\|nil`      | `.body` as passed in

The returned `extra` object has intermediary values calculated by the AWS v4 signing algorithm.

Field                   | Type
------------------------|----------
`.CanonicalURI`         | `string`
`.CanonicalQueryString` | `string`
`.SignedHeaders`        | `string`
`.CanonicalHeaders`     | `string`
`.CanonicalRequest`     | `string`
`.StringToSign`         | `string`
`.SigningKey`           | `string`
`.Signature`            | `string`
`.Authorization`        | `string`


If not provided, certain headers will be added.
To prevent a header from getting added, provide it in `.headers` with a boolean value of `false`

  - `Host`
  - `X-Amz-Date`
  - `Authorization`


##### Example

This example prepares a HTTP request to Amazon Kinesis to [ListStreams](http://docs.aws.amazon.com/kinesis/latest/APIReference/API_ListStreams.html)

```lua
local prepare_request = require "aws.v4".prepare_request
local request, extra = prepare_request {
	Region = "us-east-1";
	Service = "kinesis";
	method = "POST";
	headers = {
		["X-Amz-Target"] = "Kinesis_20131202.ListStreams";
		["Content-Type"] = "application/x-amz-json-1.1";
	};
	body = '{}';
	AccessKey = "AKIDEXAMPLE";
	SecretKey = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY";
}
```
