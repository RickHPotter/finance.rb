# frozen_string_literal: true

class Views::Shared::ActiveStatusesCombobox < Views::Base
  include TranslateHelper

  attr_reader :model, :name, :selected_statuses

  def initialize(model:, name:, selected_statuses: [])
    @model = model
    @name = name
    @selected_statuses = selected_statuses
  end

  def view_template
    Combobox(term: model_attribute(model, :status), class: "w-full", data: { ruby_ui__combobox_reorder_value: true }) do
      ComboboxTrigger(placeholder: model_attribute(model, :status), class: combobox_trigger_class)

      ComboboxPopover(class: combobox_popover_class) do
        div(class: "my-1") do
          ComboboxSearchInput(placeholder: action_message(:type), class: combobox_search_input_class)
        end

        ComboboxList(class: combobox_list_class) do
          ComboboxEmptyState(class: "py-6 text-center text-sm text-muted-foreground dark:text-slate-500") { I18n.t(:rows_not_found) }

          ComboboxItem(class: "#{combobox_item_class} mt-1") do
            ComboboxToggleAllCheckbox(name: "#{name}_toggle_all", value: action_message(:all))
            span { action_message(:select_all) }
          end

          %w[active inactive].each do |status|
            ComboboxItem(class: combobox_item_class) do
              ComboboxCheckbox(
                name:,
                value: status,
                checked: selected_statuses.include?(status),
                data: {
                  ruby_ui__combobox_target: "input",
                  action: "change->ruby-ui--combobox#inputChanged change->reactive-form#submitWithDelay",
                  text: model_attribute(model, "statuses.#{status}")
                }
              )
              span { model_attribute(model, "statuses.#{status}") }
            end
          end
        end
      end
    end
  end

  private

  def combobox_trigger_class
    "flex h-10 w-full items-center justify-between overflow-hidden whitespace-nowrap rounded-md border border-slate-300 bg-white px-4 py-2 " \
      "text-sm text-slate-900 shadow-sm transition-colors hover:border-slate-400 hover:bg-slate-50 focus-visible:ring-2 focus-visible:ring-ring " \
      "disabled:pointer-events-none disabled:opacity-50 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-100 dark:hover:bg-slate-700/70 " \
      "dark:focus-visible:ring-sky-500/60 dark:disabled:opacity-40"
  end

  def combobox_popover_class
    "absolute inset-auto m-0 rounded-lg border bg-background shadow-lg dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100"
  end

  def combobox_list_class
    "flex max-h-72 flex-col gap-1 overflow-y-auto p-1 text-foreground dark:text-slate-100"
  end

  def combobox_search_input_class
    "flex h-10 w-full rounded-md border-none bg-transparent py-3 text-sm outline-none placeholder:text-muted-foreground disabled:cursor-not-allowed " \
      "disabled:opacity-50 dark:text-slate-100 dark:placeholder:text-slate-500"
  end

  def combobox_item_class
    "relative flex cursor-default select-none items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none hover:bg-accent dark:text-slate-100 " \
      "dark:hover:bg-slate-800 data-[disabled]:pointer-events-none data-[disabled]:opacity-50"
  end
end
