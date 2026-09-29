# frozen_string_literal: true

module Loofah
  module XML # :nodoc:
    #
    #  Subclass of Nokogiri::XML::DocumentFragment.
    #
    #  See Loofah::ScrubBehavior for additional methods.
    #
    class DocumentFragment < Nokogiri::XML::DocumentFragment
      class << self
        def parse(tags)
          doc = Loofah::XML::Document.new
          # spinel-loofah: the gem guards this with tags.respond_to?(:encoding),
          # for an IO; the markup here is a String.
          doc.encoding = tags.encoding.name
          new(doc, tags)
        end
      end
    end
  end
end
