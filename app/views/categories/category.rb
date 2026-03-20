# frozen_string_literal: true

class Views::Categories::Category < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::Cycle

  include CacheHelper
  include ColoursHelper
  include TranslateHelper

  attr_reader :category, :mobile

  def initialize(category:, mobile: false)
    @category = category
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag dom_id(category) do
      mobile ? mobile_row : desktop_row
    end
  end

  private

  def desktop_row
    bg = solid_or_gradient_style(category)
    text = auto_text_color(category.hex_colour)

    div(
      class: "grid grid-cols-7 border-b border-slate-200 #{cycle('bg-gray-100', 'bg-gray-200')} hover:bg-white",
      data: { id: category.id, datatable_target: :row }
    ) do
      div(class: "col-span-2 px-1 flex items-center mx-auto font-lekton font-semibold") do
        span(class: "px-4 whitespace-nowrap border-0 rounded-sm shadow-md", style: "background-clip: padding-box; #{bg}; #{text}") { category.name }
      end

      div(class: "jump_to_card_transactions px-1 flex items-center justify-center font-anonymous font-semibold whitespace-nowrap text-md") do
        if category.card_transactions_count.positive?
          link_to(
            category.card_transactions_count,
            search_card_transactions_path(card_transaction: { category_id: category.id }, all_month_years: true),
            class: "text-indigo-600 hover:underline",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          )
        else
          span { category.card_transactions_count }
        end
      end

      div(class: "flex items-center justify-center font-lekton font-normal text-lg whitespace-nowrap") do
        span do
          from_cent_based_to_float(category.card_transactions_total, "R$")
        end
      end

      div(class: "jump_to_cash_transactions px-1 flex items-center justify-center font-anonymous font-semibold whitespace-nowrap text-md") do
        if category.cash_transactions_count.positive?
          link_to(
            category.cash_transactions_count,
            cash_transactions_path(cash_transaction: { category_id: category.id }, all_month_years: true),
            class: "text-indigo-600 hover:underline",
            data: { turbo_frame: "_top", turbo_prefetch: false }
          )
        else
          span { category.cash_transactions_count }
        end
      end

      div(class: "flex items-center justify-center font-lekton font-normal text-lg whitespace-nowrap") do
        span do
          from_cent_based_to_float(category.cash_transactions_total, "R$")
        end
      end

      div(class: "flex items-center justify-center") do
        div(class: "flex items-center justify-center px-2 my-1 rounded-md") do
          link_to(edit_category_path(category), id: "edit_category_#{category.id}",
                                                class: "text-blue-600 hover:text-blue-800 mx-2 bg-sky-200 rounded-4xl",
                                                data: { turbo_frame: "_top" }) { cached_icon(:pencil) }

          if category.built_in == false
            link_to(category_path(category), id: "delete_category_#{category.id}",
                                             class: "text-red-600 hover:text-red-800 mx-2 bg-rose-200 rounded-4xl",
                                             data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") }) { cached_icon(:destroy) }
          end
        end
      end
    end
  end

  def mobile_row
    bg = solid_or_gradient_style(category)
    text = auto_text_color(category.hex_colour)

    div(class: "rounded-lg shadow-sm overflow-hidden my-3", data: { id: category.id, datatable_target: :row }) do
      div(class: "p-4 whitespace-nowrap border-0 rounded-sm shadow-md", style: "background-clip: padding-box; #{bg}; #{text}") do
        div(class: "flex items-center justify-between") do
          div(class: "flex items-center space-x-3") do
            cached_icon :category
            link_to(category.name, edit_category_path(category), id: "edit_category_#{category.id}",
                                                                 class: "text-lg font-semibold underline underline-offset-[3px]",
                                                                 data: { turbo_frame: "_top" })
          end
        end
      end

      div(class: "p-4") do
        div(class: "grid grid-cols-2 gap-4 my-2") do
          div(class: "space-y-1") do
            div(class: "flex items-center text-sm font-medium text-slate-500") do
              cached_icon :number
              span(class: "ml-2") { pluralise_model(CardTransaction, 2) }
            end

            div(class: "flex items-center") { span(class: "text-sm font-semibold text-slate-800") { category.card_transactions_count } }
          end

          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :money
              span(class: "text-sm font-medium text-slate-500") { model_attribute(CardTransaction, :total_amount) }
            end

            div(class: "flex items-center") do
              span(class: "text-sm font-semibold text-slate-800 mr-auto") { from_cent_based_to_float(category.card_transactions_total, "R$") }
              link_to(search_card_transactions_path(card_transaction: { category_id: category.id }, all_month_years: true),
                      class: "my-auto mt-[-1rem]", data: { turbo_frame: "_top", turbo_prefetch: false }) { cached_icon(:jump_to) }
            end
          end
        end

        div(class: "grid grid-cols-2 gap-4 my-2") do
          div(class: "space-y-1") do
            div(class: "flex items-center text-sm font-medium text-slate-500") do
              cached_icon :number
              span(class: "ml-2") { pluralise_model(CashTransaction, 2) }
            end

            div(class: "flex items-center") { span(class: "text-sm font-semibold text-slate-800") { category.cash_transactions_count } }
          end

          div(class: "space-y-1") do
            div(class: "flex items-center space-x-2") do
              cached_icon :money
              span(class: "text-sm font-medium text-slate-500") { model_attribute(CashTransaction, :total_amount) }
            end

            div(class: "flex items-center") do
              span(class: "text-sm font-semibold text-slate-800 mr-auto") { from_cent_based_to_float(category.cash_transactions_total, "R$") }
              link_to(cash_transactions_path(cash_transaction: { category_id: category.id }, all_month_years: true, mobile: true),
                      class: "my-auto mt-[-1rem]", data: { turbo_frame: "_top", turbo_prefetch: false }) { cached_icon(:jump_to) }
            end
          end
        end
      end
    end
  end
end
