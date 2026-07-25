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
        segment_side(:top, "inset-x-0 top-0 h-1.5 flex")
        segment_side(:right, "inset-y-0 right-0 w-1.5 flex flex-col")
        segment_side(:bottom, "inset-x-0 bottom-0 h-1.5 flex")
        segment_side(:left, "inset-y-0 left-0 w-1.5 flex flex-col")
      end
    end

    private

    attr_reader :bundle

    def segment_side(side, classes)
      div(class: "absolute #{classes}", data: { category_colour_segment_side: side }) do
        bundle.segments.each do |segment|
          span(
            class: "min-h-0 min-w-0 flex-1",
            style: "background-color: #{segment.presentation.background};",
            data: {
              category_colour_segment: "true",
              category_colour_segment_edge: side,
              category_id: segment.key
            }
          )
        end
      end
    end

    def default_attrs
      {
        class: "pointer-events-none absolute inset-0 z-10 overflow-hidden rounded-lg",
        aria: { hidden: "true" },
        data: { category_colour_segments: "true", category_count: bundle.segments.size }
      }
    end
  end
end
