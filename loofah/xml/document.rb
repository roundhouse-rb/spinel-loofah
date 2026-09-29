# frozen_string_literal: true

module Loofah
  module XML # :nodoc:
    #
    #  Subclass of Nokogiri::XML::Document.
    #
    #  See Loofah::ScrubBehavior and Loofah::DocumentDecorator for additional methods.
    #
    class Document < Nokogiri::XML::Document
      # spinel-loofah: +scrub!+ is on Nokogiri::XML::Document itself (see
      # concerns.rb), so there is nothing to include.
    end
  end
end
