# frozen_string_literal: true

class Views::Categories::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include CacheHelper
  include TranslateHelper
  include ComponentsHelper

  attr_reader :categories, :index_context, :mobile

  def initialize(categories:, index_context: {}, mobile: false)
    @categories = categories
    @index_context = index_context
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "flex min-h-[calc(100svh-18rem)] flex-col rounded-lg bg-white shadow-md") do
        mobile ? mobile_index : desktop_index
      end
    end
  end

  private

  def desktop_index
    div(class: "mb-6 flex justify-end") do
      link_to(
        action_model(:newa, Category),
        new_category_path,
        class: index_new_button_class,
        data: { turbo_frame: "_top" }
      )
    end

    div(class: "min-w-full") do
      turbo_frame_tag :categories do
        div(class: "min-h-full", data: { controller: "datatable" }) do
          render Views::Categories::IndexSearchForm.new(index_context:, mobile: false)

          div(class: "my-4", data: { datatable_target: "table" }) do
            div(class: "rounded-lg border border-slate-300 shadow-sm overflow-hidden") do
              render Views::Shared::TableHeader.new(
                grid_class: "grid grid-cols-8",
                rows: [
                  [
                    { class: "col-span-3", label: nil },
                    { class: "col-span-2 flex justify-center", label: pluralise_model(CardTransaction, 2), align: :center },
                    { class: "col-span-2 flex justify-center", label: pluralise_model(CashTransaction, 2), align: :center },
                    { class: "", label: nil }
                  ],
                  [
                    { class: "col-span-2 flex justify-center", label: model_attribute(Category, :category_name), align: :center },
                    { class: "flex justify-center", label: model_attribute(Category, :status), align: :center },
                    { class: "flex justify-center", label: model_attribute(Category, :count), align: :center },
                    { class: "flex justify-center", label: model_attribute(Category, :spent), align: :center },
                    { class: "flex justify-center", label: model_attribute(Category, :count), align: :center },
                    { class: "flex justify-center", label: model_attribute(Category, :spent), align: :center },
                    { class: "flex justify-center", label: I18n.t(:datatable_actions) }
                  ]
                ]
              )

              if categories.present?
                categories.each do |record|
                  render Views::Categories::Category.new(category: record, mobile: false)
                end
              else
                div(class: "border-b border-slate-200 py-2 my-2 text-lg bg-white") { I18n.t(:rows_not_found) }
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
        turbo_frame_tag :categories do
          div(class: "min-h-full", data: { controller: "datatable" }) do
            div(class: "mb-6 grid grid-cols-1 gap-2 rounded-lg bg-slate-50 p-3 shadow-sm") do
              render Views::Categories::IndexSearchForm.new(index_context:, mobile: true)
            end

            div(class: "mb-8", data: { datatable_target: "table" }) do
              if categories.present?
                categories.each do |record|
                  render Views::Categories::Category.new(category: record, mobile: true)
                end
              else
                div(class: "border-b border-slate-200 py-2 my-2 text-lg bg-white") { I18n.t(:rows_not_found) }
              end
            end
          end

          link_to(
            new_category_path,
            style: "margin: 30px",
            class: "fixed bottom-0 right-0 bg-blue-600 text-white rounded-full shadow-lg flex items-center justify-center z-50 active:scale-95 transition-transform",
            data: { turbo_frame: "_top" }
          ) { cached_icon(:bigger_plus) }
        end
      end
    end
  end
end
