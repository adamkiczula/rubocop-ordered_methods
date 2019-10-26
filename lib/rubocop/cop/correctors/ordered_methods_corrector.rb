# frozen_string_literal: true

require_relative '../layout/ordered_methods'
require_relative '../alias_method_order_verifier'
require_relative '../qualifier_node_matchers'

module RuboCop
  module Cop
    # This auto-corrects method order
    class OrderedMethodsCorrector
      class << self
        include QualifierNodeMatchers

        def correct(processed_source, node, previous_node)
          @processed_source = processed_source
          @current_node = node
          @previous_node = previous_node

          AliasMethodOrderVerifier.verify!(@current_node, @previous_node)
          current_range = join_surroundings(@current_node)
          previous_range = join_surroundings(@previous_node)
          lambda do |corrector|
            corrector.replace(current_range, previous_range.source)
            corrector.replace(previous_range, current_range.source)
          end
        end

        private

        def find_last_qualifier_index(node, siblings)
          preceding_qualifier_index = node.sibling_index
          last_qualifier_index = siblings.length - 1
          while preceding_qualifier_index < last_qualifier_index
            break if found_qualifier?(node, siblings[last_qualifier_index])

            last_qualifier_index -= 1
          end

          last_qualifier_index
        end

        def found_qualifier?(node, next_sibling)
          return false if next_sibling.nil?

          (qualifier?(next_sibling) || alias?(next_sibling)) == node.method_name
        end

        def join_comments(node, source_range)
          @processed_source.ast_with_comments[node].each do |comment|
            source_range = source_range.join(comment.loc.expression)
          end
          source_range
        end

        def join_modifiers_and_aliases(node, source_range)
          siblings = node.parent.children
          preceding_qualifier_index = node.sibling_index
          last_qualifier_index = find_last_qualifier_index(node, siblings)
          while preceding_qualifier_index < last_qualifier_index
            source_range = source_range.join(
              siblings[preceding_qualifier_index + 1].source_range
            )
            preceding_qualifier_index += 1
          end
          source_range
        end

        def join_surroundings(node)
          with_modifiers_and_aliases = join_modifiers_and_aliases(
            node,
            node.source_range
          )
          join_comments(node, with_modifiers_and_aliases)
        end
      end
    end
  end
end
