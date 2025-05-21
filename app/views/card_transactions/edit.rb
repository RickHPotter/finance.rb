# frozen_string_literal: true

module Views
  module CardTransactions
    class Edit < Views::Base
      def initialize(current_user:, card_transaction:)
        @current_user = current_user
        @card_transaction = card_transaction
      end

      def view_template
        turbo_frame_tag :center_container do
          div(class: "bg-white p-4 shadow-md rounded-lg") do
            span(class: "rounded-sm shadow-md bg-lime-200 border border-1 border-lime-400 px-3") { I18n.t("gerund.edit") }

            render Form.new(current_user: @current_user, card_transaction: @card_transaction)
          end
        end
      end
    end
  end
end
