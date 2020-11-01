# frozen_string_literal: true

module SumsUp
  module Core
    # Matching DSL for sum type variants. Methods in this class are prefixed
    # with an _ so as not to conflict with the names of user-defined variant
    # names.
    class Matcher
      def self.build_matcher_class(variant, other_variants)
        Class.new(self).tap do |klass|
          klass.define_method(variant, &build_correct_matcher(variant))

          other_variants.each do |other_variant|
            klass.define_method(other_variant, &build_incorrect_matcher(other_variant))
          end

          all_variants = [variant, *other_variants]

          klass.define_method(:_fetch_result, &build_fetch_result(all_variants))
        end
      end

      def self.build_correct_matcher(variant)
        proc do |value = nil, &block|
          _ensure_wildcard_not_matched!(variant)
          _ensure_no_duplicate_match!(variant)

          @matched_variants << variant
          @matched = true

          @result = block ? block.call(*@variant_instance.members) : value

          self
        end
      end

      def self.build_incorrect_matcher(variant)
        proc do |_value = nil|
          _ensure_wildcard_not_matched!(variant)
          _ensure_no_duplicate_match!(variant)

          @matched_variants << variant

          self
        end
      end

      def self.build_fetch_result(all_variants)
        total_variants = all_variants.length

        proc do
          return @result if @wildcard_matched || (@matched_variants.length == total_variants)

          unmatched_variants = (all_variants - @matched_variants).join(', ')

          raise(
            UnmatchedVariantError,
            "Did not match the following variants: #{unmatched_variants}"
          )
        end
      end

      def initialize(variant_instance)
        @variant_instance = variant_instance

        @matched = false
        @matched_variants = []
        @wildcard_matched = false
        @result = nil
      end

      def _(value = nil)
        _ensure_wildcard_not_matched!(:_)

        @wildcard_matched = true

        return if @matched

        @result = block_given? ? yield(@variant_instance) : value

        self
      end

      def _ensure_wildcard_not_matched!(variant)
        return unless @wildcard_matched

        raise(
          MatchAfterWildcardError,
          "Attempted to match variant after wildcard (_): #{variant}"
        )
      end

      def _ensure_no_duplicate_match!(variant)
        return unless @matched_variants.include?(variant)

        raise(DuplicateMatchError, "Duplicated match for variant: #{variant}")
      end
    end
  end
end
