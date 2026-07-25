# frozen_string_literal: true

module Components
  class CategoryColourSegments < Base
    def initialize(categories:, **attrs)
      @bundle = CategoryColours::Presentation.bundle(categories)
      super(**attrs)
    end

    def view_template
      return unless bundle.multiple?

      div(**attrs) do
        bundle.segments.each do |segment|
          span(
            class: "min-w-0 flex-1",
            style: "background-color: #{segment.presentation.background};",
            data: {
              category_colour_segment: "true",
              category_id: segment.key
            }
          )
        end
      end
    end

    private

    attr_reader :bundle

    def default_attrs
      {
        class: "pointer-events-none absolute inset-x-0 top-0 z-10 flex h-1.5 overflow-hidden rounded-t-lg",
        aria: { hidden: "true" },
        data: { category_colour_segments: "true", category_count: bundle.segments.size }
      }
    end
  end
end
