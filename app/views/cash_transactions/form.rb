# frozen_string_literal: true

class Views::CashTransactions::Form < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::TextFieldTag
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :current_user, :cash_transaction

  def initialize(current_user:, cash_transaction:)
    @current_user = current_user
    @cash_transaction = cash_transaction

    set_banks
    set_user_bank_accounts
    set_categories
    set_entities
  end

  def view_template
    turbo_frame_tag dom_id cash_transaction do
      form_with model: cash_transaction,
                id: :transaction_form,
                class: "contents text-black",
                data: { controller: "reactive-form price-mask", reactive_form_type_value: "CashTransaction", action: "submit->price-mask#removeMasks" } do |form|
        form.hidden_field :user_id, value: current_user.id
        form.hidden_field :reference_transactable_type,
                          value: cash_transaction.reference_transactable_type || params.dig(:cash_transaction, :reference_transactable_type)
        form.hidden_field :reference_transactable_id,
                          value: cash_transaction.reference_transactable_id   || params.dig(:cash_transaction, :reference_transactable_id)

        hidden_field_tag :category_colours,       categories_json,        disabled: true, data: { reactive_form_target: :categoryColours }
        hidden_field_tag :entity_icons,           entities_json,          disabled: true, data: { reactive_form_target: :entityIcons }
        hidden_field_tag :exchange_category_id,   exchange_category.id,   disabled: true, id: :exchange_category_id
        hidden_field_tag :exchange_category_name, exchange_category.name, disabled: true, id: :exchange_category_name

        render Views::Transactions::FormIntroFields.new(
          form:,
          transaction: cash_transaction,
          description_class: cash_transaction.card_payment? ? outdoor_readonly_input_class : outdoor_input_class,
          comment_disabled: cash_transaction.card_payment?,
          autofocus_target: :description
        )
        render Views::CashTransactions::FormControls.new(
          form:,
          cash_transaction:,
          user_bank_accounts: @user_bank_accounts,
          categories: @categories,
          entities: @entities
        )
        render Views::CashTransactions::FormInstallmentsSection.new(form:, cash_transaction:)
        render Views::Transactions::FormCategoriesSection.new(form:, transaction: cash_transaction)
        render Views::Transactions::FormEntitiesSection.new(form:, transaction: cash_transaction)

        render Views::Transactions::FormActions.new(
          transaction: cash_transaction,
          destroy_href: cash_transaction.persisted? ? cash_transaction_path(cash_transaction) : nil,
          destroy_id: cash_transaction.persisted? ? "delete_cash_transaction_#{cash_transaction.id}" : nil
        ) do
          if cash_transaction.exchange_return?
            transactables_type = cash_transaction.exchanges.joins(:entity_transaction).pluck(:transactable_type)
            card_transactions_sheet if transactables_type.include?("CardTransaction")
            cash_transactions_sheet if transactables_type.include?("CashTransaction")
          end

          if cash_transaction.card_payment?
            card_ = cash_transaction.card_installments.first || CardTransaction.find_by(advance_cash_transaction: cash_transaction)
            default_year = card_.year
            active_month_years = "[#{Date.new(card_.year, card_.month).strftime('%Y%m')}]"

            Link(
              href: card_transactions_path(user_card_id: cash_transaction.user_card_id, default_year:, active_month_years:, format: :turbo_stream),
              variant: :outline,
              class: "flex flex-col items-center text-center text-inherit",
              data: { turbo_frame: "_top", turbo_prefetch: "false" }
            ) do
              action_model(:index, CardTransaction, 2)
            end
          end
        end

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end

  def categories_json
    current_user.categories.to_h do |c|
      [ c.id, c.hex_colour ]
    end.to_json
  end

  def entities_json
    current_user.entities.to_h do |c|
      [ c.id, asset_path("avatars/#{c.avatar_name}") ]
    end.to_json
  end

  def exchange_category
    current_user.built_in_category("EXCHANGE")
  end

  def card_transactions_sheet
    Sheet do
      SheetTrigger do
        Button(type: :button, class: "min-w-64") do
          action_model(:index, CardTransaction, 2)
        end
      end

      SheetContent(side: :middle, class: "w-full md:w-1/3 max-h-[90vh] flex flex-col") do
        SheetHeader do
          SheetTitle { pluralise_model(CardTransaction, 2) }
          SheetDescription do
            span { current_user.built_in_category("EXCHANGE RETURN").name }
          end
        end

        SheetMiddle(class: "overflow-y-auto flex-1") do
          SheetMiddle do
            exchanges = cash_transaction.exchanges
            entity_transactions = exchanges.map(&:entity_transaction).flatten
            card_transactions_ids = entity_transactions.pluck(:transactable_id)

            reference = cash_transaction.exchanges.first
            year, month = reference.slice(:year, :month).values

            index_context = {
              current_user:,
              years: [ year ],
              default_year: year,
              active_month_years: [ Date.new(year, month).strftime("%Y%m") ],
              search_term: "",
              card_installment_ids: current_user
                                    .card_installments
                                    .where(year: reference.year, month: reference.month, card_transaction_id: card_transactions_ids)
                                    .order(:order_id)
                                    .ids,
              category_id: [ exchange_category.id ],
              entity_id: cash_transaction.entities.pluck(:id),
              user_bank_account_id: nil,
              from_ct_price: nil,
              to_ct_price: nil,
              from_price: nil,
              to_price: nil,
              from_installments_count: nil,
              to_installments_count: nil,
              user_card: nil,
              skip_budgets: true,
              force_mobile: true
            }

            render Views::CardTransactions::MonthYearContainer.new(index_context:)
          end
        end
      end
    end
  end

  def cash_transactions_sheet
    Sheet do
      SheetTrigger do
        Button(type: :button, class: "min-w-64") do
          action_model(:index, CashTransaction, 2)
        end
      end

      SheetContent(side: :middle, class: "w-full md:w-1/3 max-h-[90vh] flex flex-col") do
        SheetHeader do
          SheetTitle { pluralise_model(CashTransaction, 2) }
          SheetDescription do
            span { current_user.built_in_category("EXCHANGE RETURN").name }
          end
        end

        SheetMiddle(class: "overflow-y-auto flex-1") do
          SheetMiddle do
            exchanges = cash_transaction.exchanges
            entity_transactions = exchanges.map(&:entity_transaction).flatten
            card_transactions_ids = entity_transactions.pluck(:transactable_id)

            reference = cash_transaction.exchanges.first
            year, month = reference.slice(:year, :month).values

            index_context = {
              current_user:,
              years: [ year ],
              default_year: year,
              active_month_years: [ Date.new(year, month).strftime("%Y%m") ],
              search_term: "",
              card_installment_ids: current_user
                                    .cash_installments
                                    .where(year: reference.year, month: reference.month, card_transaction_id: card_transactions_ids)
                                    .order(:order_id)
                                    .ids,
              category_id: [ exchange_category.id ],
              entity_id: cash_transaction.entities.pluck(:id),
              user_bank_account_id: nil,
              from_ct_price: nil,
              to_ct_price: nil,
              from_price: nil,
              to_price: nil,
              from_installments_count: nil,
              to_installments_count: nil,
              user_card: nil,
              skip_budgets: true,
              force_mobile: true
            }

            render Views::CashTransactions::MonthYearContainer.new(index_context:)
          end
        end
      end
    end
  end
end
