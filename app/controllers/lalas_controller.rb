# frozen_string_literal: true

# Controller for unauthenticated external entity ledgers.
class LalasController < ApplicationController
  include TranslateHelper

  skip_before_action :authenticate_user!
  before_action :authenticate_user!, if: :internal_request?
  before_action :set_user_agent, :set_tabs

  def index
    render Views::Lalas::Index.new
  end

  def set_user_agent
    return unless request.user_agent =~ /Mobile|Android|iPhone|iPad/

    @mobile = true
  end

  def set_tabs(active_menu: :cash, active_sub_menu: :pix)
    @active_menu = active_menu
    @active_sub_menu = active_sub_menu

    set_variables
  end

  private

  def user
    @user ||= if internal_request?
                current_user
              elsif params[:user_slug].present?
                User.all.detect { |candidate| external_slug_for(candidate.first_name.presence || candidate.email.split("@").first) == params[:user_slug] } ||
                  raise(ActiveRecord::RecordNotFound, "External user not found")
              else
                User.first
              end
  end

  def lala
    @lala ||= begin
      target_slug = external_entity_slug.to_s.parameterize
      entity = Entity.where(user_id: user.id).find_each.detect { |record| external_slug_for(record.entity_name) == target_slug }
      raise ActiveRecord::RecordNotFound, "External entity not found" if entity.blank? && scoped_entity_request?

      entity
    end
  end

  def lala_context
    user.main_context
  end

  def exchange_category
    user.categories.find_by(category_name: "EXCHANGE")
  end

  def user_cards
    return user.user_cards if exchange_category.nil? && lala.nil?

    user.user_cards
        .joins(card_transactions: %i[category_transactions entity_transactions])
        .where(card_transactions: { context_id: lala_context.id })
        .where(category_transactions: { category_id: exchange_category.id })
        .where(entity_transactions: { entity_id: lala.id })
        .group("user_cards.id")
        .order(active: :desc)
  end

  def set_variables
    @main_items = [ { label: t("tabs.pix"), icon: :mobile, link: external_cash_transactions_index_path, default: @active_menu == :pix } ]

    card_items = user_cards.pluck(:id, :user_card_name).map do |user_card_id, user_card_name|
      default = @active_sub_menu.to_sym == user_card_name.to_sym
      { label: user_card_name, icon: :credit_card, link: external_card_transactions_index_path(user_card_id:), default: }
    end

    @main_items += card_items

    @main_items.first[:default] = true if @main_items.pluck(:default).uniq == [ false ]
    @main_items.map! { |item| item.slice(:label, :icon, :link, :default).values }

    @main_tab = @main_items.map do |label, icon, link, default|
      Item.new(label, icon, link, default, 0)
    end

    @main_tab.each { |tab| tab.label = tab.label.split.first } if @mobile
  end

  def external_route_params
    return nil unless external_request?

    { user_slug: params[:user_slug], entity_slug: params[:entity_slug] }
  end

  def internal_route_params
    return nil unless internal_request?

    { entity_slug: params[:entity_slug] }
  end

  def external_request?
    params[:user_slug].present? && params[:entity_slug].present?
  end

  def internal_request?
    request.path.start_with?("/internal/") && params[:entity_slug].present?
  end

  def scoped_entity_request?
    external_request? || internal_request?
  end

  def external_entity_slug
    params[:entity_slug].presence || "lala"
  end

  def external_slug_for(value)
    value.to_s.parameterize
  end

  def external_cash_transactions_index_path(**query_params)
    return internal_cash_transactions_path(**internal_route_params, **query_params) if internal_request?
    return external_cash_transactions_path(**external_route_params, **query_params) if external_request?

    lalas_cash_transactions_path(query_params)
  end

  def external_card_transactions_index_path(**query_params)
    return internal_card_transactions_path(**internal_route_params, **query_params) if internal_request?
    return external_card_transactions_path(**external_route_params, **query_params) if external_request?

    lalas_card_transactions_path(query_params)
  end
end
