# frozen_string_literal: true

module Loofah
  module MetaHelpers # :nodoc:
    class << self
      # spinel-loofah: the gem's add_downcased_set_members_to_all_set_constants(mojule)
      # finds the Sets with `mojule.constants` and `const_get`, a name known only
      # at run time, which Spinel resolves at compile time or not at all. The two
      # callers name their Set constants instead; what is done to each is the
      # gem's.
      def add_downcased_set_members(sets)
        sets.each do |constant|
          constant.dup.each do |member|
            constant.add(member.downcase)
          end
        end
      end
    end
  end
end
