# frozen_string_literal: true

class Views::Entities::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::TextFieldTag

  include CacheHelper
  include TranslateHelper
  include ComponentsHelper

  attr_reader :entities, :mobile

  def initialize(entities:, mobile: false)
    @entities = entities
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

  def include_inactive?
    params[:include_inactive] == "false"
  end

  def desktop_index
    div(class: "flex justify-between mb-6 bg-white p-4 shadow-md rounded-lg") do
      link_to(
        action_model(:newa, Entity),
        new_entity_path,
        class: "py-2 px-3 rounded-sm border border-sky-900 bg-blue-600 hover:bg-blue-800 transition-colors text-white shadow-lg font-thin",
        data: { turbo_frame: "_top" }
      )

      link_to(
        include_inactive? ? action_message(:show_inactive) : action_message(:hide_inactive),
        entities_path(include_inactive: include_inactive?),
        class: "py-2 px-3 rounded-sm border border-sky-900 bg-blue-600 hover:bg-blue-800 transition-colors text-white shadow-lg font-thin",
        data: { turbo_frame: "_top" }
      )
    end

    div(class: "min-w-full") do
      turbo_frame_tag :entities do
        div(data: { controller: "datatable" }) do
          text_field_tag(
            :search,
            nil,
            type: :text,
            placeholder: "#{action_message(:search)}...",
            class: "w-full border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent",
            data: { action: "input->datatable#filter" }
          )

          div(class: "my-4", data: { datatable_target: "table" }) do
            div(class: "rounded-lg border-1 border-slate-300 shadow-sm overflow-hidden") do
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
                    { class: "flex justify-center", label: model_attribute(Entity, :icon), align: :center },
                    { class: "col-span-2 flex justify-center", label: model_attribute(Entity, :entity_name), align: :center },
                    { class: "flex justify-center", label: model_attribute(Entity, :count), align: :center },
                    { class: "flex justify-center", label: model_attribute(Entity, :spent), align: :center },
                    { class: "flex justify-center", label: model_attribute(Entity, :count), align: :center },
                    { class: "flex justify-center", label: model_attribute(Entity, :spent), align: :center },
                    { class: "flex items-end justify-end", label: I18n.t(:datatable_actions), align: :right }
                  ]
                ]
              )

              if entities.present?
                entities.each do |record|
                  render Views::Entities::Entity.new(entity: record, mobile: false)
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
        turbo_frame_tag :entities do
          div(data: { controller: "datatable" }) do
            div(class: "p-3 mb-6 bg-white rounded-lg shadow-sm grid grid-cols-1 gap-2") do
              link_to(
                include_inactive? ? action_message(:show_inactive) : action_message(:hide_inactive),
                entities_path(include_inactive: include_inactive?),
                class: "p-1 rounded-sm border border-slate-700 bg-sky-500 hover:bg-blue-400 transition-colors text-white shadow-lg font-thin",
                data: { turbo_frame: "_top" }
              )

              text_field_tag(
                :search,
                nil,
                type: :text,
                placeholder: "#{action_message(:search)}...",
                class: "w-full border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent",
                data: { action: "input->datatable#filter" }
              )
            end

            div(class: "mb-8", data: { datatable_target: "table" }) do
              if entities.present?
                entities.each do |record|
                  render Views::Entities::Entity.new(entity: record, mobile: true)
                end
              else
                div(class: "border-b border-slate-200 py-2 my-2 text-lg bg-white") { I18n.t(:rows_not_found) }
              end
            end
          end

          link_to(
            new_entity_path,
            style: "margin: 30px",
            class: "fixed bottom-0 right-0 bg-blue-600 text-white rounded-full shadow-lg flex items-center justify-center z-50 active:scale-95 transition-transform",
            data: { turbo_frame: "_top" }
          ) { cached_icon(:bigger_plus) }
        end
      end
    end
  end
end
