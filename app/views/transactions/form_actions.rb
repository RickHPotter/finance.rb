# frozen_string_literal: true

class Views::Transactions::FormActions < Views::Base
  include TranslateHelper

  attr_reader :transaction, :destroy_href, :destroy_id, :duplicate_href

  def initialize(transaction:, destroy_href:, destroy_id:, duplicate_href: nil)
    @transaction = transaction
    @destroy_href = destroy_href
    @destroy_id = destroy_id
    @duplicate_href = duplicate_href
  end

  def view_template(&)
    div(class: "grid grid-cols-1 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center gap-2 mx-auto w-full") do
      Button(type: :submit, variant: :purple, class: "w-64") { action_message(:submit) }

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
