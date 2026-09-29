# frozen_string_literal: true

module Loofah
  #
  #  Mixes +scrub!+ into Document, DocumentFragment, Node and NodeSet.
  #
  #  Traverse the document or fragment, invoking the +scrubber+ on each node.
  #
  #  +scrubber+ must either be one of the symbols representing the built-in scrubbers (see
  #  Scrubbers), or a Scrubber instance.
  #
  #    span2div = Loofah::Scrubber.new do |node|
  #      node.name = "div" if node.name == "span"
  #    end
  #    Loofah.html5_fragment("<span>foo</span><p>bar</p>").scrub!(span2div).to_s
  #    # => "<div>foo</div><p>bar</p>"
  #
  #  or
  #
  #    unsafe_html = "ohai! <div>div is safe</div> <script>but script is not</script>"
  #    Loofah.html5_fragment(unsafe_html).scrub!(:strip).to_s
  #    # => "ohai! <div>div is safe</div> "
  #
  #  Note that this method is called implicitly from the shortcuts Loofah.scrub_html5_fragment et
  #  al.
  #
  #  Please see Scrubber for more information on implementation and traversal, and README.rdoc for
  #  more example usage.
  #
  module ScrubBehavior
    # spinel-loofah: the gem mixes these in through Nokogiri's per-document
    # decorators (DocumentDecorator, below in the gem), so only the nodes of a
    # Loofah document answer +scrub!+. spinel-nokogiri has no decorators, and
    # its DocumentFragment is not a Node; so +scrub!+ is defined on
    # Nokogiri::XML::Node, Document, DocumentFragment and NodeSet directly (see
    # the end of this file), each arm of the gem's +case self+ in its own
    # class. Any Nokogiri node answers +scrub!+ here, not only a Loofah one's.
    class << self
      def resolve_scrubber(scrubber) # :nodoc:
        # spinel-loofah: MAP's class, made by name (Scrubbers.named), not
        # `MAP[scrubber].new` on a class read out of a Hash.
        named = Scrubbers.named(scrubber)
        scrubber = named if named
        unless scrubber.is_a?(Loofah::Scrubber)
          raise Loofah::ScrubberNotFound, "not a Scrubber or a scrubber name: #{scrubber.inspect}"
        end

        scrubber
      end
    end
  end

  #
  #  Overrides +text+ in Document and DocumentFragment classes, and mixes in +to_text+.
  #
  module TextBehavior
    #
    #  Returns a plain-text version of the markup contained by the document, with HTML entities
    #  encoded.
    #
    #  This method is significantly faster than #to_text, but isn't clever about whitespace around
    #  block elements.
    #
    #    Loofah.html5_document("<h1>Title</h1><div>Content</div>").text
    #    # => "TitleContent"
    #
    #  By default, the returned text will have HTML entities escaped. If you want unescaped
    #  entities, and you understand that the result is unsafe to render in a browser, then you can
    #  pass an argument as shown:
    #
    #    frag = Loofah.html5_fragment("&lt;script&gt;alert('EVIL');&lt;/script&gt;")
    #    # ok for browser:
    #    frag.text                                 # => "&lt;script&gt;alert('EVIL');&lt;/script&gt;"
    #    # decidedly not ok for browser:
    #    frag.text(:encode_special_chars => false) # => "<script>alert('EVIL');</script>"
    #
    def text(options = {})
      result = if serialize_root
        serialize_root.children.reject(&:comment?).map(&:inner_text).join("")
      else
        ""
      end
      if options[:encode_special_chars] == false
        result # possibly dangerous if rendered in a browser
      else
        encode_special_chars(result)
      end
    end

    alias_method :inner_text, :text
    alias_method :to_str, :text

    #
    #  Returns a plain-text version of the markup contained by the fragment, with HTML entities
    #  encoded.
    #
    #  This method is slower than #text, but is clever about whitespace around block elements and
    #  line break elements.
    #
    #    Loofah.html5_document("<h1>Title</h1><div>Content<br>Next line</div>").to_text
    #    # => "\nTitle\n\nContent\nNext line\n"
    #
    def to_text(options = {})
      Loofah.remove_extraneous_whitespace(dup.scrub!(:newline_block_elements).text(options))
    end
  end

  # spinel-loofah: DocumentDecorator is gone with the decorators (see
  # ScrubBehavior above).

  module HtmlDocumentBehavior # :nodoc:
    # spinel-loofah: the gem's ClassMethods#parse, extended onto each
    # including class from an +included+ hook, calls +super+ and then this.
    # Each Loofah document class defines its own +parse+ that does the same
    # (html4/document.rb, html5/document.rb).
    class << self
      # remove comments that exist outside of the HTML element.
      #
      # these comments are allowed by the HTML spec:
      #
      #    https://www.w3.org/TR/html401/struct/global.html#h-7.1
      #
      # but are not scrubbed by Loofah because these nodes don't meet
      # the contract that scrubbers expect of a node (e.g., it can be
      # replaced, sibling and children nodes can be created).
      def remove_comments_before_html_element(doc)
        doc.children.each do |child|
          child.unlink if child.comment?
        end
        doc
      end
    end

    def serialize_root
      at_xpath("/html/body")
    end
  end

  module HtmlFragmentBehavior # :nodoc:
    # spinel-loofah: the gem's ClassMethods (+parse+ and +document_klass+,
    # extended from an +included+ hook) are defined on each Loofah fragment
    # class itself (html4/document_fragment.rb, html5/document_fragment.rb),
    # where +document_klass+ is a literal rather than a comparison of self.

    def to_s
      serialize_root.children.to_s
    end

    alias_method :serialize, :to_s

    def serialize_root
      at_xpath("./body") || self
    end
  end
end

# spinel-loofah: ScrubBehavior's +scrub!+, one per class (see above).
module Nokogiri
  module XML
    class Node
      def scrub!(scrubber)
        scrubber = Loofah::ScrubBehavior.resolve_scrubber(scrubber)
        scrubber.traverse(self)
        self
      end
    end

    class Document
      def scrub!(scrubber)
        scrubber = Loofah::ScrubBehavior.resolve_scrubber(scrubber)
        scrubber.traverse(root) if root
        self
      end
    end

    class DocumentFragment
      def scrub!(scrubber)
        scrubber = Loofah::ScrubBehavior.resolve_scrubber(scrubber)
        children.scrub!(scrubber)
        self
      end
    end

    class NodeSet
      def scrub!(scrubber)
        each { |node| node.scrub!(scrubber) }
        self
      end
    end
  end
end
