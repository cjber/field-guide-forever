local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)[/\\]") or "."
local Mock = dofile(here .. "/wow_mock.lua")
local extractor = dofile(Mock.Root() .. "tools/extract_mock_catalogue.lua")
local formatNumber = extractor.formatNumber

assert(formatNumber(1) == "1", "integers keep their plain form")
assert(formatNumber(1.0) == "1", "integral floats use the integer form, not a build-dependent 1.0")
assert(formatNumber("2") == "2", "numeric strings use the same formatting")
assert(formatNumber("2.0") == "2", "integral numeric strings use the integer form")
assert(formatNumber(1.5) == "1.5000", "fractional numbers always keep four decimals")
assert(formatNumber(-2.25) == "-2.2500", "negative fractions keep their sign and decimals")
assert(formatNumber(nil) == "", "missing values stay empty")
assert(formatNumber("") == "", "empty values stay empty")
assert(extractor.clean("a\tb\nc\rd") == "a b c d", "tabs and newlines are flattened to spaces")
print("extract_mock_catalogue: ok")
