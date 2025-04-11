# frozen_string_literal: true

class Views::Investments::MonthYear < Views::Base
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include CacheHelper

  attr_reader :mobile, :month_year, :month_year_str, :investments

  def initialize(mobile:, month_year:, month_year_str:, investments:)
    @month_year = month_year
    @mobile = mobile
    @month_year_str = month_year_str
    @investments = investments
  end

  def view_template
    turbo_frame_tag "month_year_container_#{month_year}" do
      if mobile
        render_mobile_month_year
      else
        render_month_year
      end
    end
  end

  def render_mobile_month_year
    div(class: "mb-8", data: { datatable_target: :table }) do
      span(class: "py-3 col-start-7 text-end", id: :priceSum, data: { controller: "price-sum", price: investments.sum(:price) })
      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg p-4 mb-4") do
        legend(class: "px-2 text-lg text-slate-800 text-start") { month_year_str }

        render_mobile_investments
      end
    end
  end

  def render_month_year
    div(class: "mb-8", data: { datatable_target: :table }) do
      span(class: "py-3 col-start-7 text-end", id: :priceSum, data: { controller: "price-sum", price: investments.sum(:price) })
      fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg p-4 mb-4") do
        legend(class: "px-2 text-lg text-slate-800 text-start") { month_year_str }

        div(class: "bg-white rounded-lg border-1 border-slate-300 shadow-sm overflow-hidden") do
          div(class: "grid grid-cols-6 py-1 bg-slate-200 border-b border-slate-400 rounded-t-lg font-semibold text-black font-graduate") do
            div(class: "py-3")            { model_attribute(Investment, :date) }
            div(class: "py-3 col-span-2") { model_attribute(Investment, :description) }
            div(class: "py-3")            { model_attribute(Investment, :user_bank_account_id) }
            div(class: "py-3 text-end")   { model_attribute(Investment, :price) }
            div(class: "py-3")            { I18n.t(:datatable_actions) }
          end

          if investments.present?
            render_investments
          else
            div(class: "border-b border-slate-200 py-2 my-2 text-lg") { I18n.t(:rows_not_found) }
          end

          div(class: "grid grid-cols-6 py-1 bg-slate-200 border-b border-slate-400 rounded-t-lg font-semibold text-black font-graduate") do
            span(class: "py-3 col-span-4 text-center") { "#{model_attribute(Investment, :total_amount)}:" }

            span(class: "py-3 col-start-5 text-end", id: :priceSum, data: { controller: "price-sum", price: investments.sum(:price) }) do
              from_cent_based_to_float(investments.sum(:price), "R$")
            end
          end
        end
      end
    end
  end

  def render_mobile_investments
    investments.each do |investment|
      turbo_frame_tag dom_id investment do
        div(
          class: "rounded-lg shadow-sm overflow-hidden bg-slate-200 my-2",
          data: { id: investment.id, datatable_target: :row }
        ) do
          div(class: "p-4") do
            div(class: "flex items-center justify-between gap-4 w-full text-black text-sm font-semibold") do
              div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
                link_to investment.description,
                        edit_investment_path(investment),
                        id: "edit_investment_#{investment.id}",
                        class: "truncate text-md underline underline-offset-[3px]",
                        data: { turbo_frame: :center_container }

                span(class: "p-1 rounded-sm bg-white border border-black flex-shrink-0") do
                  investment.user_bank_account.user_bank_account_name
                end
              end
            end

            div(class: "flex items-center justify-between py-2") do
              span(class: "text-xs text-start flex-1") { I18n.l(investment.date, format: :short) }

              div(class: "whitespace-nowrap") do
                from_cent_based_to_float(investment.price, "R$")
              end
            end
          end
        end
      end
    end
  end

  def render_investments
    investments.each do |investment|
      turbo_frame_tag dom_id investment do
        div(
          class: "grid grid-cols-6 border-b border-slate-200 bg-gradient-to-r hover:opacity-60",
          data: { id: investment.id, datatable_target: :row }
        ) do
          div(class: "p-2 flex items-center justify-between") do
            span(class: "px-1 rounded-sm text-slate-900 mx-auto") { I18n.l(investment.date, format: :shorter) }
          end

          div(class: "col-span-2 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2") do
            link_to investment.description,
                    edit_investment_path(investment),
                    id: "edit_investment_#{investment.id}",
                    class: "flex-1 truncate text-md underline underline-offset-[3px]",
                    data: { turbo_frame: :center_container }
          end

          div(class: "py-2 flex items-center justify-center gap-2") do
            span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 border-black text-sm") do
              investment.user_bank_account.user_bank_account_name
            end
          end

          div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto") do
            from_cent_based_to_float(investment.price, "R$")
          end

          div(class: "py-2 flex items-center justify-center") do
            div(class: "flex items-center justify-center px-2 my-1 rounded-md") do
              link_to investment,
                      id: "delete_investment_#{investment.id}",
                      class: "text-red-600 hover:text-red-800 mx-2 bg-white rounded-4xl",
                      data: { turbo_method: :delete, turbo_confirm: I18n.t("confirmation.sure") } do
                cached_icon :destroy
              end
            end
          end
        end
      end
    end
  end
end
