# frozen_string_literal: true

module Components
  class BulkActionBar < Base
    include TranslateHelper
    include CacheHelper

    attr_reader :selected_label, :actions, :selection_kind

    def initialize(selected_label:, actions:, selection_kind: "installment")
      @selected_label = selected_label
      @actions = actions
      @selection_kind = selection_kind
    end

    def view_template
      div(
        class: "hidden fixed inset-x-3 bottom-20 md:bottom-6 md:left-1/2 md:right-auto md:inset-x-auto
                md:-translate-x-1/2 z-50 transition-opacity duration-300 opacity-0 pointer-events-none".squish,
        data: { datatable_target: :bulkBar, bulk_selection_kind: selection_kind }
      ) do
        div(
          class: "pointer-events-auto rounded-2xl border border-slate-300 bg-white/95 backdrop-blur shadow-2xl px-5 py-4 md:px-6 md:py-4 " \
                 "dark:border-slate-700 dark:bg-slate-900/95 dark:shadow-slate-950"
        ) do
          div(class: "flex flex-col gap-3") do
            div(class: "flex flex-col md:flex-row md:items-center md:justify-center gap-3 md:gap-6") do
              div(class: "text-base font-semibold text-slate-800 whitespace-nowrap text-center md:text-left dark:text-slate-100") do
                span(data: { datatable_target: :selectedCount }) { "0" }
                plain " "
                plain selected_label
              end

              div(class: "text-sm font-medium text-slate-600 whitespace-nowrap text-center md:text-left dark:text-slate-300") do
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
                  bulk_selection_kind: action[:selection_kind] || "installment",
                  bulk_disabled_reason: action[:disabled_reason],
                  bulk_base_disabled: action[:base_disabled].to_s,
                  bulk_base_disabled_reason: action[:base_disabled_reason]
                }.compact.merge(action[:data] || {})

                if action[:menu_items].present?
                  render_menu_action(action, action_data)
                else
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
            end

            p(class: "min-h-5 text-center text-xs text-slate-500 md:text-left dark:text-slate-400", data: { datatable_target: :selectionHint }) do
              ""
            end
          end
        end
      end
    end

    private

    def render_menu_action(action, action_data)
      Popover(options: { trigger: "click", placement: "top-start" }, class: "flex-1 md:flex-none") do
        PopoverTrigger(class: "w-full") do
          Button(
            title: action[:title],
            class: "flex w-full items-center justify-between gap-2 md:min-w-32",
            disabled: action[:base_disabled],
            data: action_data
          ) do
            span { action[:label] }
          end
        end

        PopoverContent(class: "z-50 opacity-100! min-w-44 p-1") do
          div(class: "flex flex-col gap-1") do
            action[:menu_items].each do |item|
              item_data = action_data.except(:datatable_target).merge(item[:data] || {})

              button(
                type: :button,
                title: item[:title],
                class: "w-full rounded-md px-3 py-2 text-left text-sm text-slate-700 transition-colors hover:bg-slate-100 " \
                       "dark:text-slate-200 dark:hover:bg-slate-800",
                data: item_data.merge(action: [ item_data[:action], "click->ruby-ui--popover#close" ].compact.join(" "))
              ) do
                item[:label]
              end
            end
          end
        end
      end
    end
  end
end
