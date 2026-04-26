# frozen_string_literal: true

class Views::Transactions::FormActions < Views::Base
  include Phlex::Rails::Helpers::HiddenFieldTag
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
      render_chain_controls

      div(class: "grid grid-cols-1 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center gap-2 mx-auto w-full") do
        if confirmation_submit.present?
          hidden_field_tag(
            confirmation_submit[:name],
            confirmation_submit[:current_value],
            id: confirmation_submit[:field_id]
          )
        end

        Button(type: :submit, variant: :purple, class: "w-64") { action_message(:submit) }

        render_finish_chain_button
        render_finish_chain_without_save_button

        if confirmation_submit.present?
          Button(
            type: :submit,
            variant: :outline,
            class: "w-64 border-amber-300 text-amber-900"
          ) { confirmation_submit[:label] }
        end

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
              variant: :destructive,
              class: "min-w-64",
              data: { turbo_method: :delete }
            }
          )
        end

        yield if block_given?
      end
    end
  end

  private

  def render_chain_controls
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

    Button(type: :submit, variant: :outline, class: "w-64", name: "finish_chain", value: "1") do
      I18n.t("actions.finish_chain")
    end
  end

  def render_finish_chain_without_save_button
    return unless transaction.new_record?
    return if transaction.persisted?

    Button(type: :submit, variant: :outline, class: "w-64", name: "finish_chain_without_save", value: "1") do
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

  def duplicate_button_class
    "min-w-64 border-orange-500 bg-orange-100 text-orange-900 hover:border-orange-400 hover:bg-orange-500 hover:text-white"
  end
end
