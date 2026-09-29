# loofah (spinel-loofah)

[Loofah](https://github.com/flavorjones/loofah) for Spinel. Loofah is the
HTML/XML sanitizer under rails-html-sanitizer, and so under Action View's
`sanitize` and Action Text. This is the **gem's own source**, Loofah
2.25.2, with rewrites only where Spinel cannot compile it, and every
rewrite marked `# spinel-loofah:` in place. It runs over
[spinel-nokogiri](https://github.com/rubys/spinel-nokogiri) (libxml2 and
gumbo) and [spinel-crass](../spinel-crass) (the CSS parser behind the
`style` scrubber). `require "loofah"` and the names are the gem's.

```ruby
require "loofah"

Loofah.html5_fragment("<p>hi<script>alert(1)</script></p>").scrub!(:strip).to_s
# => "<p>hi</p>"
Loofah.html5_fragment(%(<a href="http://x/">x</a>)).scrub!(:nofollow).to_s
Loofah::HTML5::Scrub.scrub_css("color: red; background: url(javascript:x)")
# => "color:red;"

span2div = Loofah::Scrubber.new { |node| node.name = "div" if node.name == "span" }
Loofah.html5_fragment("<span>x</span>").scrub!(span2div).to_s
```

## What was rewritten, and why

`git diff` against the first commit, which is the gem's `lib/` verbatim,
shows every change. There are nine:

| Where | The gem | Here | Why |
|---|---|---|---|
| `concerns.rb` | `scrub!` mixed in through Nokogiri's per-document decorators; one `case self` for Document / DocumentFragment / Node | `scrub!` defined on `Nokogiri::XML::Node`, `Document`, `DocumentFragment` and `NodeSet`, one arm each | spinel-nokogiri has no decorators, and its fragment is not a Node. Any Nokogiri node answers `scrub!` here, not only a Loofah document's |
| `concerns.rb`, `html{4,5}/document*.rb` | `ClassMethods` extended from an `included` hook | `self.parse` / `self.document_klass` on each Loofah class | `extend` from a hook |
| `concerns.rb`, `scrubbers.rb` | `Scrubbers::MAP[name].new` | `Scrubbers.named(name)`, the same table as a `case`; `MAP` is kept | `new` on a class read out of a Hash |
| `metahelpers.rb`, `elements.rb`, `html5/safelist.rb` | `mojule.constants` + `const_get` to find every Set | the Sets named in a list | `const_get` with a run-time name |
| `loofah.rb` | `html5_support?` from `Gem::Version` + `uses_gumbo?`; HTML5 methods defined only when it is true | always `true`; defined unconditionally | spinel-nokogiri carries gumbo |
| `html5/scrub.rb` | `escape_tags` with an arm for non-ASCII-compatible encodings | the ASCII-compatible arm alone | Spinel strings are UTF-8 or binary |
| `helpers.rb`, `html5/safelist.rb` | `deprecate_constant` on the `WhiteList` aliases | plain aliases | no deprecation warnings |
| `html{4,5}/document.rb` | `parse(*args, &block)` forwards to Nokogiri | `parse(string)` | see below |
| `xml/document_fragment.rb`, `html*/document_fragment.rb` | `tags.respond_to?(:encoding)` (for an IO) | `tags.encoding.name` | markup is a String |

## Known gaps

- **Markup is a String.** The gem also takes an IO. Document `parse`
  takes only the markup: no url, encoding, parse options or
  configuration block.
- **`scrub!` on any Nokogiri node.** The gem adds it only to nodes of a
  Loofah document; here every Nokogiri node has it.
- **CSS numbers beyond int64** raise `RangeError` in the `style`
  scrubber; see spinel-crass's README.

## Status

```sh
spin test          # the compiled package against the snapshots
sh oracle/run.sh   # the same programs under CRuby with the real gem
```

The corpus is **every input Loofah's own test suite passes** to its
entry points, recorded by `oracle/record.rb` while the gem's suite ran
green (1,317 runs). That is 1,008 fragments, 17 documents, 91 `style`
values and 212 URIs.

- Each fragment goes through both parsers under every built-in scrubber
  (the link and text scrubbers only on fragments that hold links,
  paragraphs or breaks), plus `text` and `to_text`.
- Each document goes through `:strip`/`:prune`, `text` and `to_text`.
- `api_test.rb` is written by hand. It covers custom scrubbers (block,
  subclass, bottom-up, `STOP`), errors, Helpers, XML and the safe lists.

All snapshots come from the gem (`sh oracle/run.sh --regen`), about 25,000
lines. None are written by hand.

**All 8 match the gem line for line** on Spinel master 1963b7732 with
spinel-nokogiri 4facdfc. The Spinel defects this corpus found, filed and
fixed upstream the same day: #5984, #5994, #5995, #5996, #6038, #6039,
and PRs #5998, #5999.
