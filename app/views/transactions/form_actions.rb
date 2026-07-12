# frozen_string_literal: true

class Views::Transactions::FormActions < Views::Base
  include TranslateHelper

  attr_reader :transaction, :destroy_href, :destroy_id, :duplicate_href, :confirmation_submit, :chain_context

  def initialize(transaction:, chain_context: nil, **action_options)
    @transaction = transaction
    @destroy_href = action_options[:destroy_href]
    @destroy_id = action_options[:destroy_id]
    @duplicate_href = action_options[:duplicate_href]
    @confirmation_submit = action_options[:confirmation_submit]
    @chain_context = chain_context
  end

  def view_template(&)
    div(class: "flex w-full flex-col gap-3") do
      render_top_control

      div(class: "grid grid-cols-1 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center gap-2 mx-auto w-full") do
        Button(type: :submit, class: "w-64 #{submit_button_class(form_action_mode(transaction))}") { action_message(:submit) }

        render_finish_chain_button
        render_finish_chain_without_save_button

        if duplicate_href.present?
          Button(link: duplicate_href, class: duplicate_button_class, data: { turbo_frame: "_top" }) do
            action_message(:duplicate)
          end
        end

        if transaction.can_be_destroyed?
          LinkWithConfirmation(
            id: transaction.id,
            text: action_message(:destroy),
            link_params: {
              href: destroy_href,
              id: destroy_id,
              variant: :outline,
              class: "min-w-64 #{destroy_button_class}",
              data: { turbo_method: :delete }
            }
          )
        end

        yield if block_given?
      end
    end
  end

  private

  def render_top_control
    if confirmation_submit.present?
      label(class: "flex w-full items-center justify-center pt-1") do
        span(class: "flex items-center gap-2 text-sm font-medium text-slate-700 dark:text-slate-300") do
          input(
            type: "checkbox",
            name: confirmation_submit[:name],
            value: confirmation_submit[:value],
            checked: confirmation_submit[:checked],
            id: confirmation_submit[:field_id],
            class: "h-4 w-4 rounded border-slate-300 text-amber-600 focus:ring-amber-500 dark:border-slate-600 dark:bg-slate-800 dark:text-amber-400"
          )
          plain confirmation_submit[:label]
        end
      end
      return
    end

    return unless transaction.new_record?
    return if transaction.persisted?

    render Views::Transactions::ChainControls.new(
      mode: chain_mode,
      record_ids: chain_record_ids,
      checked: chain_checked?
    )
  end

  def render_finish_chain_button
    return unless transaction.new_record?
    return if transaction.persisted?

    Button(type: :submit, variant: :outline, class: secondary_action_button_class, name: "finish_chain", value: "1") do
      I18n.t("actions.finish_chain")
    end
  end

  def render_finish_chain_without_save_button
    return unless transaction.new_record?
    return if transaction.persisted?

    Button(type: :submit, variant: :outline, class: secondary_action_button_class, name: "finish_chain_without_save", value: "1") do
      I18n.t("actions.finish_chain_without_save")
    end
  end

  def chain_mode
    chain_context&.dig(:mode) || (transaction.respond_to?(:duplicate) && transaction.duplicate ? "duplicate" : "create")
  end

  def chain_record_ids
    chain_context&.dig(:record_ids) || []
  end

  def chain_checked?
    chain_context&.dig(:checked) || false
  end

  def secondary_action_button_class
    secondary_submit_row_button_class
  end
end
