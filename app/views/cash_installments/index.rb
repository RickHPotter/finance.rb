# frozen_string_literal: true

class Views::CashInstallments::Index < Views::Base # rubocop:disable Metrics/ClassLength
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper
  include CacheHelper
  include ColoursHelper

  attr_reader :mobile, :cash_installments, :index_context

  def initialize(mobile:, cash_installments:, index_context: {})
    @mobile = mobile
    @cash_installments = cash_installments
    @index_context = index_context
  end

  def view_template
    if mobile
      cash_installments.each do |cash_installment|
        cash_transaction = cash_installment.cash_transaction
        avatar_name = retrieve_avatar_name(cash_transaction)
        style = solid_or_gradient_style(categories_for(cash_transaction))

        render_mobile_cash_installment(cash_installment, cash_transaction, style, avatar_name)
      end
    else
      cash_installments.each do |cash_installment|
        cash_transaction = cash_installment.cash_transaction
        avatar_name = retrieve_avatar_name(cash_transaction)
        style = solid_or_gradient_style(categories_for(cash_transaction))

        render_cash_installment(cash_installment, cash_transaction, style, avatar_name)
      end
    end
  end

  def retrieve_avatar_name(cash_transaction)
    return "others/card.png" if cash_transaction.card_advance? || cash_transaction.card_payment?
    return "others/bank.png" if cash_transaction.investment?

    nil
  end

  def render_mobile_cash_installment(cash_installment, cash_transaction, style, avatar_name)
    turbo_frame_tag dom_id cash_installment do
      should_display_link_to_pay, icon = choose_link_and_icon(cash_installment)

      render Views::CashInstallments::PayModal.new(cash_installment:, index_context:) if should_display_link_to_pay || cash_transaction.card_payment?

      div(class: "relative") do
        div(
          class: "absolute -top-2 right-0 p-1 rounded-t-lg bg-yellow-400 shadow-sm border border-yellow-600 font-lekton font-bold
                  text-sm z-40 #{'animate-pulse' if should_display_link_to_pay}"
        ) do
          from_cent_based_to_float(cash_installment.balance, "R$")
        end
      end

      div(
        class: "rounded-lg shadow-sm overflow-hidden my-4 border-2 cursor-pointer #{'animate-pulse' if should_display_link_to_pay}",
        style: "background-clip: padding-box; #{style}",
        data: { id: cash_installment.id, datatable_target: :row, action: "click->datatable#toggleCardSelection" }
      ) do
        render_row_checkbox(cash_installment, mobile: true)

        div(class: "p-4") do
          div(class: "flex items-center justify-between gap-4 w-full text-sm font-semibold") do
            div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
              if cash_transaction.investment?
                default_year = cash_transaction.year
                active_month_years = "[#{Date.new(cash_transaction.year, cash_transaction.month).strftime('%Y%m')}]"
                investment = { user_bank_account_id: cash_transaction.user_bank_account_id }

                link_to cash_transaction.description,
                        investments_path(investment:, default_year:, active_month_years:, format: :turbo_stream),
                        class: "cash_transaction_description truncate text-md underline underline-offset-[3px]",
                        title: cash_transaction.comment,
                        data: { turbo_frame: :_top, turbo_prefetch: false }
              elsif cash_transaction.card_advance?
                card_ = cash_transaction.card_installments.first || CardTransaction.find_by(advance_cash_transaction: cash_transaction)
                default_year = card_.year
                active_month_years = "[#{Date.new(card_.year, card_.month).strftime('%Y%m')}]"

                link_to cash_transaction.description,
                        card_transactions_path(user_card_id: cash_transaction.user_card_id, default_year:, active_month_years:, format: :turbo_stream),
                        class: "cash_transaction_description truncate text-md underline underline-offset-[3px]",
                        title: cash_transaction.comment,
                        data: { turbo_frame: :_top, turbo_prefetch: false }
              else
                link_to cash_transaction.description, edit_cash_transaction_path(cash_transaction),
                        id: "edit_cash_transaction_#{cash_transaction.id}",
                        class: "cash_transaction_description truncate text-md underline underline-offset-[3px]",
                        title: cash_transaction.comment,
                        data: { turbo_frame: :_top }
              end

              span(class: "flex-shrink p-1 rounded-sm bg-white text-black border border-black #{'opacity-40' if cash_transaction.cash_installments_count == 1}") do
                pretty_installments(cash_installment.number, cash_installment.cash_installments_count)
              end
            end
          end

          div(class: "flex items-center justify-between py-2") do
            div(class: "text-xs text-start flex-1 flex items-center") do
              if should_display_link_to_pay
                button(
                  class: "hover:bg-white hover:text-red-400 hover:rounded-full hover:scale-160 transition-all duration-200",
                  title: model_attribute(cash_installment, :pay),
                  data: { modal_target: "cashInstallmentModal_#{cash_installment.id}", modal_toggle: "cashInstallmentModal_#{cash_installment.id}" }
                ) do
                  cached_icon(icon)
                end
              elsif cash_transaction.card_payment?
                button(
                  class: "hover:bg-white hover:text-blue-600 hover:rounded-sm hover:scale-160",
                  title: model_attribute(cash_installment, :change_date),
                  data: { modal_target: "cashInstallmentModal_#{cash_installment.id}", modal_toggle: "cashInstallmentModal_#{cash_installment.id}" }
                ) do
                  cached_icon(:check_calendar)
                end
              else
                button(
                  class: "hover:bg-white hover:text-money hover:rounded-full hover:scale-160 transition-all duration-200",
                  title: model_attribute(cash_installment, :already_paid)
                ) do
                  cached_icon(icon)
                end
              end

              span(class: "whitespace-nowrap pl-2") do
                format = cash_transaction.investment? ? "%B %Y" : :short
                I18n.l(cash_installment.date, format:)
              end
            end

            div(class: "whitespace-nowrap") do
              from_cent_based_to_float(cash_installment.price, "R$")
            end
          end

          div(class: "flex flex-wrap items-center gap-1") do
            div(class: "flex flex-wrap gap-1", data: { datatable_target: :category, id: cash_transaction.categories.map(&:id) }) do
              border = style.split("; color:").last
              categories_for(cash_transaction).each do |category|
                span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 text-xs", style: "border-color: #{border}") do
                  category.name
                end
              end
            end

            render_mobile_entities(cash_transaction, avatar_name)
          end
        end
      end
    end
  end

  def render_cash_installment(cash_installment, cash_transaction, style, avatar_name)
    turbo_frame_tag dom_id cash_installment do
      should_display_link_to_pay, icon = choose_link_and_icon(cash_installment)

      render Views::CashInstallments::PayModal.new(cash_installment:, index_context:) if should_display_link_to_pay || cash_transaction.card_payment?

      div(
        class: "grid grid-cols-12 hover:opacity-80 #{'animate-pulse' if should_display_link_to_pay}",
        style: "background-clip: padding-box; #{style}",
        draggable: true,
        data: { id: cash_installment.id,
                datatable_target: :row,
                action: "dragstart->datatable#start dragover->datatable#activate drop->datatable#drop" }
      ) do
        render_row_checkbox(cash_installment) do
          div(class: "flex-1 flex items-center justify-between gap-2 rounded-sm pl-2") do
            if should_display_link_to_pay
              button(
                type: :button,
                class: "hover:bg-white hover:text-red-500 hover:rounded-full hover:scale-160",
                title: model_attribute(cash_installment, :pay),
                data: { modal_target: "cashInstallmentModal_#{cash_installment.id}", modal_toggle: "cashInstallmentModal_#{cash_installment.id}" }
              ) do
                cached_icon(icon)
              end
            elsif cash_transaction.card_payment?
              button(
                class: "hover:bg-white hover:text-blue-600 hover:rounded-sm hover:scale-160",
                title: model_attribute(cash_installment, :change_date),
                data: { modal_target: "cashInstallmentModal_#{cash_installment.id}", modal_toggle: "cashInstallmentModal_#{cash_installment.id}" }
              ) do
                cached_icon(:check_calendar)
              end
            else
              span(class: "hover:bg-white hover:text-money hover:rounded-sm hover:scale-160", title: model_attribute(cash_installment, :already_paid)) do
                cached_icon(icon)
              end
            end

            date, time = I18n.l(cash_installment.date, format: :shorter).split(",")
            div(class: "grid grid-cols-1 mr-auto") do
              span(class: "rounded-xs text-xs mr-auto") { date }
              span(class: "rounded-xs text-xs mr-auto") { time }
            end
          end
        end

        div(class: "col-span-4 flex-1 flex items-center justify-between gap-1 min-w-0 mx-2") do
          if cash_transaction.investment?
            default_year = cash_transaction.year
            active_month_years = "[#{Date.new(cash_transaction.year, cash_transaction.month).strftime('%Y%m')}]"
            investment = { user_bank_account_id: cash_transaction.user_bank_account_id }

            link_to cash_transaction.description,
                    investments_path(investment:, default_year:, active_month_years:, format: :turbo_stream),
                    class: "cash_transaction_description flex-1 truncate text-md underline underline-offset-[3px]",
                    title: cash_transaction.comment,
                    data: { turbo_frame: :_top, turbo_prefetch: false }
          elsif cash_transaction.card_advance?
            card_ = cash_transaction.card_installments.first || CardTransaction.find_by(advance_cash_transaction: cash_transaction)
            default_year = card_.year
            active_month_years = "[#{Date.new(card_.year, card_.month).strftime('%Y%m')}]"

            link_to cash_transaction.description,
                    card_transactions_path(user_card_id: cash_transaction.user_card_id, default_year:, active_month_years:, format: :turbo_stream),
                    class: "cash_transaction_description flex-1 truncate text-md underline underline-offset-[3px]",
                    title: cash_transaction.comment,
                    data: { turbo_frame: :_top, turbo_prefetch: false }
          else
            link_to cash_transaction.description,
                    edit_cash_transaction_path(cash_transaction),
                    id: "edit_cash_transaction_#{cash_transaction.id}",
                    class: "cash_transaction_description flex-1 truncate text-md underline underline-offset-[3px]",
                    title: cash_transaction.comment,
                    data: { turbo_frame: :_top }
          end

          span(class: "p-1 rounded-sm bg-white text-black border border-black flex-shrink-0 #{'opacity-40' if cash_installment.cash_installments_count == 1}") do
            pretty_installments(cash_installment.number, cash_installment.cash_installments_count)
          end
        end

        div(class: "col-span-3 py-2 flex items-center justify-center gap-2", data: { datatable_target: :category, id: cash_transaction.categories.map(&:id) }) do
          categories_for(cash_transaction).each do |category|
            border = style.split("; color:").last
            span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border-1 text-sm", style: "border-color: #{border}") do
              category.name
            end
          end
        end

        render_desktop_entities(cash_transaction, avatar_name)

        div(class: "py-2 flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto") do
          from_cent_based_to_float(cash_installment.price, "R$")
        end

        div(class: "flex items-center justify-center font-lekton font-bold whitespace-nowrap ml-auto mr-1") do
          div(class: "p-1 rounded-md shadow-sm border border-black") do
            from_cent_based_to_float(cash_installment.balance, "R$")
          end
        end
      end
    end
  end

  def choose_link_and_icon(cash_installment)
    case [ cash_installment.paid, cash_installment.date > Time.zone.today ]
    in [ true,  _     ] then [ false, :check_square ]
    in [ false, true  ] then [ true,  :warning_octagon ]
    in [ false, false ] then [ true,  :x_circle ]
    end
  end

  def render_mobile_entities(cash_transaction, avatar_name)
    items = cash_entity_popover_items(cash_transaction, avatar_name, :id)

    render Views::Entities::Popover.new(
      items:,
      mobile: true,
      target_ids: cash_transaction.entities.map(&:id),
      trigger_label: pluralise_model(Entity, items.count).upcase,
      variant: :cash
    )
  end

  def render_desktop_entities(cash_transaction, avatar_name)
    render Views::Entities::Popover.new(
      items: cash_entity_popover_items(cash_transaction, avatar_name, :entity_id),
      mobile: false,
      target_ids: cash_transaction.entities.map(&:id),
      trigger_label: "",
      variant: :cash
    )
  end

  def categories_for(cash_transaction)
    cash_transaction.category_transactions.sort_by(&:id).filter_map(&:category)
  end

  def entities_for(cash_transaction, sort_key)
    cash_transaction.entity_transactions.sort_by(&sort_key).filter_map(&:entity)
  end

  def cash_entity_popover_items(cash_transaction, avatar_name, sort_key)
    entities_for(cash_transaction, sort_key).map do |entity|
      {
        name: entity.entity_name,
        avatar_name: avatar_name || entity.avatar_name,
        href: new_cash_transaction_path(cash_transaction: { entity_id: entity.id }, format: :turbo_stream),
        data: { turbo_frame: "_top", turbo_prefetch: "false" }
      }
    end
  end

  def render_row_checkbox(cash_installment, mobile: false)
    div(class: "flex items-center gap-1 relative px-2") do
      label(class: "group inline-flex cursor-pointer items-center justify-center") do
        input(
          type: :checkbox,
          value: cash_installment.id,
          class: "peer sr-only",
          disabled: cash_installment.paid?,
          data: { datatable_target: :checkbox, action: "change->datatable#toggleSelection" }
        )

        unless mobile
          span(
            class: "flex items-center justify-center rounded-full border border-zinc-700 bg-white shadow-sm transition-all
                peer-checked:border-blue-600 peer-checked:bg-blue-600 peer-checked:text-white
                peer-focus:ring-2 peer-focus:ring-blue-300 size-6
                peer-disabled:bg-slate-300 peer-disabled:text-slate-400"
          ) do
            span(class: "text-[10px] font-bold opacity-0 transition-opacity peer-checked:opacity-100") { "✓" }
          end
        end
      end

      yield if block_given?
    end
  end
end
