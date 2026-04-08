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
        class: "hidden fixed inset-x-3 bottom-20 md:bottom-6 md:left-1/2 md:right-auto md:inset-x-auto
                md:-translate-x-1/2 z-50 transition-opacity duration-300 opacity-0 pointer-events-none".squish,
        data: { datatable_target: :bulkBar }
      ) do
        div(class: "pointer-events-auto rounded-2xl border border-slate-300 bg-white/95 backdrop-blur shadow-2xl px-5 py-4 md:px-6 md:py-4") do
          div(class: "flex flex-col gap-3") do
            div(class: "flex flex-col md:flex-row md:items-center md:justify-center gap-3 md:gap-6") do
              div(class: "text-base font-semibold text-slate-800 whitespace-nowrap text-center md:text-left") do
                span(data: { datatable_target: :selectedCount }) { "0" }
                plain " "
                plain selected_label
              end

              div(class: "text-sm font-medium text-slate-600 whitespace-nowrap text-center md:text-left") do
                plain "#{I18n.t('bulk_actions.total_selected')}: "
                span(data: { datatable_target: :selectedTotal }) { "R$0.00" }
              end
            end

            div(class: "flex flex-wrap gap-2 md:gap-3") do
              Button(
                title: action_message(:select_page),
                class: "flex-1 md:flex-none md:min-w-32",
                data: { action: "click->datatable#togglePageSelection", datatable_target: :selectPageButton }
              ) do
                action_message(:select_page)
              end

              actions.each do |action|
                action_data = {
                  datatable_target: :bulkActionButton,
                  bulk_action_name: action[:name],
                  bulk_ids_kind: action[:ids_kind] || "installment",
                  bulk_disabled_reason: action[:disabled_reason],
                  bulk_base_disabled: action[:base_disabled].to_s,
                  bulk_base_disabled_reason: action[:base_disabled_reason]
                }.compact.merge(action[:data] || {})

                Button(
                  title: action[:title],
                  class: "flex-1 md:flex-none md:min-w-32",
                  disabled: action[:base_disabled],
                  data: action_data
                ) do
                  action[:label]
                end
              end
            end

            p(class: "min-h-5 text-center text-xs text-slate-500 md:text-left", data: { datatable_target: :selectionHint }) do
              ""
            end
          end
        end
      end
    end
  end
end
