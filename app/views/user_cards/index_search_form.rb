# frozen_string_literal: true

class Views::UserCards::IndexSearchForm < Views::Base
  include Phlex::Rails::Helpers::FormWith

  include TranslateHelper
  include CacheHelper

  attr_reader :index_context, :mobile, :search_term, :status

  def initialize(index_context: {}, mobile: false)
    @index_context = index_context
    @search_term = index_context[:search_term]
    @status = index_context[:status]
    @mobile = mobile
  end

  def view_template
    form_with model: UserCard.new,
              url: user_cards_path,
              id: :search_form,
              method: :get,
              class: "w-full",
              data: { controller: "reactive-form" } do
      div(class: "flex items-center gap-2") do
        div(class: mobile ? "w-full" : "grid flex-1 grid-cols-2 gap-2") do
          TextFieldTag \
            :search_term,
            svg: :magnifying_glass,
            clearable: true,
            placeholder: "#{action_message(:search)}...",
            value: search_term,
            data: { controller: "cursor", action: "input->reactive-form#submitWithDelay" }

          unless mobile
            render Views::Shared::ActiveStatusesCombobox.new(
              model: UserCard,
              name: "user_card[status][]",
              selected_statuses:
            )
          end
        end

        if mobile
          Sheet(id: "advanced_filter") do
            SheetTrigger do
              Button(type: :button, icon: true, class: "scale-105") do
                cached_icon(:filter)
              end
            end

            SheetContent(side: :middle, class: "w-4/5 lg:w-1/2", data: { action: "close->reactive-form#submit" }) do
              SheetHeader do
                SheetTitle { pluralise_model(UserCard, 2) }
                SheetDescription { I18n.t(:advanced_filter) }
              end

              SheetMiddle do
                div(class: "grid grid-cols-1 gap-y-2 mb-2 w-full") do
                  render Views::Shared::ActiveStatusesCombobox.new(
                    model: UserCard,
                    name: "user_card[status][]",
                    selected_statuses:
                  )
                end
              end
            end
          end
        end
      end

      button(type: :submit, class: "hidden")
    end
  end

  private

  def selected_statuses
    Array(status).map(&:to_s)
  end
end
