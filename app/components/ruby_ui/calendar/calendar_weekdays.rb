# frozen_string_literal: true

module RubyUI
  class CalendarWeekdays < Base
    DAYS = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze

    def view_template
      template(data: { ruby_ui__calendar_target: "weekdaysTemplate" }) do
        thead(**attrs) do
          tr(class: "grid w-full grid-cols-7") do
            DAYS.each do |day|
              render_day(day)
            end
          end
        end
      end
    end

    private

    def render_day(day)
      th(
        scope: "col",
        class: "text-muted-foreground flex justify-center rounded-md font-normal text-[0.8rem]",
        aria_label: day
      ) { day[0..1] }
    end

    def default_attrs
      {}
    end
  end
end
