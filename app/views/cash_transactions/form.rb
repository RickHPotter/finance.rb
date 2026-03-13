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
            exchanges = exchange_sheet_exchanges_for("CardTransaction")
            render_bound_card_transactions_sheet(exchanges)
            render_exchange_transaction_groups(exchanges.standalone, CardTransaction)
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
            exchanges = exchange_sheet_exchanges_for("CashTransaction")
            render_exchange_transaction_groups(exchanges, CashTransaction)
          end
        end
      end
    end
  end

  def exchange_sheet_exchanges_for(transactable_type)
    cash_transaction.exchanges
                    .joins(:entity_transaction)
                    .where(entity_transactions: { transactable_type: })
                    .order(:year, :month, :number, :date)
  end

  def render_bound_card_transactions_sheet(exchanges)
    card_bound_exchanges = exchanges.card_bound
    return if card_bound_exchanges.blank?

    related_transaction_ids = card_bound_exchanges.pluck(:entity_transaction_id).uniq
    related_transaction_ids = EntityTransaction.where(id: related_transaction_ids).pluck(:transactable_id).uniq
    installments = current_user.card_installments
                               .includes(card_transaction: %i[categories entities entity_transactions])
                               .where(card_transaction_id: related_transaction_ids)
                               .where(year: cash_transaction.year, month: cash_transaction.month)
                               .order(:order_id)

    render Views::Transactions::CardBoundTransactionsSheet.new(
      label: I18n.t("activerecord.attributes.exchange.card_bound"),
      installments:,
      user_card_id: cash_transaction.user_card_id
    )
  end

  def render_exchange_transaction_groups(exchanges, transaction_class)
    transactions = standalone_exchange_transactions(exchanges)
    return if transactions.empty?

    render Views::Transactions::StandaloneTransactionsSheet.new(transactions:, transaction_class:)
  end

  def standalone_exchange_transactions(exchanges)
    transactions = exchanges.filter_map { |exchange| exchange.entity_transaction.transactable }.uniq(&:id)

    preload_standalone_transactions(transactions)
    transactions
  end

  def preload_standalone_transactions(transactions)
    cash_transactions, card_transactions = transactions.partition { |transaction| transaction.is_a?(CashTransaction) }

    ActiveRecord::Associations::Preloader.new(
      records: cash_transactions,
      associations: [
        { category_transactions: :category },
        { entity_transactions: :entity },
        :cash_installments
      ]
    ).call

    ActiveRecord::Associations::Preloader.new(
      records: card_transactions,
      associations: [
        { category_transactions: :category },
        { entity_transactions: :entity },
        :card_installments
      ]
    ).call
  end
end
