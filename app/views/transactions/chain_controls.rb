# frozen_string_literal: true

class Views::Transactions::ChainControls < Views::Base
  include Phlex::Rails::Helpers::HiddenFieldTag

  attr_reader :mode, :record_ids, :checked

  def initialize(mode:, record_ids: [], checked: false)
    @mode = mode
    @record_ids = Array(record_ids).compact_blank
    @checked = checked
  end

  def view_template
    hidden_field_tag :chain_mode, mode
    record_ids.each do |record_id|
      hidden_field_tag "chain_record_ids[]", record_id
    end

    div(class: "flex w-full items-center justify-center pt-1") do
      label(class: "flex items-center gap-2 text-sm font-medium text-slate-700") do
        input(
          type: "checkbox",
          name: "continue_chain",
          value: "1",
          checked: checked,
          class: "h-4 w-4 rounded border-slate-300 text-sky-600 focus:ring-sky-500"
        )
        plain chain_label
      end
    end
  end

  private

  def chain_label
    I18n.t("actions.#{mode}_more")
  end
end
