# frozen_string_literal: true

class Views::CardTransactions::Form < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::TextFieldTag
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::AssetPath
  include Views::CardTransactions

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :current_user, :card_transaction

  def initialize(current_user:, card_transaction:)
    @current_user = current_user
    @card_transaction = card_transaction

    set_cards
    set_user_cards
    set_categories
    set_entities

    @user_cards << card_transaction.user_card.slice(:user_card_name, :id).values if card_transaction.user_card.inactive?
  end

  def which_target_to_autofocus(card_transaction)
    return :date                 if card_transaction.duplicate && params[:commit] != "Update"
    return :description          if params[:commit] != "Update"
    return :category_transaction if card_transaction.category_transactions.empty?
    return :entity_transaction   if card_transaction.entity_transactions.empty?

    :date
  end

  def view_template
    user_card_date = card_transaction.user_card.calculate_reference_date(card_transaction.date).to_datetime
    autofocus_target = which_target_to_autofocus(card_transaction)

    turbo_frame_tag dom_id @card_transaction do
      form_with(
        model: card_transaction,
        id: :transaction_form,
        class: "contents text-black",
        data: { controller: "reactive-form price-mask", action: "submit->price-mask#removeMasks", operation_type: card_transaction.operation_type }
      ) do |form|
        form.hidden_field :user_id, value: current_user.id
        form.hidden_field :duplicate

        hidden_field_tag :category_colours, categories_json, disabled: true, data: { reactive_form_target: :categoryColours }
        hidden_field_tag :entity_icons,     entities_json,   disabled: true, data: { reactive_form_target: :entityIcons }

        hidden_field_tag :exchange_category_id,   exchange_category.id,   disabled: true, id: :exchange_category_id
        hidden_field_tag :exchange_category_name, exchange_category.name, disabled: true, id: :exchange_category_name

        render Views::Transactions::FormIntroFields.new(
          form:,
          transaction: card_transaction,
          description_class: outdoor_input_class,
          autofocus_target:
        )
        render Views::CardTransactions::FormControls.new(
          form:,
          card_transaction:,
          user_cards: @user_cards,
          categories: @categories,
          entities: @entities,
          autofocus_target:,
          user_card_date:
        )
        render Views::CardTransactions::FormInstallmentsSection.new(form:, card_transaction:)
        render Views::Transactions::FormCategoriesSection.new(form:, transaction: card_transaction)
        render Views::Transactions::FormEntitiesSection.new(form:, transaction: card_transaction)
        render Views::Transactions::FormActions.new(
          transaction: card_transaction,
          destroy_href: card_transaction.persisted? ? card_transaction_path(card_transaction) : nil,
          destroy_id: card_transaction.persisted? ? "delete_card_transaction_#{card_transaction.id}" : nil,
          duplicate_href: card_transaction.persisted? ? duplicate_card_transaction_path(card_transaction) : nil
        )

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
end
