local assert = require("luassert")
local yalua = require("yalua")
local rapidjson = require("rapidjson")
describe("Run the YAML test #suite, compare with JSON", function()
  it("should parse the Spec Example 2.4. Sequence of Mappings, file: #229Q, tags: #sequence #mapping #spec", function()
  print("### should parse the Spec Example 2.4. Sequence of Mappings, file: #229Q")
    local input = "-\n  name: Mark McGwire\n  hr:   65\n  avg:  0.278\n-\n  name: Sammy Sosa\n  hr:   63\n  avg:  0.288\n"
    local tree = "[\n  {\n    \"name\": \"Mark McGwire\",\n    \"hr\": 65,\n    \"avg\": 0.278\n  },\n  {\n    \"name\": \"Sammy Sosa\",\n    \"hr\": 63,\n    \"avg\": 0.288\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Whitespace around colon in mappings, file: #26DV, tags: #alias #mapping #whitespace", function()
  print("### should parse the Whitespace around colon in mappings, file: #26DV")
    local input = "\"top1\" : \n  \"key1\" : &alias1 scalar1\n\'top2\' : \n  \'key2\' : &alias2 scalar2\ntop3: &node3 \n  *alias1 : scalar3\ntop4: \n  *alias2 : scalar4\ntop5   :    \n  scalar5\ntop6: \n  &anchor6 \'key6\' : scalar6\n"
    local tree = "{\n  \"top1\": {\n    \"key1\": \"scalar1\"\n  },\n  \"top2\": {\n    \"key2\": \"scalar2\"\n  },\n  \"top3\": {\n    \"scalar1\": \"scalar3\"\n  },\n  \"top4\": {\n    \"scalar2\": \"scalar4\"\n  },\n  \"top5\": \"scalar5\",\n  \"top6\": {\n    \"key6\": \"scalar6\"\n  }\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 5.9. Directive Indicator, file: #27NA, tags: #spec #directive #1.3-err", function()
  print("### should parse the Spec Example 5.9. Directive Indicator, file: #27NA")
    local input = "%YAML 1.2\n--- text\n"
    local tree = "\"text\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Tags in Block Sequence, file: #2AUY, tags: #tag #sequence", function()
  print("### should parse the Tags in Block Sequence, file: #2AUY")
    local input = " - !!str a\n - b\n - !!int 42\n - d\n"
    local tree = "[\n  \"a\",\n  \"b\",\n  42,\n  \"d\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Allowed characters in keys, file: #2EBW, tags: #mapping #scalar", function()
  print("### should parse the Allowed characters in keys, file: #2EBW")
    local input = "a!\"#$%&\'()*+,-./09:;<=>?@AZ[\\]^_`az{|}~: safe\n?foo: safe question mark\n:foo: safe colon\n-foo: safe dash\nthis is#not: a comment\n"
    local tree = "{\n  \"a!\\\"#$%&\'()*+,-./09:;<=>?@AZ[\\\\]^_`az{|}~\": \"safe\",\n  \"?foo\": \"safe question mark\",\n  \":foo\": \"safe colon\",\n  \"-foo\": \"safe dash\",\n  \"this is#not\": \"a comment\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.13. Reserved Directives [1.3], file: #2LFX, tags: #spec #directive #header #double #1.3-mod", function()
  print("### should parse the Spec Example 6.13. Reserved Directives [1.3], file: #2LFX")
    local input = "%FOO  bar baz # Should be ignored\n              # with a warning.\n---\n\"foo\"\n"
    local tree = "\"foo\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Anchors With Colon in Name, file: #2SXE, tags: #alias #edge #mapping #1.3-err", function()
  print("### should parse the Anchors With Colon in Name, file: #2SXE")
    local input = "&a: key: &a value\nfoo:\n  *a:\n"
    local tree = "{\n  \"key\": \"value\",\n  \"foo\": \"key\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.25. Unordered Sets, file: #2XXW, tags: #spec #mapping #unknown-tag #explicit-key", function()
  print("### should parse the Spec Example 2.25. Unordered Sets, file: #2XXW")
    local input = "# Sets are represented as a\n# Mapping where each key is\n# associated with a null value\n--- !!set\n? Mark McGwire\n? Sammy Sosa\n? Ken Griff\n"
    local tree = "{\n  \"Mark McGwire\": null,\n  \"Sammy Sosa\": null,\n  \"Ken Griff\": null\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Three explicit integers in a block sequence, file: #33X3, tags: #sequence #tag", function()
  print("### should parse the Three explicit integers in a block sequence, file: #33X3")
    local input = "---\n- !!int 1\n- !!int -2\n- !!int 33\n"
    local tree = "[\n  1,\n  -2,\n  33\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Tags for Root Objects, file: #35KP, tags: #explicit-key #header #mapping #tag", function()
  print("### should parse the Tags for Root Objects, file: #35KP")
    local input = "--- !!map\n? a\n: b\n--- !!seq\n- !!str c\n--- !!str\nd\ne\n"
    local tree = "{\n  \"a\": \"b\"\n}\n[\n  \"c\"\n]\n\"d e\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiline plain scalar with empty line, file: #36F6, tags: #mapping #scalar", function()
  print("### should parse the Multiline plain scalar with empty line, file: #36F6")
    local input = "---\nplain: a\n b\n\n c\n"
    local tree = "{\n  \"plain\": \"a b\\nc\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Block Sequence in Block Sequence, file: #3ALJ, tags: #sequence", function()
  print("### should parse the Block Sequence in Block Sequence, file: #3ALJ")
    local input = "- - s1_i1\n  - s1_i2\n- s2\n"
    local tree = "[\n  [\n    \"s1_i1\",\n    \"s1_i2\"\n  ],\n  \"s2\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.1. Alias Nodes, file: #3GZX, tags: #mapping #spec #alias", function()
  print("### should parse the Spec Example 7.1. Alias Nodes, file: #3GZX")
    local input = "First occurrence: &anchor Foo\nSecond occurrence: *anchor\nOverride anchor: &anchor Bar\nReuse anchor: *anchor\n"
    local tree = "{\n  \"First occurrence\": \"Foo\",\n  \"Second occurrence\": \"Foo\",\n  \"Override anchor\": \"Bar\",\n  \"Reuse anchor\": \"Bar\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Plain Scalar looking like key, comment, anchor and tag, file: #3MYT, tags: #scalar", function()
  print("### should parse the Plain Scalar looking like key, comment, anchor and tag, file: #3MYT")
    local input = "---\nk:#foo\n &a !t s\n"
    local tree = "\"k:#foo &a !t s\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Single block sequence with anchor, file: #3R3P, tags: #anchor #sequence", function()
  print("### should parse the Single block sequence with anchor, file: #3R3P")
    local input = "&sequence\n- a\n"
    local tree = "[\n  \"a\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Leading tabs in double quoted, file: #3RLN, tags: #double #whitespace", function()
  print("### should parse the Leading tabs in double quoted, file: #3RLN")
    local input = "\"1 leading\n    \\ttab\"\n"
    local tree = "\"1 leading \\ttab\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Escaped slash in double quotes, file: #3UYS, tags: #double", function()
  print("### should parse the Escaped slash in double quotes, file: #3UYS")
    local input = "escaped slash: \"a\\/b\"\n"
    local tree = "{\n  \"escaped slash\": \"a/b\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.18. Multi-line Flow Scalars, file: #4CQQ, tags: #spec #scalar", function()
  print("### should parse the Spec Example 2.18. Multi-line Flow Scalars, file: #4CQQ")
    local input = "plain:\n  This unquoted scalar\n  spans many lines.\n\nquoted: \"So does this\n  quoted scalar.\\n\"\n"
    local tree = "{\n  \"plain\": \"This unquoted scalar spans many lines.\",\n  \"quoted\": \"So does this quoted scalar.\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.7. Single Quoted Characters, file: #4GC6, tags: #spec #scalar #1.3-err", function()
  print("### should parse the Spec Example 7.7. Single Quoted Characters, file: #4GC6")
    local input = "\'here\'\'s to \"quotes\"\'\n"
    local tree = "\"here\'s to \\\"quotes\\\"\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Flow mapping colon on line after key, file: #4MUZ, tags: #flow #mapping", function()
  print("### should parse the Flow mapping colon on line after key, file: #4MUZ")
    local input = "{\"foo\"\n: \"bar\"}\n"
    local tree = "{\n  \"foo\": \"bar\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Folded Block Scalar [1.3], file: #4Q9F, tags: #folded #scalar #1.3-mod #whitespace", function()
  print("### should parse the Folded Block Scalar [1.3], file: #4Q9F")
    local input = "--- >\n ab\n cd\n \n ef\n\n\n gh\n"
    local tree = "\"ab cd\\nef\\n\\ngh\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.2. Block Indentation Indicator [1.3], file: #4QFQ, tags: #spec #literal #folded #scalar #libyaml-err #1.3-mod #whitespace", function()
  print("### should parse the Spec Example 8.2. Block Indentation Indicator [1.3], file: #4QFQ")
    local input = "- |\n detected\n- >\n \n  \n  # detected\n- |1\n  explicit\n- >\n detected\n"
    local tree = "[\n  \"detected\\n\",\n  \"\\n\\n# detected\\n\",\n  \" explicit\\n\",\n  \"detected\\n\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Trailing spaces after flow collection, file: #4RWC, tags: #flow #whitespace", function()
  print("### should parse the Trailing spaces after flow collection, file: #4RWC")
    local input = "  [1, 2, 3]  \n  \n"
    local tree = "[\n  1,\n  2,\n  3\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Colon in Double Quoted String, file: #4UYU, tags: #mapping #scalar #1.3-err", function()
  print("### should parse the Colon in Double Quoted String, file: #4UYU")
    local input = "\"foo: bar\\\": baz\"\n"
    local tree = "\"foo: bar\\\": baz\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Plain scalar with backslashes, file: #4V8U, tags: #scalar", function()
  print("### should parse the Plain scalar with backslashes, file: #4V8U")
    local input = "---\nplain\\value\\with\\backslashes\n"
    local tree = "\"plain\\\\value\\\\with\\\\backslashes\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Literal scalars, file: #4WA9, tags: #indent #literal", function()
  print("### should parse the Literal scalars, file: #4WA9")
    local input = "- aaa: |2\n    xxx\n  bbb: |\n    xxx\n"
    local tree = "[\n  {\n    \"aaa\" : \"xxx\\n\",\n    \"bbb\" : \"xxx\\n\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.4. Line Prefixes, file: #4ZYM, tags: #spec #scalar #literal #double #upto-1.2 #whitespace", function()
  print("### should parse the Spec Example 6.4. Line Prefixes, file: #4ZYM")
    local input = "plain: text\n  lines\nquoted: \"text\n  		lines\"\nblock: |\n  text\n   	lines\n"
    local tree = "{\n  \"plain\": \"text lines\",\n  \"quoted\": \"text lines\",\n  \"block\": \"text\\n \\tlines\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Explicit Non-Specific Tag [1.3], file: #52DL, tags: #tag #1.3-mod", function()
  print("### should parse the Explicit Non-Specific Tag [1.3], file: #52DL")
    local input = "---\n! a\n"
    local tree = "\"a\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Flow Mapping, file: #54T7, tags: #flow #mapping", function()
  print("### should parse the Flow Mapping, file: #54T7")
    local input = "{foo: you, bar: far}\n"
    local tree = "{\n  \"foo\": \"you\",\n  \"bar\": \"far\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Construct Binary, file: #565N, tags: #tag #unknown-tag", function()
  print("### should parse the Construct Binary, file: #565N")
    local input = "canonical: !!binary \"\\\n R0lGODlhDAAMAIQAAP//9/X17unp5WZmZgAAAOfn515eXvPz7Y6OjuDg4J+fn5\\\n OTk6enp56enmlpaWNjY6Ojo4SEhP/++f/++f/++f/++f/++f/++f/++f/++f/+\\\n +f/++f/++f/++f/++f/++SH+Dk1hZGUgd2l0aCBHSU1QACwAAAAADAAMAAAFLC\\\n AgjoEwnuNAFOhpEMTRiggcz4BNJHrv/zCFcLiwMWYNG84BwwEeECcgggoBADs=\"\ngeneric: !!binary |\n R0lGODlhDAAMAIQAAP//9/X17unp5WZmZgAAAOfn515eXvPz7Y6OjuDg4J+fn5\n OTk6enp56enmlpaWNjY6Ojo4SEhP/++f/++f/++f/++f/++f/++f/++f/++f/+\n +f/++f/++f/++f/++f/++SH+Dk1hZGUgd2l0aCBHSU1QACwAAAAADAAMAAAFLC\n AgjoEwnuNAFOhpEMTRiggcz4BNJHrv/zCFcLiwMWYNG84BwwEeECcgggoBADs=\ndescription:\n The binary value above is a tiny arrow encoded as a gif image.\n"
    local tree = "{\n  \"canonical\": \"R0lGODlhDAAMAIQAAP//9/X17unp5WZmZgAAAOfn515eXvPz7Y6OjuDg4J+fn5OTk6enp56enmlpaWNjY6Ojo4SEhP/++f/++f/++f/++f/++f/++f/++f/++f/++f/++f/++f/++f/++f/++SH+Dk1hZGUgd2l0aCBHSU1QACwAAAAADAAMAAAFLCAgjoEwnuNAFOhpEMTRiggcz4BNJHrv/zCFcLiwMWYNG84BwwEeECcgggoBADs=\",\n  \"generic\": \"R0lGODlhDAAMAIQAAP//9/X17unp5WZmZgAAAOfn515eXvPz7Y6OjuDg4J+fn5\\nOTk6enp56enmlpaWNjY6Ojo4SEhP/++f/++f/++f/++f/++f/++f/++f/++f/+\\n+f/++f/++f/++f/++f/++SH+Dk1hZGUgd2l0aCBHSU1QACwAAAAADAAMAAAFLC\\nAgjoEwnuNAFOhpEMTRiggcz4BNJHrv/zCFcLiwMWYNG84BwwEeECcgggoBADs=\\n\",\n  \"description\": \"The binary value above is a tiny arrow encoded as a gif image.\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.22. Block Collection Nodes, file: #57H4, tags: #sequence #mapping #tag", function()
  print("### should parse the Spec Example 8.22. Block Collection Nodes, file: #57H4")
    local input = "sequence: !!seq\n- entry\n- !!seq\n - nested\nmapping: !!map\n foo: bar\n"
    local tree = "{\n  \"sequence\": [\n    \"entry\",\n    [\n      \"nested\"\n    ]\n  ],\n  \"mapping\": {\n    \"foo\": \"bar\"\n  }\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Flow mapping edge cases, file: #58MP, tags: #edge #flow #mapping", function()
  print("### should parse the Flow mapping edge cases, file: #58MP")
    local input = "{x: :x}\n"
    local tree = "{\n  \"x\": \":x\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 5.7. Block Scalar Indicators, file: #5BVJ, tags: #spec #literal #folded #scalar", function()
  print("### should parse the Spec Example 5.7. Block Scalar Indicators, file: #5BVJ")
    local input = "literal: |\n  some\n  text\nfolded: >\n  some\n  text\n"
    local tree = "{\n  \"literal\": \"some\\ntext\\n\",\n  \"folded\": \"some text\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.15. Flow Mappings, file: #5C5M, tags: #spec #flow #mapping", function()
  print("### should parse the Spec Example 7.15. Flow Mappings, file: #5C5M")
    local input = "- { one : two , three: four , }\n- {five: six,seven : eight}\n"
    local tree = "[\n  {\n    \"one\": \"two\",\n    \"three\": \"four\"\n  },\n  {\n    \"five\": \"six\",\n    \"seven\": \"eight\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.5. Empty Lines, file: #5GBF, tags: #double #literal #spec #scalar #upto-1.2 #whitespace", function()
  print("### should parse the Spec Example 6.5. Empty Lines, file: #5GBF")
    local input = "Folding:\n  \"Empty line\n   	\n  as a line feed\"\nChomping: |\n  Clipped empty lines\n \n\n\n"
    local tree = "{\n  \"Folding\": \"Empty line\\nas a line feed\",\n  \"Chomping\": \"Clipped empty lines\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.13. Flow Sequence, file: #5KJE, tags: #spec #flow #sequence", function()
  print("### should parse the Spec Example 7.13. Flow Sequence, file: #5KJE")
    local input = "- [ one, two, ]\n- [three ,four]\n"
    local tree = "[\n  [\n    \"one\",\n    \"two\"\n  ],\n  [\n    \"three\",\n    \"four\"\n  ]\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Colon and adjacent value on next line, file: #5MUD, tags: #double #flow #mapping", function()
  print("### should parse the Colon and adjacent value on next line, file: #5MUD")
    local input = "---\n{ \"foo\"\n  :bar }\n"
    local tree = "{\n  \"foo\": \"bar\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.9. Separated Comment, file: #5NYZ, tags: #mapping #spec #comment", function()
  print("### should parse the Spec Example 6.9. Separated Comment, file: #5NYZ")
    local input = "key:    # Comment\n  value\n"
    local tree = "{\n  \"key\": \"value\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Colon at the beginning of adjacent flow scalar, file: #5T43, tags: #flow #mapping #scalar", function()
  print("### should parse the Colon at the beginning of adjacent flow scalar, file: #5T43")
    local input = "- { \"key\":value }\n- { \"key\"::value }\n"
    local tree = "[\n  {\n    \"key\": \"value\"\n  },\n  {\n    \"key\": \":value\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.21. Local Tag Prefix, file: #5TYM, tags: #local-tag #spec #directive #tag", function()
  print("### should parse the Spec Example 6.21. Local Tag Prefix, file: #5TYM")
    local input = "%TAG !m! !my-\n--- # Bulb here\n!m!light fluorescent\n...\n%TAG !m! !my-\n--- # Color here\n!m!light green\n"
    local tree = "\"fluorescent\"\n\"green\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.17. Explicit Block Mapping Entries, file: #5WE3, tags: #explicit-key #spec #mapping #comment #literal #sequence", function()
  print("### should parse the Spec Example 8.17. Explicit Block Mapping Entries, file: #5WE3")
    local input = "? explicit key # Empty value\n? |\n  block key\n: - one # Explicit compact\n  - two # block value\n"
    local tree = "{\n  \"explicit key\": null,\n  \"block key\\n\": [\n    \"one\",\n    \"two\"\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Question mark at start of flow key, file: #652Z, tags: #flow", function()
  print("### should parse the Question mark at start of flow key, file: #652Z")
    local input = "{ ?foo: bar,\nbar: 42\n}\n"
    local tree = "{\n  \"?foo\" : \"bar\",\n  \"bar\" : 42\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Single Entry Block Sequence, file: #65WH, tags: #sequence", function()
  print("### should parse the Single Entry Block Sequence, file: #65WH")
    local input = "- foo\n"
    local tree = "[\n  \"foo\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.3. Separation Spaces, file: #6BCT, tags: #spec #libyaml-err #sequence #whitespace #upto-1.2", function()
  print("### should parse the Spec Example 6.3. Separation Spaces, file: #6BCT")
    local input = "- foo:		 bar\n- - baz\n  -	baz\n"
    local tree = "[\n  {\n    \"foo\": \"bar\"\n  },\n  [\n    \"baz\",\n    \"baz\"\n  ]\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Tab indented top flow, file: #6CA3, tags: #indent #whitespace", function()
  print("### should parse the Tab indented top flow, file: #6CA3")
    local input = "—				[\n—				]\n"
    local tree = "[]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.26. Tag Shorthands, file: #6CK3, tags: #spec #tag #local-tag", function()
  print("### should parse the Spec Example 6.26. Tag Shorthands, file: #6CK3")
    local input = "%TAG !e! tag:example.com,2000:app/\n---\n- !local foo\n- !!str bar\n- !e!tag%21 baz\n"
    local tree = "[\n  \"foo\",\n  \"bar\",\n  \"baz\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Block Scalar Keep, file: #6FWR, tags: #literal #scalar #whitespace", function()
  print("### should parse the Block Scalar Keep, file: #6FWR")
    local input = "--- |+\n ab\n \n  \n...\n"
    local tree = "\"ab\\n\\n \\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Backslashes in singlequotes, file: #6H3V, tags: #scalar #single", function()
  print("### should parse the Backslashes in singlequotes, file: #6H3V")
    local input = "\'foo: bar\\\': baz\'\n"
    local tree = "{\n  \"foo: bar\\\\\": \"baz\'\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.1. Indentation Spaces, file: #6HB6, tags: #comment #flow #spec #indent #upto-1.2 #whitespace", function()
  print("### should parse the Spec Example 6.1. Indentation Spaces, file: #6HB6")
    local input = "  # Leading comment line spaces are\n   # neither content nor indentation.\n    \nNot indented:\n By one space: |\n    By four\n      spaces\n Flow style: [    # Leading spaces\n   By two,        # in flow style\n  Also by two,    # are neither\n  		Still by two   # content nor\n    ]             # indentation.\n"
    local tree = "{\n  \"Not indented\": {\n    \"By one space\": \"By four\\n  spaces\\n\",\n    \"Flow style\": [\n      \"By two\",\n      \"Also by two\",\n      \"Still by two\"\n    ]\n  }\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.13. In literals, newlines are preserved, file: #6JQW, tags: #spec #scalar #literal #comment", function()
  print("### should parse the Spec Example 2.13. In literals, newlines are preserved, file: #6JQW")
    local input = "# ASCII Art\n--- |\n  \\//||\\/||\n  // ||  ||__\n"
    local tree = "\"\\\\//||\\\\/||\\n// ||  ||__\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Tags for Block Objects, file: #6JWB, tags: #mapping #sequence #tag", function()
  print("### should parse the Tags for Block Objects, file: #6JWB")
    local input = "foo: !!seq\n  - !!str a\n  - !!map\n    key: !!str value\n"
    local tree = "{\n  \"foo\": [\n    \"a\",\n    {\n      \"key\": \"value\"\n    }\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Anchor for empty node, file: #6KGN, tags: #alias #anchor", function()
  print("### should parse the Anchor for empty node, file: #6KGN")
    local input = "---\na: &anchor\nb: *anchor\n"
    local tree = "{\n  \"a\": null,\n  \"b\": null\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.13. Reserved Directives, file: #6LVF, tags: #spec #directive #header #double #1.3-err", function()
  print("### should parse the Spec Example 6.13. Reserved Directives, file: #6LVF")
    local input = "%FOO  bar baz # Should be ignored\n              # with a warning.\n--- \"foo\"\n"
    local tree = "\"foo\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Allowed characters in quoted mapping key, file: #6SLA, tags: #mapping #single #double", function()
  print("### should parse the Allowed characters in quoted mapping key, file: #6SLA")
    local input = "\"foo\\nbar:baz\\tx \\\\$%^&*()x\": 23\n\'x\\ny:z\\tx $%^&*()x\': 24\n"
    local tree = "{\n  \"foo\\nbar:baz\\tx \\\\$%^&*()x\": 23,\n  \"x\\\\ny:z\\\\tx $%^&*()x\": 24\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.15. Folded newlines are preserved for \"more indented\" and blank lines, file: #6VJK, tags: #spec #folded #scalar #1.3-err", function()
  print("### should parse the Spec Example 2.15. Folded newlines are preserved for \"more indented\" and blank lines, file: #6VJK")
    local input = ">\n Sammy Sosa completed another\n fine season with great stats.\n\n   63 Home Runs\n   0.288 Batting Average\n\n What a year!\n"
    local tree = "\"Sammy Sosa completed another fine season with great stats.\\n\\n  63 Home Runs\\n  0.288 Batting Average\\n\\nWhat a year!\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.18. Primary Tag Handle [1.3], file: #6WLZ, tags: #local-tag #spec #directive #tag #1.3-mod", function()
  print("### should parse the Spec Example 6.18. Primary Tag Handle [1.3], file: #6WLZ")
    local input = "# Private\n---\n!foo \"bar\"\n...\n# Global\n%TAG ! tag:example.com,2000:app/\n---\n!foo \"bar\"\n"
    local tree = "\"bar\"\n\"bar\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.8. Flow Folding [1.3], file: #6WPF, tags: #double #spec #whitespace #scalar #1.3-mod", function()
  print("### should parse the Spec Example 6.8. Flow Folding [1.3], file: #6WPF")
    local input = "---\n\"\n  foo \n \n    bar\n\n  baz\n\"\n"
    local tree = "\" foo\\nbar\\nbaz \"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Two document start markers, file: #6XDY, tags: #header", function()
  print("### should parse the Two document start markers, file: #6XDY")
    local input = "---\n---\n"
    local tree = "null\nnull\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 9.6. Stream, file: #6ZKB, tags: #spec #header #1.3-err", function()
  print("### should parse the Spec Example 9.6. Stream, file: #6ZKB")
    local input = "Document\n---\n# Empty\n...\n%YAML 1.2\n---\nmatches %: 20\n"
    local tree = "\"Document\"\nnull\n{\n  \"matches %\": 20\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.20. Block Node Types, file: #735Y, tags: #comment #double #spec #folded #tag", function()
  print("### should parse the Spec Example 8.20. Block Node Types, file: #735Y")
    local input = "-\n  \"flow in block\"\n- >\n Block scalar\n- !!map # Block collection\n  foo : bar\n"
    local tree = "[\n  \"flow in block\",\n  \"Block scalar\\n\",\n  {\n    \"foo\": \"bar\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Tags in Implicit Mapping, file: #74H7, tags: #tag #mapping", function()
  print("### should parse the Tags in Implicit Mapping, file: #74H7")
    local input = "!!str a: b\nc: !!int 42\ne: !!str f\ng: h\n!!str 23: !!bool false\n"
    local tree = "{\n  \"a\": \"b\",\n  \"c\": 42,\n  \"e\": \"f\",\n  \"g\": \"h\",\n  \"23\": false\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Block Scalar Strip [1.3], file: #753E, tags: #literal #scalar #1.3-mod #whitespace", function()
  print("### should parse the Block Scalar Strip [1.3], file: #753E")
    local input = "--- |-\n ab\n \n \n...\n"
    local tree = "\"ab\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.6. Double Quoted Lines, file: #7A4E, tags: #spec #scalar #upto-1.2 #whitespace", function()
  print("### should parse the Spec Example 7.6. Double Quoted Lines, file: #7A4E")
    local input = "\" 1st non-empty\n\n 2nd non-empty \n				3rd non-empty \"\n"
    local tree = "\" 1st non-empty\\n2nd non-empty 3rd non-empty \"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Node and Mapping Key Anchors [1.3], file: #7BMT, tags: #anchor #comment #mapping #1.3-mod", function()
  print("### should parse the Node and Mapping Key Anchors [1.3], file: #7BMT")
    local input = "---\ntop1: &node1\n  &k1 key1: one\ntop2: &node2 # comment\n  key2: two\ntop3:\n  &k3 key3: three\ntop4: &node4\n  &k4 key4: four\ntop5: &node5\n  key5: five\ntop6: &val6\n  six\ntop7:\n  &val7 seven\n"
    local tree = "{\n  \"top1\": {\n    \"key1\": \"one\"\n  },\n  \"top2\": {\n    \"key2\": \"two\"\n  },\n  \"top3\": {\n    \"key3\": \"three\"\n  },\n  \"top4\": {\n    \"key4\": \"four\"\n  },\n  \"top5\": {\n    \"key5\": \"five\"\n  },\n  \"top6\": \"six\",\n  \"top7\": \"seven\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.10. Node for “Sammy Sosa” appears twice in this document, file: #7BUB, tags: #mapping #sequence #spec #alias", function()
  print("### should parse the Spec Example 2.10. Node for “Sammy Sosa” appears twice in this document, file: #7BUB")
    local input = "---\nhr:\n  - Mark McGwire\n  # Following node labeled SS\n  - &SS Sammy Sosa\nrbi:\n  - *SS # Subsequent occurrence\n  - Ken Griffey\n"
    local tree = "{\n  \"hr\": [\n    \"Mark McGwire\",\n    \"Sammy Sosa\"\n  ],\n  \"rbi\": [\n    \"Sammy Sosa\",\n    \"Ken Griffey\"\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.24. Verbatim Tags, file: #7FWL, tags: #mapping #spec #tag #unknown-tag", function()
  print("### should parse the Spec Example 6.24. Verbatim Tags, file: #7FWL")
    local input = "!<tag:yaml.org,2002:str> foo :\n  !<!bar> baz\n"
    local tree = "{\n  \"foo\": \"baz\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.10. Folded Lines - 8.13. Final Empty Lines, file: #7T8X, tags: #spec #folded #scalar #comment #1.3-err", function()
  print("### should parse the Spec Example 8.10. Folded Lines - 8.13. Final Empty Lines, file: #7T8X")
    local input = ">\n\n folded\n line\n\n next\n line\n   * bullet\n\n   * list\n   * lines\n\n last\n line\n\n# Comment\n"
    local tree = "\"\\nfolded line\\nnext line\\n  * bullet\\n\\n  * list\\n  * lines\\n\\nlast line\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Comment in flow sequence before comma, file: #7TMG, tags: #comment #flow #sequence", function()
  print("### should parse the Comment in flow sequence before comma, file: #7TMG")
    local input = "---\n[ word1\n# comment\n, word2]\n"
    local tree = "[\n  \"word1\",\n  \"word2\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Block Mapping with Missing Values, file: #7W2P, tags: #explicit-key #mapping", function()
  print("### should parse the Block Mapping with Missing Values, file: #7W2P")
    local input = "? a\n? b\nc:\n"
    local tree = "{\n  \"a\": null,\n  \"b\": null,\n  \"c\": null\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Bare document after document end marker, file: #7Z25, tags: #footer", function()
  print("### should parse the Bare document after document end marker, file: #7Z25")
    local input = "---\nscalar1\n...\nkey: value\n"
    local tree = "\"scalar1\"\n{\n  \"key\": \"value\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Empty flow collections, file: #7ZZ5, tags: #flow #mapping #sequence", function()
  print("### should parse the Empty flow collections, file: #7ZZ5")
    local input = "---\nnested sequences:\n- - - []\n- - - {}\nkey1: []\nkey2: {}\n"
    local tree = "{\n  \"nested sequences\": [\n    [\n      [\n        []\n      ]\n    ],\n    [\n      [\n        {}\n      ]\n    ]\n  ],\n  \"key1\": [],\n  \"key2\": {}\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Three dashes and content without space, file: #82AN, tags: #scalar #1.3-err", function()
  print("### should parse the Three dashes and content without space, file: #82AN")
    local input = "---word1\nword2\n"
    local tree = "\"---word1 word2\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.8. Single Quoted Implicit Keys, file: #87E4, tags: #spec #flow #sequence #mapping", function()
  print("### should parse the Spec Example 7.8. Single Quoted Implicit Keys, file: #87E4")
    local input = "\'implicit block key\' : [\n  \'implicit flow key\' : value,\n ]\n"
    local tree = "{\n  \"implicit block key\": [\n    {\n      \"implicit flow key\": \"value\"\n    }\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Plain mapping key ending with colon, file: #8CWC, tags: #mapping #scalar", function()
  print("### should parse the Plain mapping key ending with colon, file: #8CWC")
    local input = "---\nkey ends with two colons::: value\n"
    local tree = "{\n  \"key ends with two colons::\": \"value\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.10. Comment Lines, file: #8G76, tags: #spec #comment #empty #scalar #whitespace", function()
  print("### should parse the Spec Example 6.10. Comment Lines, file: #8G76")
    local input = "  # Comment\n   \n\n\n\n\n"
    local tree = ""
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiline plain flow mapping key without value, file: #8KB6, tags: #flow #mapping", function()
  print("### should parse the Multiline plain flow mapping key without value, file: #8KB6")
    local input = "---\n- { single line, a: b}\n- { multi\n  line, a: b}\n"
    local tree = "[\n  {\n    \"single line\": null,\n    \"a\": \"b\"\n  },\n  {\n    \"multi line\": null,\n    \"a\": \"b\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Explicit Non-Specific Tag, file: #8MK2, tags: #tag #1.3-err", function()
  print("### should parse the Explicit Non-Specific Tag, file: #8MK2")
    local input = "! a\n"
    local tree = "\"a\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Block Sequence in Block Mapping, file: #8QBE, tags: #mapping #sequence", function()
  print("### should parse the Block Sequence in Block Mapping, file: #8QBE")
    local input = "key:\n - item1\n - item2\n"
    local tree = "{\n  \"key\": [\n    \"item1\",\n    \"item2\"\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.14. Flow Sequence Entries, file: #8UDB, tags: #spec #flow #sequence", function()
  print("### should parse the Spec Example 7.14. Flow Sequence Entries, file: #8UDB")
    local input = "[\n\"double\n quoted\", \'single\n           quoted\',\nplain\n text, [ nested ],\nsingle: pair,\n]\n"
    local tree = "[\n  \"double quoted\",\n  \"single quoted\",\n  \"plain text\",\n  [\n    \"nested\"\n  ],\n  {\n    \"single\": \"pair\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Anchor with unicode character, file: #8XYN, tags: #anchor", function()
  print("### should parse the Anchor with unicode character, file: #8XYN")
    local input = "---\n- &😁 unicode anchor\n"
    local tree = "[\n  \"unicode anchor\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Block Mappings in Block Sequence, file: #93JH, tags: #mapping #sequence", function()
  print("### should parse the Block Mappings in Block Sequence, file: #93JH")
    local input = " - key: value\n   key2: value2\n -\n   key3: value3\n"
    local tree = "[\n  {\n    \"key\": \"value\",\n    \"key2\": \"value2\"\n  },\n  {\n    \"key3\": \"value3\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.6. Line Folding [1.3], file: #93WF, tags: #folded #spec #whitespace #scalar #1.3-mod", function()
  print("### should parse the Spec Example 6.6. Line Folding [1.3], file: #93WF")
    local input = "--- >-\n  trimmed\n  \n \n\n  as\n  space\n"
    local tree = "\"trimmed\\n\\n\\nas space\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.14. In the folded scalars, newlines become spaces, file: #96L6, tags: #spec #folded #scalar", function()
  print("### should parse the Spec Example 2.14. In the folded scalars, newlines become spaces, file: #96L6")
    local input = "--- >\n  Mark McGwire\'s\n  year was crippled\n  by a knee injury.\n"
    local tree = "\"Mark McGwire\'s year was crippled by a knee injury.\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Leading tab content in literals, file: #96NN, tags: #indent #literal #whitespace", function()
  print("### should parse the Leading tab content in literals, file: #96NN")
    local input = "foo: |-\n 			bar\n"
    local tree = "{\"foo\":\"\\tbar\"}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 5.5. Comment Indicator, file: #98YD, tags: #spec #comment #empty", function()
  print("### should parse the Spec Example 5.5. Comment Indicator, file: #98YD")
    local input = "# Comment only.\n"
    local tree = ""
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiline doublequoted flow mapping key without value, file: #9BXH, tags: #double #flow #mapping", function()
  print("### should parse the Multiline doublequoted flow mapping key without value, file: #9BXH")
    local input = "---\n- { \"single line\", a: b}\n- { \"multi\n  line\", a: b}\n"
    local tree = "[\n  {\n    \"single line\": null,\n    \"a\": \"b\"\n  },\n  {\n    \"multi line\": null,\n    \"a\": \"b\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 9.6. Stream [1.3], file: #9DXL, tags: #spec #header #1.3-mod", function()
  print("### should parse the Spec Example 9.6. Stream [1.3], file: #9DXL")
    local input = "Mapping: Document\n---\n# Empty\n...\n%YAML 1.2\n---\nmatches %: 20\n"
    local tree = "{\n  \"Mapping\": \"Document\"\n}\nnull\n{\n  \"matches %\": 20\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multi-level Mapping Indent, file: #9FMG, tags: #mapping #indent", function()
  print("### should parse the Multi-level Mapping Indent, file: #9FMG")
    local input = "a:\n  b:\n    c: d\n  e:\n    f: g\nh: i\n"
    local tree = "{\n  \"a\": {\n    \"b\": {\n      \"c\": \"d\"\n    },\n    \"e\": {\n      \"f\": \"g\"\n    }\n  },\n  \"h\": \"i\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Simple Mapping Indent, file: #9J7A, tags: #simple #mapping #indent", function()
  print("### should parse the Simple Mapping Indent, file: #9J7A")
    local input = "foo:\n  bar: baz\n"
    local tree = "{\n  \"foo\": {\n    \"bar\": \"baz\"\n  }\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Various combinations of tags and anchors, file: #9KAX, tags: #anchor #mapping #1.3-err #tag", function()
  print("### should parse the Various combinations of tags and anchors, file: #9KAX")
    local input = "---\n&a1\n!!str\nscalar1\n---\n!!str\n&a2\nscalar2\n---\n&a3\n!!str scalar3\n---\n&a4 !!map\n&a5 !!str key5: value4\n---\na6: 1\n&anchor6 b6: 2\n---\n!!map\n&a8 !!str key8: value7\n---\n!!map\n!!str &a10 key10: value9\n---\n!!str &a11\nvalue11\n"
    local tree = "\"scalar1\"\n\"scalar2\"\n\"scalar3\"\n{\n  \"key5\": \"value4\"\n}\n{\n  \"a6\": 1,\n  \"b6\": 2\n}\n{\n  \"key8\": \"value7\"\n}\n{\n  \"key10\": \"value9\"\n}\n\"value11\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Scalar doc with \'...\' in content, file: #9MQT, tags: #double #scalar", function()
  print("### should parse the Scalar doc with \'...\' in content, file: #9MQT")
    local input = "--- \"a\n...x\nb\"\n"
    local tree = "\"a ...x b\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiline double quoted flow mapping key, file: #9SA2, tags: #double #flow #mapping", function()
  print("### should parse the Multiline double quoted flow mapping key, file: #9SA2")
    local input = "---\n- { \"single line\": value}\n- { \"multi\n  line\": value}\n"
    local tree = "[\n  {\n    \"single line\": \"value\"\n  },\n  {\n    \"multi line\": \"value\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 5.8. Quoted Scalar Indicators, file: #9SHH, tags: #spec #scalar", function()
  print("### should parse the Spec Example 5.8. Quoted Scalar Indicators, file: #9SHH")
    local input = "single: \'text\'\ndouble: \"text\"\n"
    local tree = "{\n  \"single\": \"text\",\n  \"double\": \"text\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.6. Double Quoted Lines [1.3], file: #9TFX, tags: #double #spec #scalar #whitespace #1.3-mod", function()
  print("### should parse the Spec Example 7.6. Double Quoted Lines [1.3], file: #9TFX")
    local input = "---\n\" 1st non-empty\n\n 2nd non-empty \n 3rd non-empty \"\n"
    local tree = "\" 1st non-empty\\n2nd non-empty 3rd non-empty \"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.12. Compact Nested Mapping, file: #9U5K, tags: #spec #mapping #sequence", function()
  print("### should parse the Spec Example 2.12. Compact Nested Mapping, file: #9U5K")
    local input = "---\n# Products purchased\n- item    : Super Hoop\n  quantity: 1\n- item    : Basketball\n  quantity: 4\n- item    : Big Shoes\n  quantity: 1\n"
    local tree = "[\n  {\n    \"item\": \"Super Hoop\",\n    \"quantity\": 1\n  },\n  {\n    \"item\": \"Basketball\",\n    \"quantity\": 4\n  },\n  {\n    \"item\": \"Big Shoes\",\n    \"quantity\": 1\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.18. Primary Tag Handle, file: #9WXW, tags: #local-tag #spec #directive #tag #unknown-tag #1.3-err", function()
  print("### should parse the Spec Example 6.18. Primary Tag Handle, file: #9WXW")
    local input = "# Private\n!foo \"bar\"\n...\n# Global\n%TAG ! tag:example.com,2000:app/\n---\n!foo \"bar\"\n"
    local tree = "\"bar\"\n\"bar\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiline Scalar at Top Level, file: #9YRD, tags: #scalar #whitespace #1.3-err", function()
  print("### should parse the Multiline Scalar at Top Level, file: #9YRD")
    local input = "a\nb  \n  c\nd\n\ne\n"
    local tree = "\"a b c d\\ne\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.2. Indentation Indicators, file: #A2M4, tags: #explicit-key #spec #libyaml-err #indent #whitespace #sequence #upto-1.2", function()
  print("### should parse the Spec Example 6.2. Indentation Indicators, file: #A2M4")
    local input = "? a\n: -	b\n  -  -		c\n     - d\n"
    local tree = "{\n  \"a\": [\n    \"b\",\n    [\n      \"c\",\n      \"d\"\n    ]\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.4. Chomping Final Line Break, file: #A6F9, tags: #spec #literal #scalar", function()
  print("### should parse the Spec Example 8.4. Chomping Final Line Break, file: #A6F9")
    local input = "strip: |-\n  text\nclip: |\n  text\nkeep: |+\n  text\n"
    local tree = "{\n  \"strip\": \"text\",\n  \"clip\": \"text\\n\",\n  \"keep\": \"text\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiline Scalar in Mapping, file: #A984, tags: #scalar", function()
  print("### should parse the Multiline Scalar in Mapping, file: #A984")
    local input = "a: b\n c\nd:\n e\n  f\n"
    local tree = "{\n  \"a\": \"b c\",\n  \"d\": \"e f\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Sequence entry that looks like two with wrong indentation, file: #AB8U, tags: #scalar #sequence", function()
  print("### should parse the Sequence entry that looks like two with wrong indentation, file: #AB8U")
    local input = "- single multiline\n - sequence entry\n"
    local tree = "[\n  \"single multiline - sequence entry\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Empty Stream, file: #AVM7, tags: #edge", function()
  print("### should parse the Empty Stream, file: #AVM7")
    local input = "\n"
    local tree = ""
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Sequence With Same Indentation as Parent Mapping, file: #AZ63, tags: #indent #mapping #sequence", function()
  print("### should parse the Sequence With Same Indentation as Parent Mapping, file: #AZ63")
    local input = "one:\n- 2\n- 3\nfour: 5\n"
    local tree = "{\n  \"one\": [\n    2,\n    3\n  ],\n  \"four\": 5\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Lookahead test cases, file: #AZW3, tags: #mapping #edge", function()
  print("### should parse the Lookahead test cases, file: #AZW3")
    local input = "- bla\"keks: foo\n- bla]keks: foo\n"
    local tree = "[\n  {\n    \"bla\\\"keks\": \"foo\"\n  },\n  {\n    \"bla]keks\": \"foo\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.9. Folded Scalar [1.3], file: #B3HG, tags: #spec #folded #scalar #1.3-mod", function()
  print("### should parse the Spec Example 8.9. Folded Scalar [1.3], file: #B3HG")
    local input = "--- >\n folded\n text\n\n\n\n\n"
    local tree = "\"folded text\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.14. “YAML” directive, file: #BEC7, tags: #spec #directive", function()
  print("### should parse the Spec Example 6.14. “YAML” directive, file: #BEC7")
    local input = "%YAML 1.3 # Attempt parsing\n          # with a warning\n---\n\"foo\"\n"
    local tree = "\"foo\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Node Anchor and Tag on Seperate Lines, file: #BU8L, tags: #anchor #indent #1.3-err #tag", function()
  print("### should parse the Node Anchor and Tag on Seperate Lines, file: #BU8L")
    local input = "key: &anchor\n !!map\n  a: b\n"
    local tree = "{\n  \"key\": {\n    \"a\": \"b\"\n  }\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.18. Flow Mapping Adjacent Values, file: #C2DT, tags: #spec #flow #mapping", function()
  print("### should parse the Spec Example 7.18. Flow Mapping Adjacent Values, file: #C2DT")
    local input = "{\n\"adjacent\":value,\n\"readable\": value,\n\"empty\":\n}\n"
    local tree = "{\n  \"adjacent\": \"value\",\n  \"readable\": \"value\",\n  \"empty\": null\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.24. Global Tags, file: #C4HZ, tags: #spec #tag #alias #directive #local-tag", function()
  print("### should parse the Spec Example 2.24. Global Tags, file: #C4HZ")
    local input = "%TAG ! tag:clarkevans.com,2002:\n--- !shape\n  # Use the ! handle for presenting\n  # tag:clarkevans.com,2002:circle\n- !circle\n  center: &ORIGIN {x: 73, y: 129}\n  radius: 7\n- !line\n  start: *ORIGIN\n  finish: { x: 89, y: 102 }\n- !label\n  start: *ORIGIN\n  color: 0xFFEEBB\n  text: Pretty vector drawing.\n"
    local tree = "[\n  {\n    \"center\": {\n      \"x\": 73,\n      \"y\": 129\n    },\n    \"radius\": 7\n  },\n  {\n    \"start\": {\n      \"x\": 73,\n      \"y\": 129\n    },\n    \"finish\": {\n      \"x\": 89,\n      \"y\": 102\n    }\n  },\n  {\n    \"start\": {\n      \"x\": 73,\n      \"y\": 129\n    },\n    \"color\": 16772795,\n    \"text\": \"Pretty vector drawing.\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.20. Tag Handles, file: #CC74, tags: #spec #directive #tag #unknown-tag", function()
  print("### should parse the Spec Example 6.20. Tag Handles, file: #CC74")
    local input = "%TAG !e! tag:example.com,2000:app/\n---\n!e!foo \"bar\"\n"
    local tree = "\"bar\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Various location of anchors in flow sequence, file: #CN3R, tags: #anchor #flow #mapping #sequence", function()
  print("### should parse the Various location of anchors in flow sequence, file: #CN3R")
    local input = "&flowseq [\n a: b,\n &c c: d,\n { &e e: f },\n &g { g: h }\n]\n"
    local tree = "[\n  {\n    \"a\": \"b\"\n  },\n  {\n    \"c\": \"d\"\n  },\n  {\n    \"e\": \"f\"\n  },\n  {\n    \"g\": \"h\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Doublequoted scalar starting with a tab, file: #CPZ3, tags: #double #scalar", function()
  print("### should parse the Doublequoted scalar starting with a tab, file: #CPZ3")
    local input = "---\ntab: \"\\tstring\"\n"
    local tree = "{\n  \"tab\": \"\\tstring\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.20. Single Pair Explicit Entry, file: #CT4Q, tags: #explicit-key #spec #flow #mapping", function()
  print("### should parse the Spec Example 7.20. Single Pair Explicit Entry, file: #CT4Q")
    local input = "[\n? foo\n bar : baz\n]\n"
    local tree = "[\n  {\n    \"foo bar\": \"baz\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 5.6. Node Property Indicators, file: #CUP7, tags: #local-tag #spec #tag #alias", function()
  print("### should parse the Spec Example 5.6. Node Property Indicators, file: #CUP7")
    local input = "anchored: !local &anchor value\nalias: *anchor\n"
    local tree = "{\n  \"anchored\": \"value\",\n  \"alias\": \"value\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Block scalar indicator order, file: #D83L, tags: #indent #literal", function()
  print("### should parse the Block scalar indicator order, file: #D83L")
    local input = "- |2-\n  explicit indent and chomp\n- |-2\n  chomp and explicit indent\n"
    local tree = "[\n  \"explicit indent and chomp\",\n  \"chomp and explicit indent\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Flow Sequence in Block Mapping, file: #D88J, tags: #flow #sequence #mapping", function()
  print("### should parse the Flow Sequence in Block Mapping, file: #D88J")
    local input = "a: [b, c]\n"
    local tree = "{\n  \"a\": [\n    \"b\",\n    \"c\"\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Single Pair Block Mapping, file: #D9TU, tags: #simple #mapping", function()
  print("### should parse the Single Pair Block Mapping, file: #D9TU")
    local input = "foo: bar\n"
    local tree = "{\n  \"foo\": \"bar\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.10. Plain Characters, file: #DBG4, tags: #spec #flow #sequence #scalar", function()
  print("### should parse the Spec Example 7.10. Plain Characters, file: #DBG4")
    local input = "# Outside flow collection:\n- ::vector\n- \": - ()\"\n- Up, up, and away!\n- -123\n- http://example.com/foo#bar\n# Inside flow collection:\n- [ ::vector,\n  \": - ()\",\n  \"Up, up and away!\",\n  -123,\n  http://example.com/foo#bar ]\n"
    local tree = "[\n  \"::vector\",\n  \": - ()\",\n  \"Up, up, and away!\",\n  -123,\n  \"http://example.com/foo#bar\",\n  [\n    \"::vector\",\n    \": - ()\",\n    \"Up, up and away!\",\n    -123,\n    \"http://example.com/foo#bar\"\n  ]\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Various trailing tabs, file: #DC7X, tags: #comment #whitespace", function()
  print("### should parse the Various trailing tabs, file: #DC7X")
    local input = "a: b				\nseq:				\n - a				\nc: d				#X\n"
    local tree = "{\n  \"a\": \"b\",\n  \"seq\": [\n    \"a\"\n  ],\n  \"c\": \"d\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Trailing tabs in double quoted, file: #DE56, tags: #double #whitespace", function()
  print("### should parse the Trailing tabs in double quoted, file: #DE56")
    local input = "\"1 trailing\\t\n    tab\"\n"
    local tree = "\"1 trailing\\t tab\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Flow Sequence, file: #DHP8, tags: #flow #sequence", function()
  print("### should parse the Flow Sequence, file: #DHP8")
    local input = "[foo, bar, 42]\n"
    local tree = "[\n  \"foo\",\n  \"bar\",\n  42\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Zero indented block scalar with line that looks like a comment, file: #DK3J, tags: #comment #folded #scalar", function()
  print("### should parse the Zero indented block scalar with line that looks like a comment, file: #DK3J")
    local input = "--- >\nline1\n# no comment\nline3\n"
    local tree = "\"line1 # no comment line3\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Tabs that look like indentation, file: #DK95, tags: #indent #whitespace", function()
  print("### should parse the Tabs that look like indentation, file: #DK95")
    local input = "foo:\n 				bar\n"
    local tree = "{\n  \"foo\" : \"bar\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.8. Literal Content, file: #DWX9, tags: #spec #literal #scalar #comment #whitespace #1.3-err", function()
  print("### should parse the Spec Example 8.8. Literal Content, file: #DWX9")
    local input = "|\n \n  \n  literal\n   \n  \n  text\n\n # Comment\n"
    local tree = "\"\\n\\nliteral\\n \\n\\ntext\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Aliases in Implicit Block Mapping, file: #E76Z, tags: #mapping #alias", function()
  print("### should parse the Aliases in Implicit Block Mapping, file: #E76Z")
    local input = "&a a: &b b\n*b : *a\n"
    local tree = "{\n  \"a\": \"b\",\n  \"b\": \"a\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Tags for Flow Objects, file: #EHF6, tags: #tag #flow #mapping #sequence", function()
  print("### should parse the Tags for Flow Objects, file: #EHF6")
    local input = "!!map {\n  k: !!seq\n  [ a, !!str b]\n}\n"
    local tree = "{\n  \"k\": [\n    \"a\",\n    \"b\"\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiline Scalar at Top Level [1.3], file: #EX5H, tags: #scalar #whitespace #1.3-mod", function()
  print("### should parse the Multiline Scalar at Top Level [1.3], file: #EX5H")
    local input = "---\na\nb  \n  c\nd\n\ne\n"
    local tree = "\"a b c d\\ne\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Three dashes and content without space [1.3], file: #EXG3, tags: #scalar #1.3-mod", function()
  print("### should parse the Three dashes and content without space [1.3], file: #EXG3")
    local input = "---\n---word1\nword2\n"
    local tree = "\"---word1 word2\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Anchors and Tags, file: #F2C7, tags: #anchor #tag", function()
  print("### should parse the Anchors and Tags, file: #F2C7")
    local input = " - &a !!str a\n - !!int 2\n - !!int &c 4\n - &d d\n"
    local tree = "[\n  \"a\",\n  2,\n  4,\n  \"d\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Nested flow collections on one line, file: #F3CP, tags: #flow #mapping #sequence", function()
  print("### should parse the Nested flow collections on one line, file: #F3CP")
    local input = "---\n{ a: [b, c, { d: [e, f] } ] }\n"
    local tree = "{\n  \"a\": [\n    \"b\",\n    \"c\",\n    {\n      \"d\": [\n        \"e\",\n        \"f\"\n      ]\n    }\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the More indented lines at the beginning of folded block scalars, file: #F6MC, tags: #folded #indent", function()
  print("### should parse the More indented lines at the beginning of folded block scalars, file: #F6MC")
    local input = "---\na: >2\n   more indented\n  regular\nb: >2\n\n\n   more indented\n  regular\n"
    local tree = "{\n  \"a\": \" more indented\\nregular\\n\",\n  \"b\": \"\\n\\n more indented\\nregular\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.5. Chomping Trailing Lines, file: #F8F9, tags: #spec #literal #scalar #comment", function()
  print("### should parse the Spec Example 8.5. Chomping Trailing Lines, file: #F8F9")
    local input = " # Strip\n  # Comments:\nstrip: |-\n  # text\n  \n # Clip\n  # comments:\n\nclip: |\n  # text\n \n # Keep\n  # comments:\n\nkeep: |+\n  # text\n\n # Trail\n  # comments.\n"
    local tree = "{\n  \"strip\": \"# text\",\n  \"clip\": \"# text\\n\",\n  \"keep\": \"# text\\n\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Allowed characters in plain scalars, file: #FBC9, tags: #scalar", function()
  print("### should parse the Allowed characters in plain scalars, file: #FBC9")
    local input = "safe: a!\"#$%&\'()*+,-./09:;<=>?@AZ[\\]^_`az{|}~\n     !\"#$%&\'()*+,-./09:;<=>?@AZ[\\]^_`az{|}~\nsafe question mark: ?foo\nsafe colon: :foo\nsafe dash: -foo\n"
    local tree = "{\n  \"safe\": \"a!\\\"#$%&\'()*+,-./09:;<=>?@AZ[\\\\]^_`az{|}~ !\\\"#$%&\'()*+,-./09:;<=>?@AZ[\\\\]^_`az{|}~\",\n  \"safe question mark\": \"?foo\",\n  \"safe colon\": \":foo\",\n  \"safe dash\": \"-foo\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Zero indented block scalar, file: #FP8R, tags: #folded #indent #scalar", function()
  print("### should parse the Zero indented block scalar, file: #FP8R")
    local input = "--- >\nline1\nline2\nline3\n"
    local tree = "\"line1 line2 line3\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.1. Sequence of Scalars, file: #FQ7F, tags: #spec #sequence", function()
  print("### should parse the Spec Example 2.1. Sequence of Scalars, file: #FQ7F")
    local input = "- Mark McGwire\n- Sammy Sosa\n- Ken Griffey\n"
    local tree = "[\n  \"Mark McGwire\",\n  \"Sammy Sosa\",\n  \"Ken Griffey\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Single block sequence with anchor and explicit document start, file: #FTA2, tags: #anchor #header #sequence", function()
  print("### should parse the Single block sequence with anchor and explicit document start, file: #FTA2")
    local input = "--- &sequence\n- a\n"
    local tree = "[\n  \"a\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Flow Sequence in Flow Sequence, file: #FUP4, tags: #sequence #flow", function()
  print("### should parse the Flow Sequence in Flow Sequence, file: #FUP4")
    local input = "[a, [b, c]]\n"
    local tree = "[\n  \"a\",\n  [\n    \"b\",\n    \"c\"\n  ]\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.17. Quoted Scalars, file: #G4RS, tags: #spec #scalar", function()
  print("### should parse the Spec Example 2.17. Quoted Scalars, file: #G4RS")
    local input = "unicode: \"Sosa did fine.\\u263A\"\ncontrol: \"\\b1998\\t1999\\t2000\\n\"\nhex esc: \"\\x0d\\x0a is \\r\\n\"\n\nsingle: \'\"Howdy!\" he cried.\'\nquoted: \' # Not a \'\'comment\'\'.\'\ntie-fighter: \'|\\-*-/|\'\n"
    local tree = "{\n  \"unicode\": \"Sosa did fine.☺\",\n  \"control\": \"\\b1998\\t1999\\t2000\\n\",\n  \"hex esc\": \"\\r\\n is \\r\\n\",\n  \"single\": \"\\\"Howdy!\\\" he cried.\",\n  \"quoted\": \" # Not a \'comment\'.\",\n  \"tie-fighter\": \"|\\\\-*-/|\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.9. Folded Scalar, file: #G992, tags: #spec #folded #scalar #1.3-err", function()
  print("### should parse the Spec Example 8.9. Folded Scalar, file: #G992")
    local input = ">\n folded\n text\n\n\n\n\n"
    local tree = "\"folded text\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Mixed Block Mapping (explicit to implicit), file: #GH63, tags: #explicit-key #mapping", function()
  print("### should parse the Mixed Block Mapping (explicit to implicit), file: #GH63")
    local input = "? a\n: 1.3\nfifteen: d\n"
    local tree = "{\n  \"a\": 1.3,\n  \"fifteen\": \"d\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Blank lines, file: #H2RW, tags: #comment #literal #scalar #whitespace", function()
  print("### should parse the Blank lines, file: #H2RW")
    local input = "foo: 1\n\nbar: 2\n    \ntext: |\n  a\n    \n  b\n\n  c\n \n  d\n"
    local tree = "{\n  \"foo\": 1,\n  \"bar\": 2,\n  \"text\": \"a\\n  \\nb\\n\\nc\\n\\nd\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Literal unicode, file: #H3Z8, tags: #scalar", function()
  print("### should parse the Literal unicode, file: #H3Z8")
    local input = "---\nwanted: love ♥ and peace ☮\n"
    local tree = "{\n  \"wanted\": \"love ♥ and peace ☮\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Scalars in flow start with syntax char, file: #HM87, tags: #flow #scalar", function()
  print("### should parse the Scalars in flow start with syntax char, file: #HM87")
    local input = "[:x]\n"
    local tree = "[\n  \":x\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.16. Indentation determines scope, file: #HMK4, tags: #spec #folded #literal", function()
  print("### should parse the Spec Example 2.16. Indentation determines scope, file: #HMK4")
    local input = "name: Mark McGwire\naccomplishment: >\n  Mark set a major league\n  home run record in 1998.\nstats: |\n  65 Home Runs\n  0.278 Batting Average\n"
    local tree = "{\n  \"name\": \"Mark McGwire\",\n  \"accomplishment\": \"Mark set a major league home run record in 1998.\\n\",\n  \"stats\": \"65 Home Runs\\n0.278 Batting Average\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.23. Node Properties, file: #HMQ5, tags: #spec #tag #alias", function()
  print("### should parse the Spec Example 6.23. Node Properties, file: #HMQ5")
    local input = "!!str &a1 \"foo\":\n  !!str bar\n&a2 baz : *a1\n"
    local tree = "{\n  \"foo\": \"bar\",\n  \"baz\": \"foo\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.12. Plain Lines, file: #HS5T, tags: #spec #scalar #whitespace #upto-1.2", function()
  print("### should parse the Spec Example 7.12. Plain Lines, file: #HS5T")
    local input = "1st non-empty\n\n 2nd non-empty \n				3rd non-empty\n"
    local tree = "\"1st non-empty\\n2nd non-empty 3rd non-empty\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Document-end marker, file: #HWV9, tags: #footer", function()
  print("### should parse the Document-end marker, file: #HWV9")
    local input = "...\n"
    local tree = ""
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 5.12. Tabs and Spaces, file: #J3BT, tags: #spec #whitespace #upto-1.2", function()
  print("### should parse the Spec Example 5.12. Tabs and Spaces, file: #J3BT")
    local input = "# Tabs and spaces\nquoted: \"Quoted 				\"\nblock:		|\n  void main() {\n  		printf(\"Hello, world!\\n\");\n  }\n"
    local tree = "{\n  \"quoted\": \"Quoted \\t\",\n  \"block\": \"void main() {\\n\\tprintf(\\\"Hello, world!\\\\n\\\");\\n}\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiple Pair Block Mapping, file: #J5UC, tags: #mapping", function()
  print("### should parse the Multiple Pair Block Mapping, file: #J5UC")
    local input = "foo: blue\nbar: arrr\nbaz: jazz\n"
    local tree = "{\n  \"foo\": \"blue\",\n  \"bar\": \"arrr\",\n  \"baz\": \"jazz\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.26. Ordered Mappings, file: #J7PZ, tags: #spec #mapping #tag #unknown-tag", function()
  print("### should parse the Spec Example 2.26. Ordered Mappings, file: #J7PZ")
    local input = "# The !!omap tag is one of the optional types\n# introduced for YAML 1.1. In 1.2, it is not\n# part of the standard tags and should not be\n# enabled by default.\n# Ordered maps are represented as\n# A sequence of mappings, with\n# each mapping having one key\n--- !!omap\n- Mark McGwire: 65\n- Sammy Sosa: 63\n- Ken Griffy: 58\n"
    local tree = "[\n  {\n    \"Mark McGwire\": 65\n  },\n  {\n    \"Sammy Sosa\": 63\n  },\n  {\n    \"Ken Griffy\": 58\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Empty Lines Between Mapping Elements, file: #J7VC, tags: #whitespace #mapping", function()
  print("### should parse the Empty Lines Between Mapping Elements, file: #J7VC")
    local input = "one: 2\n\n\nthree: 4\n"
    local tree = "{\n  \"one\": 2,\n  \"three\": 4\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.9. Single Document with Two Comments, file: #J9HZ, tags: #mapping #sequence #spec #comment", function()
  print("### should parse the Spec Example 2.9. Single Document with Two Comments, file: #J9HZ")
    local input = "---\nhr: # 1998 hr ranking\n  - Mark McGwire\n  - Sammy Sosa\nrbi:\n  # 1998 rbi ranking\n  - Sammy Sosa\n  - Ken Griffey\n"
    local tree = "{\n  \"hr\": [\n    \"Mark McGwire\",\n    \"Sammy Sosa\"\n  ],\n  \"rbi\": [\n    \"Sammy Sosa\",\n    \"Ken Griffey\"\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Trailing whitespace in streams, file: #JEF9, tags: #literal", function()
  print("### should parse the Trailing whitespace in streams, file: #JEF9")
    local input = "- |+\n\n\n\n\n"
    local tree = "[\n  \"\\n\\n\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.7. Two Documents in a Stream, file: #JHB9, tags: #spec #header", function()
  print("### should parse the Spec Example 2.7. Two Documents in a Stream, file: #JHB9")
    local input = "# Ranking of 1998 home runs\n---\n- Mark McGwire\n- Sammy Sosa\n- Ken Griffey\n\n# Team ranking\n---\n- Chicago Cubs\n- St Louis Cardinals\n"
    local tree = "[\n  \"Mark McGwire\",\n  \"Sammy Sosa\",\n  \"Ken Griffey\"\n]\n[\n  \"Chicago Cubs\",\n  \"St Louis Cardinals\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.14. Block Sequence, file: #JQ4R, tags: #mapping #spec #sequence", function()
  print("### should parse the Spec Example 8.14. Block Sequence, file: #JQ4R")
    local input = "block sequence:\n  - one\n  - two : three\n"
    local tree = "{\n  \"block sequence\": [\n    \"one\",\n    {\n      \"two\": \"three\"\n    }\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Question marks in scalars, file: #JR7V, tags: #flow #scalar", function()
  print("### should parse the Question marks in scalars, file: #JR7V")
    local input = "- a?string\n- another ? string\n- key: value?\n- [a?string]\n- [another ? string]\n- {key: value? }\n- {key: value?}\n- {key?: value }\n"
    local tree = "[\n  \"a?string\",\n  \"another ? string\",\n  {\n    \"key\": \"value?\"\n  },\n  [\n    \"a?string\"\n  ],\n  [\n    \"another ? string\"\n  ],\n  {\n    \"key\": \"value?\"\n  },\n  {\n    \"key\": \"value?\"\n  },\n  {\n    \"key?\": \"value\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.29. Node Anchors, file: #JS2J, tags: #spec #alias", function()
  print("### should parse the Spec Example 6.29. Node Anchors, file: #JS2J")
    local input = "First occurrence: &anchor Value\nSecond occurrence: *anchor\n"
    local tree = "{\n  \"First occurrence\": \"Value\",\n  \"Second occurrence\": \"Value\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Block Mapping with Multiline Scalars, file: #JTV5, tags: #explicit-key #mapping #scalar", function()
  print("### should parse the Block Mapping with Multiline Scalars, file: #JTV5")
    local input = "? a\n  true\n: null\n  d\n? e\n  42\n"
    local tree = "{\n  \"a true\": \"null d\",\n  \"e 42\": null\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Colon and adjacent value after comment on next line, file: #K3WX, tags: #comment #flow #mapping", function()
  print("### should parse the Colon and adjacent value after comment on next line, file: #K3WX")
    local input = "---\n{ \"foo\" # comment\n  :bar }\n"
    local tree = "{\n  \"foo\": \"bar\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiple Entry Block Sequence, file: #K4SU, tags: #sequence", function()
  print("### should parse the Multiple Entry Block Sequence, file: #K4SU")
    local input = "- foo\n- bar\n- 42\n"
    local tree = "[\n  \"foo\",\n  \"bar\",\n  42\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.6. Line Folding, file: #K527, tags: #folded #spec #whitespace #scalar #1.3-err", function()
  print("### should parse the Spec Example 6.6. Line Folding, file: #K527")
    local input = ">-\n  trimmed\n  \n \n\n  as\n  space\n"
    local tree = "\"trimmed\\n\\n\\nas space\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Tab after document header, file: #K54U, tags: #header #whitespace", function()
  print("### should parse the Tab after document header, file: #K54U")
    local input = "---	scalar\n"
    local tree = "\"scalar\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.6. Empty Scalar Chomping, file: #K858, tags: #spec #folded #literal #whitespace", function()
  print("### should parse the Spec Example 8.6. Empty Scalar Chomping, file: #K858")
    local input = "strip: >-\n\nclip: >\n\nkeep: |+\n\n\n"
    local tree = "{\n  \"strip\": \"\",\n  \"clip\": \"\",\n  \"keep\": \"\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Inline tabs in double quoted, file: #KH5V, tags: #double #whitespace", function()
  print("### should parse the Inline tabs in double quoted, file: #KH5V")
    local input = "\"1 inline\\ttab\"\n"
    local tree = "\"1 inline\\ttab\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Block Submapping, file: #KMK3, tags: #mapping", function()
  print("### should parse the Block Submapping, file: #KMK3")
    local input = "foo:\n  bar: 1\nbaz: 2\n"
    local tree = "{\n  \"foo\": {\n    \"bar\": 1\n  },\n  \"baz\": 2\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Scalars on --- line, file: #KSS4, tags: #anchor #header #scalar #1.3-err", function()
  print("### should parse the Scalars on --- line, file: #KSS4")
    local input = "--- \"quoted\nstring\"\n--- &node foo\n"
    local tree = "\"quoted string\"\n\"foo\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Trailing line of spaces, file: #L24T, tags: #whitespace", function()
  print("### should parse the Trailing line of spaces, file: #L24T")
    local input = "foo: |\n  x\n   \n"
    local tree = "{\n  \"foo\" : \"x\\n \\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Two scalar docs with trailing comments, file: #L383, tags: #comment", function()
  print("### should parse the Two scalar docs with trailing comments, file: #L383")
    local input = "--- foo  # comment\n--- foo  # comment\n"
    local tree = "\"foo\"\n\"foo\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Tags in Explicit Mapping, file: #L94M, tags: #explicit-key #tag #mapping", function()
  print("### should parse the Tags in Explicit Mapping, file: #L94M")
    local input = "? !!str a\n: !!int 47\n? c\n: !!str d\n"
    local tree = "{\n  \"a\": 47,\n  \"c\": \"d\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.11. Plain Implicit Keys, file: #L9U5, tags: #spec #flow #mapping", function()
  print("### should parse the Spec Example 7.11. Plain Implicit Keys, file: #L9U5")
    local input = "implicit block key : [\n  implicit flow key : value,\n ]\n"
    local tree = "{\n  \"implicit block key\": [\n    {\n      \"implicit flow key\": \"value\"\n    }\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.24. Flow Nodes, file: #LE5A, tags: #spec #tag #alias", function()
  print("### should parse the Spec Example 7.24. Flow Nodes, file: #LE5A")
    local input = "- !!str \"a\"\n- \'b\'\n- &anchor \"c\"\n- *anchor\n- !!str\n"
    local tree = "[\n  \"a\",\n  \"b\",\n  \"c\",\n  \"c\",\n  \"\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Whitespace After Scalars in Flow, file: #LP6E, tags: #flow #scalar #whitespace", function()
  print("### should parse the Whitespace After Scalars in Flow, file: #LP6E")
    local input = "- [a, b , c ]\n- { \"a\"  : b\n   , c : \'d\' ,\n   e   : \"f\"\n  }\n- [      ]\n"
    local tree = "[\n  [\n    \"a\",\n    \"b\",\n    \"c\"\n  ],\n  {\n    \"a\": \"b\",\n    \"c\": \"d\",\n    \"e\": \"f\"\n  },\n  []\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.4. Double Quoted Implicit Keys, file: #LQZ7, tags: #spec #scalar #flow", function()
  print("### should parse the Spec Example 7.4. Double Quoted Implicit Keys, file: #LQZ7")
    local input = "\"implicit block key\" : [\n  \"implicit flow key\" : value,\n ]\n"
    local tree = "{\n  \"implicit block key\": [\n    {\n      \"implicit flow key\": \"value\"\n    }\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Literal Block Scalar, file: #M29M, tags: #literal #scalar #whitespace", function()
  print("### should parse the Literal Block Scalar, file: #M29M")
    local input = "a: |\n ab\n \n cd\n ef\n \n\n...\n"
    local tree = "{\n  \"a\": \"ab\\n\\ncd\\nef\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.21. Block Scalar Nodes, file: #M5C3, tags: #indent #spec #literal #folded #tag #local-tag #1.3-err", function()
  print("### should parse the Spec Example 8.21. Block Scalar Nodes, file: #M5C3")
    local input = "literal: |2\n  value\nfolded:\n   !foo\n  >1\n value\n"
    local tree = "{\n  \"literal\": \"value\\n\",\n  \"folded\": \"value\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Block sequence indentation, file: #M6YH, tags: #indent", function()
  print("### should parse the Block sequence indentation, file: #M6YH")
    local input = "- |\n x\n-\n foo: bar\n-\n - 42\n"
    local tree = "[\n  \"x\\n\",\n  {\n    \"foo\" : \"bar\"\n  },\n  [\n    42\n  ]\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 9.3. Bare Documents, file: #M7A3, tags: #spec #footer #1.3-err", function()
  print("### should parse the Spec Example 9.3. Bare Documents, file: #M7A3")
    local input = "Bare\ndocument\n...\n# No document\n...\n|\n%!PS-Adobe-2.0 # Not the first line\n"
    local tree = "\"Bare document\"\n\"%!PS-Adobe-2.0 # Not the first line\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Nested flow collections, file: #M7NX, tags: #flow #mapping #sequence", function()
  print("### should parse the Nested flow collections, file: #M7NX")
    local input = "---\n{\n a: [\n  b, c, {\n   d: [e, f]\n  }\n ]\n}\n"
    local tree = "{\n  \"a\": [\n    \"b\",\n    \"c\",\n    {\n      \"d\": [\n        \"e\",\n        \"f\"\n      ]\n    }\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.7. Literal Scalar, file: #M9B4, tags: #spec #literal #scalar #whitespace #1.3-err", function()
  print("### should parse the Spec Example 8.7. Literal Scalar, file: #M9B4")
    local input = "|\n literal\n 			text\n\n\n\n\n"
    local tree = "\"literal\\n\\ttext\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.7. Block Folding, file: #MJS9, tags: #folded #spec #scalar #whitespace #1.3-err", function()
  print("### should parse the Spec Example 6.7. Block Folding, file: #MJS9")
    local input = ">\n  foo \n \n  		 bar\n\n  baz\n"
    local tree = "\"foo \\n\\n\\t bar\\n\\nbaz\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Flow Mapping in Block Sequence, file: #MXS3, tags: #mapping #sequence #flow", function()
  print("### should parse the Flow Mapping in Block Sequence, file: #MXS3")
    local input = "- {a: b}\n"
    local tree = "[\n  {\n    \"a\": \"b\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Block Scalar Strip, file: #MYW6, tags: #literal #scalar #whitespace #1.3-err", function()
  print("### should parse the Block Scalar Strip, file: #MYW6")
    local input = "|-\n ab\n \n \n...\n"
    local tree = "\"ab\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Non-Specific Tags on Scalars, file: #MZX3, tags: #folded #scalar", function()
  print("### should parse the Non-Specific Tags on Scalars, file: #MZX3")
    local input = "- plain\n- \"double quoted\"\n- \'single quoted\'\n- >\n  block\n- plain again\n"
    local tree = "[\n  \"plain\",\n  \"double quoted\",\n  \"single quoted\",\n  \"block\\n\",\n  \"plain again\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Various empty or newline only quoted strings, file: #NAT4, tags: #double #scalar #single #whitespace", function()
  print("### should parse the Various empty or newline only quoted strings, file: #NAT4")
    local input = "---\na: \'\n  \'\nb: \'  \n  \'\nc: \"\n  \"\nd: \"  \n  \"\ne: \'\n\n  \'\nf: \"\n\n  \"\ng: \'\n\n\n  \'\nh: \"\n\n\n  \"\n"
    local tree = "{\n  \"a\": \" \",\n  \"b\": \" \",\n  \"c\": \" \",\n  \"d\": \" \",\n  \"e\": \"\\n\",\n  \"f\": \"\\n\",\n  \"g\": \"\\n\\n\",\n  \"h\": \"\\n\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiline plain value with tabs on empty lines, file: #NB6Z, tags: #scalar #whitespace", function()
  print("### should parse the Multiline plain value with tabs on empty lines, file: #NB6Z")
    local input = "key:\n  value\n  with\n  		\n  tabs\n"
    local tree = "{\n  \"key\": \"value with\\ntabs\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiline plain flow mapping key, file: #NJ66, tags: #flow #mapping", function()
  print("### should parse the Multiline plain flow mapping key, file: #NJ66")
    local input = "---\n- { single line: value}\n- { multi\n  line: value}\n"
    local tree = "[\n  {\n    \"single line\": \"value\"\n  },\n  {\n    \"multi line\": \"value\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.5. Double Quoted Line Breaks, file: #NP9H, tags: #double #spec #scalar #whitespace #upto-1.2", function()
  print("### should parse the Spec Example 7.5. Double Quoted Line Breaks, file: #NP9H")
    local input = "\"folded \nto a space,	\n \nto a line feed, or 	\\\n \\ 	non-content\"\n"
    local tree = "\"folded to a space,\\nto a line feed, or \\t \\tnon-content\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.1. Block Scalar Header, file: #P2AD, tags: #spec #literal #folded #comment #scalar", function()
  print("### should parse the Spec Example 8.1. Block Scalar Header, file: #P2AD")
    local input = "- | # Empty header↓\n literal\n- >1 # Indentation indicator↓\n  folded\n- |+ # Chomping indicator↓\n keep\n\n- >1- # Both indicators↓\n  strip\n"
    local tree = "[\n  \"literal\\n\",\n  \" folded\\n\",\n  \"keep\\n\\n\",\n  \" strip\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.19. Secondary Tag Handle, file: #P76L, tags: #spec #header #tag #unknown-tag", function()
  print("### should parse the Spec Example 6.19. Secondary Tag Handle, file: #P76L")
    local input = "%TAG !! tag:example.com,2000:app/\n---\n!!int 1 - 3 # Interval, not integer\n"
    local tree = "\"1 - 3\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.11. Multi-Line Comments, file: #P94K, tags: #spec #comment", function()
  print("### should parse the Spec Example 6.11. Multi-Line Comments, file: #P94K")
    local input = "key:    # Comment\n        # lines\n  value\n\n\n\n\n"
    local tree = "{\n  \"key\": \"value\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.3. Mapping Scalars to Sequences, file: #PBJ2, tags: #spec #mapping #sequence", function()
  print("### should parse the Spec Example 2.3. Mapping Scalars to Sequences, file: #PBJ2")
    local input = "american:\n  - Boston Red Sox\n  - Detroit Tigers\n  - New York Yankees\nnational:\n  - New York Mets\n  - Chicago Cubs\n  - Atlanta Braves\n"
    local tree = "{\n  \"american\": [\n    \"Boston Red Sox\",\n    \"Detroit Tigers\",\n    \"New York Yankees\"\n  ],\n  \"national\": [\n    \"New York Mets\",\n    \"Chicago Cubs\",\n    \"Atlanta Braves\"\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.9. Single Quoted Lines, file: #PRH3, tags: #single #spec #scalar #whitespace #upto-1.2", function()
  print("### should parse the Spec Example 7.9. Single Quoted Lines, file: #PRH3")
    local input = "\' 1st non-empty\n\n 2nd non-empty \n				3rd non-empty \'\n"
    local tree = "\" 1st non-empty\\n2nd non-empty 3rd non-empty \"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Document start on last line, file: #PUW8, tags: #header", function()
  print("### should parse the Document start on last line, file: #PUW8")
    local input = "---\na: b\n---\n"
    local tree = "{\n  \"a\": \"b\"\n}\nnull\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Tab at beginning of line followed by a flow mapping, file: #Q5MG, tags: #flow #whitespace", function()
  print("### should parse the Tab at beginning of line followed by a flow mapping, file: #Q5MG")
    local input = "				{}\n"
    local tree = "{}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.23. Flow Content, file: #Q88A, tags: #spec #flow #sequence #mapping", function()
  print("### should parse the Spec Example 7.23. Flow Content, file: #Q88A")
    local input = "- [ a, b ]\n- { a: b }\n- \"a\"\n- \'b\'\n- c\n"
    local tree = "[\n  [\n    \"a\",\n    \"b\"\n  ],\n  {\n    \"a\": \"b\"\n  },\n  \"a\",\n  \"b\",\n  \"c\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.5. Double Quoted Line Breaks [1.3], file: #Q8AD, tags: #double #spec #scalar #whitespace #1.3-mod", function()
  print("### should parse the Spec Example 7.5. Double Quoted Line Breaks [1.3], file: #Q8AD")
    local input = "---\n\"folded \nto a space,\n \nto a line feed, or 	\\\n \\ 	non-content\"\n"
    local tree = "\"folded to a space,\\nto a line feed, or \\t \\tnon-content\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.19. Single Pair Flow Mappings, file: #QF4Y, tags: #spec #flow #mapping", function()
  print("### should parse the Spec Example 7.19. Single Pair Flow Mappings, file: #QF4Y")
    local input = "[\nfoo: bar\n]\n"
    local tree = "[\n  {\n    \"foo\": \"bar\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Comment and document-end marker, file: #QT73, tags: #comment #footer", function()
  print("### should parse the Comment and document-end marker, file: #QT73")
    local input = "# comment\n...\n"
    local tree = ""
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.2. Block Indentation Indicator, file: #R4YG, tags: #spec #literal #folded #scalar #whitespace #libyaml-err #upto-1.2", function()
  print("### should parse the Spec Example 8.2. Block Indentation Indicator, file: #R4YG")
    local input = "- |\n detected\n- >\n \n  \n  # detected\n- |1\n  explicit\n- >\n 			\n detected\n"
    local tree = "[\n  \"detected\\n\",\n  \"\\n\\n# detected\\n\",\n  \" explicit\\n\",\n  \"\\t\\ndetected\\n\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Nested flow mapping sequence and mappings, file: #R52L, tags: #flow #mapping #sequence", function()
  print("### should parse the Nested flow mapping sequence and mappings, file: #R52L")
    local input = "---\n{ top1: [item1, {key2: value2}, item3], top2: value2 }\n"
    local tree = "{\n  \"top1\": [\n    \"item1\",\n    {\n      \"key2\": \"value2\"\n    },\n    \"item3\"\n  ],\n  \"top2\": \"value2\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Sequence Indent, file: #RLU9, tags: #sequence #indent", function()
  print("### should parse the Sequence Indent, file: #RLU9")
    local input = "foo:\n- 42\nbar:\n  - 44\n"
    local tree = "{\n  \"foo\": [\n    42\n  ],\n  \"bar\": [\n    44\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Mixed Block Mapping (implicit to explicit), file: #RR7F, tags: #explicit-key #mapping", function()
  print("### should parse the Mixed Block Mapping (implicit to explicit), file: #RR7F")
    local input = "a: 4.2\n? d\n: 23\n"
    local tree = "{\n  \"d\": 23,\n  \"a\": 4.2\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 9.2. Document Markers, file: #RTP8, tags: #spec #header #footer", function()
  print("### should parse the Spec Example 9.2. Document Markers, file: #RTP8")
    local input = "%YAML 1.2\n---\nDocument\n... # Suffix\n"
    local tree = "\"Document\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.28. Log File, file: #RZT7, tags: #spec #header #literal #mapping #sequence", function()
  print("### should parse the Spec Example 2.28. Log File, file: #RZT7")
    local input = "---\nTime: 2001-11-23 15:01:42 -5\nUser: ed\nWarning:\n  This is an error message\n  for the log file\n---\nTime: 2001-11-23 15:02:31 -5\nUser: ed\nWarning:\n  A slightly different error\n  message.\n---\nDate: 2001-11-23 15:03:17 -5\nUser: ed\nFatal:\n  Unknown variable \"bar\"\nStack:\n  - file: TopClass.py\n    line: 23\n    code: |\n      x = MoreObject(\"345\\n\")\n  - file: MoreClass.py\n    line: 58\n    code: |-\n      foo = bar\n"
    local tree = "{\n  \"Time\": \"2001-11-23 15:01:42 -5\",\n  \"User\": \"ed\",\n  \"Warning\": \"This is an error message for the log file\"\n}\n{\n  \"Time\": \"2001-11-23 15:02:31 -5\",\n  \"User\": \"ed\",\n  \"Warning\": \"A slightly different error message.\"\n}\n{\n  \"Date\": \"2001-11-23 15:03:17 -5\",\n  \"User\": \"ed\",\n  \"Fatal\": \"Unknown variable \\\"bar\\\"\",\n  \"Stack\": [\n    {\n      \"file\": \"TopClass.py\",\n      \"line\": 23,\n      \"code\": \"x = MoreObject(\\\"345\\\\n\\\")\\n\"\n    },\n    {\n      \"file\": \"MoreClass.py\",\n      \"line\": 58,\n      \"code\": \"foo = bar\"\n    }\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.28. Non-Specific Tags, file: #S4JQ, tags: #spec #tag", function()
  print("### should parse the Spec Example 6.28. Non-Specific Tags, file: #S4JQ")
    local input = "# Assuming conventional resolution:\n- \"12\"\n- 12\n- ! 12\n"
    local tree = "[\n  \"12\",\n  12,\n  \"12\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Document with footer, file: #S4T7, tags: #mapping #footer", function()
  print("### should parse the Document with footer, file: #S4T7")
    local input = "aaa: bbb\n...\n"
    local tree = "{\n  \"aaa\": \"bbb\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Colon followed by comma, file: #S7BG, tags: #scalar", function()
  print("### should parse the Colon followed by comma, file: #S7BG")
    local input = "---\n- :,\n"
    local tree = "[\n  \":,\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 5.3. Block Structure Indicators, file: #S9E8, tags: #explicit-key #spec #mapping #sequence", function()
  print("### should parse the Spec Example 5.3. Block Structure Indicators, file: #S9E8")
    local input = "sequence:\n- one\n- two\nmapping:\n  ? sky\n  : blue\n  sea : green\n"
    local tree = "{\n  \"sequence\": [\n    \"one\",\n    \"two\"\n  ],\n  \"mapping\": {\n    \"sky\": \"blue\",\n    \"sea\": \"green\"\n  }\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Anchor before zero indented sequence, file: #SKE5, tags: #anchor #indent #sequence", function()
  print("### should parse the Anchor before zero indented sequence, file: #SKE5")
    local input = "---\nseq:\n &anchor\n- a\n- b\n"
    local tree = "{\n  \"seq\": [\n    \"a\",\n    \"b\"\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Single character streams, file: #SM9W, tags: #sequence", function()
  print("### should parse the Single character streams, file: #SM9W")
    local input = "-\n"
    local tree = "[null]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.7. Single Quoted Characters [1.3], file: #SSW6, tags: #spec #scalar #single #1.3-mod", function()
  print("### should parse the Spec Example 7.7. Single Quoted Characters [1.3], file: #SSW6")
    local input = "---\n\'here\'\'s to \"quotes\"\'\n"
    local tree = "\"here\'s to \\\"quotes\\\"\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.2. Mapping Scalars to Scalars, file: #SYW4, tags: #spec #scalar #comment", function()
  print("### should parse the Spec Example 2.2. Mapping Scalars to Scalars, file: #SYW4")
    local input = "hr:  65    # Home runs\navg: 0.278 # Batting average\nrbi: 147   # Runs Batted In\n"
    local tree = "{\n  \"hr\": 65,\n  \"avg\": 0.278,\n  \"rbi\": 147\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.8. Literal Content [1.3], file: #T26H, tags: #spec #literal #scalar #comment #whitespace #1.3-mod", function()
  print("### should parse the Spec Example 8.8. Literal Content [1.3], file: #T26H")
    local input = "--- |\n \n  \n  literal\n   \n  \n  text\n\n # Comment\n"
    local tree = "\"\\n\\nliteral\\n \\n\\ntext\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.9. Single Quoted Lines [1.3], file: #T4YY, tags: #single #spec #scalar #whitespace #1.3-mod", function()
  print("### should parse the Spec Example 7.9. Single Quoted Lines [1.3], file: #T4YY")
    local input = "---\n\' 1st non-empty\n\n 2nd non-empty \n 3rd non-empty \'\n"
    local tree = "\" 1st non-empty\\n2nd non-empty 3rd non-empty \"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.7. Literal Scalar [1.3], file: #T5N4, tags: #spec #literal #scalar #whitespace #1.3-mod", function()
  print("### should parse the Spec Example 8.7. Literal Scalar [1.3], file: #T5N4")
    local input = "--- |\n literal\n 			text\n\n\n\n\n"
    local tree = "\"literal\\n\\ttext\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.16. Block Mappings, file: #TE2A, tags: #spec #mapping", function()
  print("### should parse the Spec Example 8.16. Block Mappings, file: #TE2A")
    local input = "block mapping:\n key: value\n"
    local tree = "{\n  \"block mapping\": {\n    \"key\": \"value\"\n  }\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.8. Flow Folding, file: #TL85, tags: #double #spec #whitespace #scalar #upto-1.2", function()
  print("### should parse the Spec Example 6.8. Flow Folding, file: #TL85")
    local input = "\"\n  foo \n \n  		 bar\n\n  baz\n\"\n"
    local tree = "\" foo\\nbar\\nbaz \"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Folded Block Scalar, file: #TS54, tags: #folded #scalar #1.3-err", function()
  print("### should parse the Folded Block Scalar, file: #TS54")
    local input = ">\n ab\n cd\n \n ef\n\n\n gh\n"
    local tree = "\"ab cd\\nef\\n\\ngh\\n\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.16. “TAG” directive, file: #U3C3, tags: #spec #header #tag", function()
  print("### should parse the Spec Example 6.16. “TAG” directive, file: #U3C3")
    local input = "%TAG !yaml! tag:yaml.org,2002:\n---\n!yaml!str \"foo\"\n"
    local tree = "\"foo\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Node and Mapping Key Anchors, file: #U3XV, tags: #anchor #comment #1.3-err", function()
  print("### should parse the Node and Mapping Key Anchors, file: #U3XV")
    local input = "---\ntop1: &node1\n  &k1 key1: one\ntop2: &node2 # comment\n  key2: two\ntop3:\n  &k3 key3: three\ntop4:\n  &node4\n  &k4 key4: four\ntop5:\n  &node5\n  key5: five\ntop6: &val6\n  six\ntop7:\n  &val7 seven\n"
    local tree = "{\n  \"top1\": {\n    \"key1\": \"one\"\n  },\n  \"top2\": {\n    \"key2\": \"two\"\n  },\n  \"top3\": {\n    \"key3\": \"three\"\n  },\n  \"top4\": {\n    \"key4\": \"four\"\n  },\n  \"top5\": {\n    \"key5\": \"five\"\n  },\n  \"top6\": \"six\",\n  \"top7\": \"seven\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.8. Play by Play Feed from a Game, file: #U9NS, tags: #spec #header", function()
  print("### should parse the Spec Example 2.8. Play by Play Feed from a Game, file: #U9NS")
    local input = "---\ntime: 20:03:20\nplayer: Sammy Sosa\naction: strike (miss)\n...\n---\ntime: 20:03:47\nplayer: Sammy Sosa\naction: grand slam\n...\n"
    local tree = "{\n  \"time\": \"20:03:20\",\n  \"player\": \"Sammy Sosa\",\n  \"action\": \"strike (miss)\"\n}\n{\n  \"time\": \"20:03:47\",\n  \"player\": \"Sammy Sosa\",\n  \"action\": \"grand slam\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Plain URL in flow mapping, file: #UDM2, tags: #flow #scalar", function()
  print("### should parse the Plain URL in flow mapping, file: #UDM2")
    local input = "- { url: http://example.org }\n"
    local tree = "[\n  {\n    \"url\": \"http://example.org\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 5.4. Flow Collection Indicators, file: #UDR7, tags: #spec #flow #sequence #mapping", function()
  print("### should parse the Spec Example 5.4. Flow Collection Indicators, file: #UDR7")
    local input = "sequence: [ one, two, ]\nmapping: { sky: blue, sea: green }\n"
    local tree = "{\n  \"sequence\": [\n    \"one\",\n    \"two\"\n  ],\n  \"mapping\": {\n    \"sky\": \"blue\",\n    \"sea\": \"green\"\n  }\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.27. Invoice, file: #UGM3, tags: #spec #tag #literal #mapping #sequence #alias #unknown-tag", function()
  print("### should parse the Spec Example 2.27. Invoice, file: #UGM3")
    local input = "--- !<tag:clarkevans.com,2002:invoice>\ninvoice: 34843\ndate   : 2001-01-23\nbill-to: &id001\n    given  : Chris\n    family : Dumars\n    address:\n        lines: |\n            458 Walkman Dr.\n            Suite #292\n        city    : Royal Oak\n        state   : MI\n        postal  : 48046\nship-to: *id001\nproduct:\n    - sku         : BL394D\n      quantity    : 4\n      description : Basketball\n      price       : 450.00\n    - sku         : BL4438H\n      quantity    : 1\n      description : Super Hoop\n      price       : 2392.00\ntax  : 251.42\ntotal: 4443.52\ncomments:\n    Late afternoon is best.\n    Backup contact is Nancy\n    Billsmer @ 338-4338.\n"
    local tree = "{\n  \"invoice\": 34843,\n  \"date\": \"2001-01-23\",\n  \"bill-to\": {\n    \"given\": \"Chris\",\n    \"family\": \"Dumars\",\n    \"address\": {\n      \"lines\": \"458 Walkman Dr.\\nSuite #292\\n\",\n      \"city\": \"Royal Oak\",\n      \"state\": \"MI\",\n      \"postal\": 48046\n    }\n  },\n  \"ship-to\": {\n    \"given\": \"Chris\",\n    \"family\": \"Dumars\",\n    \"address\": {\n      \"lines\": \"458 Walkman Dr.\\nSuite #292\\n\",\n      \"city\": \"Royal Oak\",\n      \"state\": \"MI\",\n      \"postal\": 48046\n    }\n  },\n  \"product\": [\n    {\n      \"sku\": \"BL394D\",\n      \"quantity\": 4,\n      \"description\": \"Basketball\",\n      \"price\": 450\n    },\n    {\n      \"sku\": \"BL4438H\",\n      \"quantity\": 1,\n      \"description\": \"Super Hoop\",\n      \"price\": 2392\n    }\n  ],\n  \"tax\": 251.42,\n  \"total\": 4443.52,\n  \"comments\": \"Late afternoon is best. Backup contact is Nancy Billsmer @ 338-4338.\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 9.4. Explicit Documents, file: #UT92, tags: #flow #spec #header #footer #comment", function()
  print("### should parse the Spec Example 9.4. Explicit Documents, file: #UT92")
    local input = "---\n{ matches\n% : 20 }\n...\n---\n# Empty\n...\n"
    local tree = "{\n  \"matches %\": 20\n}\nnull\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Legal tab after indentation, file: #UV7Q, tags: #indent #whitespace", function()
  print("### should parse the Legal tab after indentation, file: #UV7Q")
    local input = "x:\n - x\n  			x\n"
    local tree = "{\n  \"x\": [\n    \"x x\"\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Aliases in Block Sequence, file: #V55R, tags: #alias #sequence", function()
  print("### should parse the Aliases in Block Sequence, file: #V55R")
    local input = "- &a a\n- &b b\n- *a\n- *b\n"
    local tree = "[\n  \"a\",\n  \"b\",\n  \"a\",\n  \"b\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.15. Block Sequence Entry Types, file: #W42U, tags: #comment #spec #literal #sequence", function()
  print("### should parse the Spec Example 8.15. Block Sequence Entry Types, file: #W42U")
    local input = "- # Empty\n- |\n block node\n- - one # Compact\n  - two # sequence\n- one: two # Compact mapping\n"
    local tree = "[\n  null,\n  \"block node\\n\",\n  [\n    \"one\",\n    \"two\"\n  ],\n  {\n    \"one\": \"two\"\n  }\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 9.5. Directives Documents, file: #W4TN, tags: #spec #header #footer #1.3-err", function()
  print("### should parse the Spec Example 9.5. Directives Documents, file: #W4TN")
    local input = "%YAML 1.2\n--- |\n%!PS-Adobe-2.0\n...\n%YAML 1.2\n---\n# Empty\n...\n"
    local tree = "\"%!PS-Adobe-2.0\\n\"\nnull\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Allowed characters in alias, file: #W5VH, tags: #alias #1.3-err", function()
  print("### should parse the Allowed characters in alias, file: #W5VH")
    local input = "a: &:@*!$\"<foo>: scalar a\nb: *:@*!$\"<foo>:\n"
    local tree = "{\n  \"a\": \"scalar a\",\n  \"b\": \"scalar a\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 7.2. Empty Content, file: #WZ62, tags: #spec #flow #scalar #tag", function()
  print("### should parse the Spec Example 7.2. Empty Content, file: #WZ62")
    local input = "{\n  foo : !!str,\n  !!str : bar,\n}\n"
    local tree = "{\n  \"foo\": \"\",\n  \"\": \"bar\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Explicit key and value seperated by comment, file: #X8DW, tags: #comment #explicit-key #mapping", function()
  print("### should parse the Explicit key and value seperated by comment, file: #X8DW")
    local input = "---\n? key\n# comment\n: value\n"
    local tree = "{\n  \"key\": \"value\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Multiline scalar that looks like a YAML directive, file: #XLQ9, tags: #directive #scalar", function()
  print("### should parse the Multiline scalar that looks like a YAML directive, file: #XLQ9")
    local input = "---\nscalar\n%YAML 1.2\n"
    local tree = "\"scalar %YAML 1.2\"\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.5. Empty Lines [1.3], file: #XV9V, tags: #literal #spec #scalar #1.3-mod", function()
  print("### should parse the Spec Example 6.5. Empty Lines [1.3], file: #XV9V")
    local input = "Folding:\n  \"Empty line\n\n  as a line feed\"\nChomping: |\n  Clipped empty lines\n \n\n\n"
    local tree = "{\n  \"Folding\": \"Empty line\\nas a line feed\",\n  \"Chomping\": \"Clipped empty lines\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Anchor with colon in the middle, file: #Y2GN, tags: #anchor", function()
  print("### should parse the Anchor with colon in the middle, file: #Y2GN")
    local input = "---\nkey: &an:chor value\n"
    local tree = "{\n  \"key\": \"value\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.5. Sequence of Sequences, file: #YD5X, tags: #spec #sequence", function()
  print("### should parse the Spec Example 2.5. Sequence of Sequences, file: #YD5X")
    local input = "- [name        , hr, avg  ]\n- [Mark McGwire, 65, 0.278]\n- [Sammy Sosa  , 63, 0.288]\n"
    local tree = "[\n  [\n    \"name\",\n    \"hr\",\n    \"avg\"\n  ],\n  [\n    \"Mark McGwire\",\n    65,\n    0.278\n  ],\n  [\n    \"Sammy Sosa\",\n    63,\n    0.288\n  ]\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 8.21. Block Scalar Nodes [1.3], file: #Z67P, tags: #indent #spec #literal #folded #tag #local-tag #1.3-mod", function()
  print("### should parse the Spec Example 8.21. Block Scalar Nodes [1.3], file: #Z67P")
    local input = "literal: |2\n  value\nfolded: !foo >1\n value\n"
    local tree = "{\n  \"literal\": \"value\\n\",\n  \"folded\": \"value\\n\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 6.22. Global Tag Prefix, file: #Z9M4, tags: #spec #header #tag #unknown-tag", function()
  print("### should parse the Spec Example 6.22. Global Tag Prefix, file: #Z9M4")
    local input = "%TAG !e! tag:example.com,2000:app/\n---\n- !e!foo \"bar\"\n"
    local tree = "[\n  \"bar\"\n]\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Spec Example 2.6. Mapping of Mappings, file: #ZF4X, tags: #flow #spec #mapping", function()
  print("### should parse the Spec Example 2.6. Mapping of Mappings, file: #ZF4X")
    local input = "Mark McGwire: {hr: 65, avg: 0.278}\nSammy Sosa: {\n    hr: 63,\n    avg: 0.288\n  }\n"
    local tree = "{\n  \"Mark McGwire\": {\n    \"hr\": 65,\n    \"avg\": 0.278\n  },\n  \"Sammy Sosa\": {\n    \"hr\": 63,\n    \"avg\": 0.288\n  }\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Anchors in Mapping, file: #ZH7C, tags: #anchor #mapping", function()
  print("### should parse the Anchors in Mapping, file: #ZH7C")
    local input = "&a a: b\nc: &d d\n"
    local tree = "{\n  \"a\": \"b\",\n  \"c\": \"d\"\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Nested top level flow mapping, file: #ZK9H, tags: #flow #indent #mapping #sequence", function()
  print("### should parse the Nested top level flow mapping, file: #ZK9H")
    local input = "{ key: [[[\n  value\n ]]]\n}\n"
    local tree = "{\n  \"key\": [\n    [\n      [\n        \"value\"\n      ]\n    ]\n  ]\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Key with anchor after missing explicit mapping value, file: #ZWK4, tags: #anchor #explicit-key #mapping", function()
  print("### should parse the Key with anchor after missing explicit mapping value, file: #ZWK4")
    local input = "---\na: 1\n? b\n&anchor c: 3\n"
    local tree = "{\n  \"a\": 1,\n  \"b\": null,\n  \"c\": 3\n}\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
  it("should parse the Directive variants, file: #ZYU8, tags: #directive", function()
  print("### should parse the Directive variants, file: #ZYU8")
    local input = "%YAML1.1\n---\n"
    local tree = "null\n"
local result = yalua.decode(input)
assert.is.Same(rapidjson.decode(tree), result)
  end)
end)

