# frozen_string_literal: true

class Views::CardTransactions::Form < Views::Base
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::Routes
  include Views::CardTransactions

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :current_user, :card_transaction, :chain_context, :return_to

  def initialize(current_user:, card_transaction:, chain_context: nil, return_to: "/card_transactions")
    @current_user = current_user
    @card_transaction = card_transaction
    @chain_context = chain_context
    @return_to = return_to

    set_cards
    set_user_cards
    set_categories
    set_leaf_categories
    set_entities

    @user_cards << card_transaction.user_card.slice(:user_card_name, :id).values if card_transaction.user_card.inactive?
  end

  def which_target_to_autofocus(card_transaction)
    return :time                 if params[:next_autofocus] == "time"
    return :date                 if card_transaction.duplicate && params[:commit] != "Update"
    return :description          if params[:commit] != "Update"
    return :category_transaction if card_transaction.category_transactions.empty?
    return :entity_transaction   if card_transaction.entity_transactions.empty?

    :date
  end

  def view_template
    user_card_date = card_transaction.user_card.calculate_reference_date(card_transaction.date).to_datetime
    autofocus_target = which_target_to_autofocus(card_transaction)
    receipts_upload = Components::TransactionReceiptsUpload.new(transaction: card_transaction, form: nil)

    turbo_frame_tag dom_id @card_transaction do
      form_with(
        model: card_transaction,
        id: :transaction_form,
        class: "contents text-slate-100",
        data: {
          controller: "reactive-form price-mask composite-transaction attachment-upload",
          composite_transaction_composite_value: card_transaction.composite?,
          reactive_form_preserve_installment_prices_value: card_transaction.persisted?,
          action: "submit->price-mask#removeMasks",
          operation_type: card_transaction.operation_type,
          attachment_upload_model_name_value: card_transaction.model_name.param_key,
          attachment_upload_direct_upload_url_value: rails_direct_uploads_path,
          attachment_upload_existing_count_value: receipts_upload.existing_count,
          attachment_upload_max_files_value: 5,
          attachment_upload_max_file_size_value: 10.megabytes.to_i,
          attachment_upload_too_large_message_value: I18n.t("attachments.too_large"),
          attachment_upload_invalid_type_message_value: I18n.t("attachments.invalid_type"),
          attachment_upload_max_count_message_value: I18n.t("attachments.max_count"),
          attachment_upload_uploading_message_value: I18n.t("attachments.uploading")
        }
      ) do |form|
        form.hidden_field :user_id, value: current_user.id
        form.hidden_field :duplicate
        # Hidden split_purchase field so the tab controller can update it
        form.hidden_field :split_purchase, value: card_transaction.composite? ? "1" : "0"
        hidden_field_tag :return_to, return_to

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
          user_card_date:,
          attachment_modal_id: receipts_upload.modal_id,
          existing_count: receipts_upload.existing_count
        )

        # Tabbed section: Single Purchase | Split Purchase
        default_tab = card_transaction.composite? ? "split" : "single"
        composite = card_transaction.composite?

        Tabs(default: default_tab, class: "mb-3") do
          TabsList(class: "w-full justify-start rounded-none border-b border-slate-200 bg-transparent p-0 dark:border-slate-700/50 h-auto") do
            TabsTrigger(
              value: "single",
              tabindex: -1,
              class: "rounded-none border-b-2 border-transparent px-4 py-2 text-sm font-medium text-slate-600 data-[state=active]:border-slate-800 " \
                     "data-[state=active]:text-slate-900 dark:text-slate-400 dark:data-[state=active]:border-slate-200 dark:data-[state=active]:text-slate-100",
              data: { action: "click->composite-transaction#tabChanged" }
            ) { I18n.t("transactions.composite.single_purchase") }
            TabsTrigger(
              value: "split",
              tabindex: -1,
              class: "rounded-none border-b-2 border-transparent px-4 py-2 text-sm font-medium text-slate-600 data-[state=active]:border-slate-800 " \
                     "data-[state=active]:text-slate-900 dark:text-slate-400 dark:data-[state=active]:border-slate-200 dark:data-[state=active]:text-slate-100",
              data: { action: "click->composite-transaction#tabChanged" }
            ) { I18n.t("transactions.composite.split_purchase") }
          end

          # Single Purchase tab: Categories (A1) + Entities (A2)
          TabsContent(value: "single", class: "mt-0") do
            div(
              class: "grid grid-cols-1 md:grid-cols-2 items-start pt-2 #{'pointer-events-none opacity-50' if composite}",
              data: { composite_transaction_target: "allocationsContainer" }
            ) do
              render Views::Transactions::FormCategoriesSection.new(form:, transaction: card_transaction)
              render Views::Transactions::FormEntitiesSection.new(form:, transaction: card_transaction)
            end
          end

          # Split Purchase tab: line items (always expanded)
          TabsContent(value: "split", class: "mt-0 pt-2") do
            render Views::Transactions::FormLineItemsSection.new(
              form:,
              transaction: card_transaction,
              categories: @leaf_categories,
              entities: @entities
            )
          end
        end

        # Receipts upload: modal + hidden inputs (button is in FormControls row)
        render receipts_upload

        render Views::CardTransactions::FormInstallmentsSection.new(form:, card_transaction:)

        render Views::Transactions::FormActions.new(
          transaction: card_transaction,
          destroy_href: card_transaction.persisted? ? card_transaction_path(card_transaction, return_to:) : nil,
          destroy_id: card_transaction.persisted? ? "delete_card_transaction_#{card_transaction.id}" : nil,
          duplicate_href: card_transaction.persisted? ? duplicate_card_transaction_path(card_transaction, return_to:) : nil,
          confirmation_submit: historical_correction_confirmation_submit_for(card_transaction, :card_transaction),
          chain_context:,
          canonical_navigation: true
        )

        form.submit "Update", class: "opacity-0 pointer-events-none", data: { reactive_form_target: :updateButton }
      end
    end
  end

  def categories_json
    current_user.categories.to_h do |c|
      presentation = CategoryColours::Presentation.for(c)
      [ c.id, { background_colour: presentation.background, text_colour: presentation.foreground } ]
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

  def historical_correction_confirmation_submit_for(transaction, param_key)
    return unless transaction.persisted?

    {
      field_id: "#{param_key}_historical_correction_confirmation",
      name: "#{param_key}[historical_correction_confirmation]",
      value: "1",
      checked: ActiveModel::Type::Boolean.new.cast(transaction.historical_correction_confirmation),
      label: I18n.t("actions.confirm_historical_change")
    }
  end
end
