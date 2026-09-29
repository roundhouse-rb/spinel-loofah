# frozen_string_literal: true

module Loofah
  module HTML5 # :nodoc:
    #
    #  Subclass of Nokogiri::HTML5::DocumentFragment.
    #
    #  See Loofah::ScrubBehavior and Loofah::TextBehavior for additional methods.
    #
    class DocumentFragment < Nokogiri::HTML5::DocumentFragment
      include Loofah::TextBehavior
      include Loofah::HtmlFragmentBehavior

      # spinel-loofah: HtmlFragmentBehavior::ClassMethods, defined here (see
      # concerns.rb). The markup is a String, so its encoding is the default.
      def self.parse(tags, encoding = nil)
        doc = document_klass.new

        encoding ||= tags.encoding.name
        doc.encoding = encoding

        new(doc, tags)
      end

      def self.document_klass
        Loofah::HTML5::Document
      end
    end
  end
end
