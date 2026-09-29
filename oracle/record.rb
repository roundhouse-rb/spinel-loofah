# Loaded before the suite: records each String input the gem's own tests
# hand Loofah's entry points, by entry point, into corpus.json at exit.
gem "loofah", "2.25.2"
gem "minitest", "5.27.0"
require "loofah"
require "json"
require "set"
CORPUS = Hash.new { |h, k| h[k] = Set.new }
def record_on(target, names)
  names.each do |m|
    orig = target.method(m)
    target.define_singleton_method(m) do |*a, **k, &b|
      CORPUS[m] << a.first if a.first.is_a?(String)
      orig.call(*a, **k, &b)
    end
  end
end
record_on(Loofah, %i[html4_fragment html5_fragment html4_document html5_document xml_fragment xml_document
                     scrub_html4_fragment scrub_html5_fragment scrub_html4_document scrub_html5_document
                     fragment document scrub_fragment scrub_document])
record_on(Loofah::HTML5::Scrub, %i[scrub_css allowed_uri?])
at_exit { File.write("corpus.json", JSON.pretty_generate(CORPUS.transform_values(&:to_a))) }
