# Loofah's API beyond the built-in scrubbers: custom scrubbers (a block,
# a subclass, bottom-up, STOP), Node and NodeSet scrub!, the scrubber
# errors, the Helpers, XML, and the safe lists' downcased members — the
# surface rails-html-sanitizer builds on. Every line is the gem's answer.
require "loofah"
require "loofah/helpers"

def guarded
  yield
rescue StandardError => e
  "!#{e.class}: #{e.message}"
end

puts "-- support"
puts Loofah.html5_support?
puts Loofah::Scrubbers.scrubber_symbols.inspect

puts "-- a block scrubber"
names = []
blk = Loofah::Scrubber.new do |node|
  names << node.name
  node.remove if node.name == "script"
end
puts blk.direction.inspect
puts Loofah.html5_fragment("<p>a<script>x</script><b>b</b></p>").scrub!(blk).to_html
puts names.inspect

puts "-- a bottom-up block scrubber"
order = []
up = Loofah::Scrubber.new(direction: :bottom_up) { |node| order << node.name }
Loofah.html5_fragment("<div><p><i>x</i></p><span>y</span></div>").scrub!(up)
puts order.inspect

puts "-- STOP ends the descent"
seen = []
stopper = Loofah::Scrubber.new do |node|
  seen << node.name
  node.name == "p" ? Loofah::Scrubber::STOP : Loofah::Scrubber::CONTINUE
end
Loofah.html5_fragment("<div><p><i>x</i></p><span><b>y</b></span></div>").scrub!(stopper)
puts seen.inspect

puts "-- a subclass scrubber"
class Shouty < Loofah::Scrubber
  def initialize
    @direction = :top_down
  end

  def scrub(node)
    return CONTINUE unless node.text?

    node.content = node.content.upcase
    CONTINUE
  end
end
puts Loofah.html5_fragment("<p>hello <b>world</b></p>").scrub!(Shouty.new).to_s

class Rel < Loofah::Scrubber
  def initialize
    @direction = :top_down
  end

  def scrub(node)
    return CONTINUE unless node.name == "a"

    append_attribute(node, "rel", "external")
    append_attribute(node, "rel", "nofollow")
    append_attribute(node, "rel", "external")
    STOP
  end
end
puts Loofah.html5_fragment('<a href="/x" rel="me">x</a><a href="/y">y</a>').scrub!(Rel.new).to_s

puts "-- scrubbers chain"
f = Loofah.html5_fragment('<a href="http://x/">x</a><script>s</script>')
puts f.scrub!(:prune).scrub!(:nofollow).scrub!(:noopener).scrub!(:targetblank).to_s

puts "-- Node and NodeSet scrub!"
doc = Loofah.html5_document("<div><p>one<script>1</script></p><p>two<script>2</script></p></div>")
doc.at_css("p").scrub!(:prune)
puts doc.at_css("div").inner_html
doc.css("p").scrub!(:escape)
puts doc.at_css("div").inner_html

puts "-- errors"
puts guarded { Loofah.html5_fragment("<p>x</p>").scrub!(:nope).to_s }
puts guarded { Loofah.html5_fragment("<p>x</p>").scrub!("strip").to_s }
puts guarded { Loofah::Scrubber.new(direction: :sideways) { |n| n }.direction.to_s }
puts guarded { Loofah::Scrubber.new.traverse(Loofah.html5_fragment("<p>x</p>").children.first) }

puts "-- fragments: to_s, serialize, text"
frag = Loofah.html4_fragment("<body><p>in body &amp; <b>bold</b></p></body>")
puts frag.to_s
puts frag.serialize
puts frag.text
puts frag.inner_text
puts frag.to_str
puts frag.to_text
f5 = Loofah.html5_fragment("<p>a</p><p>b</p><br>c")
puts f5.to_text.inspect
puts f5.text(encode_special_chars: false)
puts Loofah.fragment("<em>x</em>").class
puts Loofah.document("<em>x</em>").class
puts Loofah.html5_fragment("x").class
puts Loofah.html5_document("x").class
puts Loofah.xml_fragment("<a/>").class
puts Loofah.xml_document("<a/>").class

puts "-- documents drop the comments before <html>"
d = Loofah.html4_document("<!-- a --><!-- b --><html><body><!-- c --><p>x</p></body></html>")
puts d.children.length
puts d.to_html
d5 = Loofah.html5_document("<!-- a --><p>x</p>")
puts d5.children.length

puts "-- the scrub_ shortcuts"
puts Loofah.scrub_fragment("<p>x<script>y</script></p>", :strip).to_s
puts Loofah.scrub_html5_fragment("<p>x<script>y</script></p>", :escape).to_s
puts Loofah.scrub_html4_document("<p>x<script>y</script></p>", :prune).to_html
puts Loofah.scrub_html5_document("<p>x<script>y</script></p>", :whitewash).to_html
puts Loofah.remove_extraneous_whitespace("a\n\n\n\nb\n \n \nc")

puts "-- XML"
x = Loofah.xml_fragment("<root><evil>x</evil><good>y</good></root>")
evil = Loofah::Scrubber.new { |node| node.remove if node.name == "evil" }
puts x.scrub!(evil).to_s
xd = Loofah.xml_document("<root><evil>x</evil><good>y</good></root>")
puts xd.scrub!(evil).to_xml
puts Loofah.scrub_xml_fragment("<a><evil/></a>", evil).to_s

puts "-- Helpers"
puts Loofah::Helpers.strip_tags("<div>Hello <b>there</b></div>")
puts Loofah::Helpers.sanitize("<div>Hello <script>alert(1)</script><form>f</form><b>there</b></div>")
puts Loofah::Helpers.sanitize_css("display:block;background-image:url(http://x/y.jpg);color:red")
puts Loofah::Helpers.remove_extraneous_whitespace("a\n\n\n\nb")
puts Loofah::Helpers::ActionView::FullSanitizer.new.sanitize("<i>x</i> & y")
puts Loofah::Helpers::ActionView::SafeListSanitizer.new.sanitize("<i onclick='z'>x</i>")
puts Loofah::Helpers::ActionView::SafeListSanitizer.new.sanitize_css("color: red; behavior: url(x)")

puts "-- the safe lists"
sl = Loofah::HTML5::SafeList
puts sl::ALLOWED_ELEMENTS.include?("clipPath")
puts sl::ALLOWED_ELEMENTS.include?("clippath")
puts sl::ALLOWED_ATTRIBUTES.include?("viewbox")
puts sl::ALLOWED_ATTRIBUTES.include?("viewBox")
puts sl::ALLOWED_ELEMENTS_WITH_LIBXML2.include?("script")
puts sl::ALLOWED_ELEMENTS_WITH_LIBXML2.include?("div")
puts [sl::ALLOWED_ELEMENTS.size, sl::ALLOWED_ATTRIBUTES.size, sl::ALLOWED_CSS_PROPERTIES.size,
      sl::ALLOWED_CSS_KEYWORDS.size, sl::ALLOWED_PROTOCOLS.size, sl::VOID_ELEMENTS.size].inspect
puts sl::ALLOWED_PROTOCOLS.to_a.sort.first(5).inspect
puts Loofah::Elements::BLOCK_LEVEL.include?("div")
puts Loofah::Elements::LINEBREAKERS.include?("br")
puts Loofah::Elements::LINEBREAKERS.size
puts Loofah::HTML5::Scrub.allowed_element?("svg")
puts Loofah::HTML5::Scrub.allowed_element?("script")

puts "-- attribute-level scrubbing"
a = Loofah.html5_fragment('<a href="java&#x09;script:alert(1)" title="t" onclick="x" style="color: red; background: url(x)">l</a>')
puts a.scrub!(:strip).to_s
svg = Loofah.html5_fragment('<svg><use xlink:href="http://evil/#x"></use><use xlink:href="#ok"></use><rect fill="url(#g) red" /></svg>')
puts svg.scrub!(:strip).to_s
img = Loofah.html5_fragment('<img src="a b.png" name="n m"><a name="a b" href="x y">z</a>')
puts img.scrub!(:strip).to_s
