# frozen_string_literal: true

module Components
  class BulkActionBar < Base
    include TranslateHelper

    attr_reader :selected_label, :actions

    def initialize(selected_label:, actions:)
      @selected_label = selected_label
      @actions = actions
    end

    def view_template
      div(
        class: "hidden fixed inset-x-3 bottom-20 md:bottom-6 md:left-1/2 md:right-auto md:inset-x-auto md:-translate-x-1/2 z-50",
        data: { datatable_target: :bulkBar }
      ) do
        div(class: "pointer-events-auto rounded-2xl border border-slate-300 bg-white/95 backdrop-blur shadow-2xl px-5 py-4 md:px-6 md:py-4") do
          div(class: "flex flex-col md:flex-row md:items-center md:justify-center gap-3 md:gap-5") do
            div(class: "text-base font-semibold text-slate-800 whitespace-nowrap text-center md:text-left") do
              span(data: { datatable_target: :selectedCount }) { "0" }
              plain " "
              plain selected_label
            end

            div(class: "flex gap-2 md:gap-3") do
              actions.each do |action|
                Button(
                  title: action[:title],
                  class: "flex-1 md:flex-none md:min-w-32",
                  data: action[:data]
                ) do
                  action[:label]
                end
              end
            end
          end
        end
      end
    end
  end
end
