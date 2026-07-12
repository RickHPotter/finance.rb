# frozen_string_literal: true

class Views::UserCards::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include CacheHelper
  include TranslateHelper
  include ComponentsHelper

  attr_reader :user_cards, :index_context, :mobile

  def initialize(user_cards:, index_context: {}, mobile: false)
    @user_cards = user_cards
    @index_context = index_context
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: resource_index_shell_class) do
        render_hero
        mobile ? mobile_index : desktop_index
      end
    end
  end

  private

  def render_hero
    div(class: resource_index_hero_class) do
      h1(class: resource_index_title_class) { action_model(:index, UserCard, 2) }
      next if mobile

      link_to(
        action_model(:new, UserCard),
        new_user_card_path,
        class: index_new_button_class,
        data: { turbo_frame: "_top" }
      )
    end
  end

  def desktop_index
    div(class: "min-w-full") do
      turbo_frame_tag :user_cards do
        div(class: "min-h-full", data: { controller: "datatable" }) do
          render Views::UserCards::IndexSearchForm.new(index_context:, mobile: false)

          div(class: "my-4", data: { datatable_target: "table" }) do
            div(class: resource_table_shell_class) do
              render Views::Shared::TableHeader.new(
                grid_class: "grid grid-cols-9",
                rows: [
                  [
                    { class: "col-span-2 flex justify-center", label: model_attribute(UserCard, :user_card_name), align: :center },
                    { class: "flex justify-center", label: model_attribute(UserCard, :status), align: :center },
                    { class: "flex justify-center", label: model_attribute(UserCard, :count), align: :center },
                    { class: "flex justify-center", label: model_attribute(UserCard, :spent), align: :center },
                    { class: "flex items-end justify-end pr-2", label: model_attribute(UserCard, :closing_date), align: :right },
                    { class: "flex justify-start", label: model_attribute(UserCard, :due_date) },
                    { class: "flex items-end justify-end", label: model_attribute(UserCard, :credit_limit), align: :right },
                    { class: "flex justify-center", label: I18n.t(:datatable_actions) }
                  ]
                ]
              )

              if user_cards.present?
                user_cards.each do |record|
                  render Views::UserCards::UserCard.new(user_card: record, mobile: false)
                end
              else
                div(class: resource_empty_row_class) { I18n.t(:rows_not_found) }
              end
            end
          end
        end
      end
    end
  end

  def mobile_index
    div(class: "w-full") do
      div(class: "min-w-full") do
        turbo_frame_tag :user_cards do
          div(class: "min-h-full", data: { controller: "datatable" }) do
            div(class: resource_mobile_filter_shell_class) do
              render Views::UserCards::IndexSearchForm.new(index_context:, mobile: true)
            end

            div(class: "mb-8", data: { datatable_target: "table" }) do
              if user_cards.present?
                user_cards.each do |record|
                  render Views::UserCards::UserCard.new(user_card: record, mobile: true)
                end
              else
                div(class: resource_empty_row_class) { I18n.t(:rows_not_found) }
              end
            end
          end

          link_to(
            new_user_card_path,
            style: "margin: 30px",
            class: "fixed bottom-0 right-0 bg-blue-600 text-white rounded-full shadow-lg flex items-center justify-center z-50 active:scale-95 transition-transform",
            data: { turbo_frame: "_top" }
          ) { cached_icon(:bigger_plus) }
        end
      end
    end
  end
end
