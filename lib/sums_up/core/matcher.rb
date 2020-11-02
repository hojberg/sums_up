# frozen_string_literal: true

module SumsUp
  module Core
    # Matching DSL for sum type variants. Methods in this class are prefixed
    # with an _ so as not to conflict with the names of user-defined variant
    # names. Use .build_matcher_class to generate a new subclass for a variant
    # given the other variant names.
    class Matcher
      def self.build_matcher_class(variant, other_variants)
        mods = {
          CorrectMatcher: correct_matcher_module(variant),
          IncorrectMatcher: incorrect_matcher_module(other_variants),
          FetchResult: fetch_result_module([variant, *other_variants])
        }

        mods.each_with_object(Class.new(self)) do |(const, mod), klass|
          klass.const_set(const, mod)

          klass.include(mod)
        end
      end

      def self.correct_matcher_module(variant)
        Module.new.tap do |mod|
          mod.define_method(variant) do |value = nil, &block|
            _ensure_wildcard_not_matched!(variant)
            _ensure_no_duplicate_match!(variant)

            @matched_variants << variant
            @matched = true

            @result = block ? block.call(*@variant_instance.members) : value

            self
          end
        end
      end

      def self.incorrect_matcher_module(variants)
        variants.each_with_object(Module.new) do |variant, mod|
          mod.define_method(variant) do |_value = nil|
            _ensure_wildcard_not_matched!(variant)
            _ensure_no_duplicate_match!(variant)

            @matched_variants << variant

            self
          end
        end
      end

      def self.fetch_result_module(all_variants)
        Module.new.tap do |mod|
          mod.define_method(:_fetch_result) do
            return @result if @wildcard_matched
            return @result if @matched_variants.length == all_variants.length

            unmatched_variants = (all_variants - @matched_variants).join(', ')

            raise(
              UnmatchedVariantError,
              "Did not match the following variants: #{unmatched_variants}"
            )
          end
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

        return self if @matched

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
