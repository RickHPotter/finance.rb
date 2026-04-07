# frozen_string_literal: true

class Views::Transactions::FormActions < Views::Base
  include Phlex::Rails::Helpers::HiddenFieldTag
  include TranslateHelper

  attr_reader :transaction, :destroy_href, :destroy_id, :duplicate_href, :confirmation_submit

  def initialize(transaction:, destroy_href:, destroy_id:, duplicate_href: nil, confirmation_submit: nil)
    @transaction = transaction
    @destroy_href = destroy_href
    @destroy_id = destroy_id
    @duplicate_href = duplicate_href
    @confirmation_submit = confirmation_submit
  end

  def view_template(&)
    div(class: "grid grid-cols-1 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center gap-2 mx-auto w-full") do
      if confirmation_submit.present?
        hidden_field_tag(
          confirmation_submit[:name],
          confirmation_submit[:current_value],
          id: confirmation_submit[:field_id]
        )
      end

      Button(type: :submit, variant: :purple, class: "w-64") { action_message(:submit) }

      if confirmation_submit.present?
        Button(
          type: :submit,
          variant: :outline,
          class: "w-64 border-amber-300 text-amber-900"
        ) { confirmation_submit[:label] }
      end

      if duplicate_href.present? && transaction.can_be_destroyed?
        Button(link: duplicate_href, class: "min-w-64", data: { turbo_frame: "_top" }) do
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
