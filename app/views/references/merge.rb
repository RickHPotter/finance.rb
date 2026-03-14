# frozen_string_literal: true

class Views::References::Merge < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :reference, :user_card

  def initialize(reference:, user_card:)
    @reference = reference
    @user_card = user_card
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "bg-white p-4 shadow-md rounded-lg") do
        h1(class: "text-2xl font-bold mb-4") { action_model(:merge, Reference, 2) }

        form_with(url: perform_merge_user_card_references_path(user_card), method: :post, data: { turbo: true }) do |form|
          div(class: "grid grid-cols-2 gap-4") do
            div(class: "mb-4") do
              form.label :source_reference_date, model_attribute(Reference, :source_reference_date), class: "block text-sm font-medium text-gray-700"
              render Components::TextFieldTag.new(
                :source_reference_date,
                type: :month,
                svg: :calendar,
                class: "font-graduate",
                value: reference.reference_date.strftime("%Y-%m")
              )
            end

            div(class: "mb-4") do
              form.label :target_reference_date, model_attribute(Reference, :target_reference_date), class: "block text-sm font-medium text-gray-700"
              render Components::TextFieldTag.new(
                :target_reference_date,
                type: :month,
                svg: :calendar,
                class: "font-graduate",
                value: reference.reference_date.next_month.strftime("%Y-%m")
              )
            end
          end

          div(class: "flex items-center justify-between") do
            form.submit action_model(:merge, Reference, 2),
                        class: "inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md
                                text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"

            link_to I18n.t("confirmation.cancel"),
                    edit_user_card_path(user_card),
                    class: "py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
          end
        end
      end
    end
  end
end
