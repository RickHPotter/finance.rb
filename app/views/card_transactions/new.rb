# frozen_string_literal: true

module Views
  module CardTransactions
    class New < Views::Base
      def initialize(current_user:, card_transaction:)
        @current_user = current_user
        @card_transaction = card_transaction
      end

      def view_template
        turbo_frame_tag :center_container do
          div(class: "bg-white p-4 shadow-md rounded-lg") do
            if @card_transaction.duplicate
              span(class: "rounded-sm shadow-md bg-orange-200 border border-1 border-orange-400 px-3") { I18n.t("gerund.duplicate") }
            else
              span(class: "rounded-sm shadow-md bg-sky-200 border border-1 border-sky-400 px-3") { I18n.t("gerund.new") }
            end

            render Form.new(current_user: @current_user, card_transaction: @card_transaction)
          end
        end
      end
    end
  end
end
