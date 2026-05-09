# frozen_string_literal: true

# Helper for Translations with i18n for model / attributes
module TranslateHelper
  # Takes a collection of model instances, extracts the model class, counts the instances, and returns a pluralised human-readable model name.
  #
  # @example Get pluralised model name based on instance count:
  #   model_on_count(@users) # @users = User.all
  #   # => "Users" or "User" (depending on the count)
  #
  # @param instances [ActiveRecord::Relation]. Collection of model instances.
  #
  # @note One needs to fill in the i18n keys one and other for the model in question.
  #
  # @return [String] Pluralised human-readable model name based on the count of instances.
  #
  def model_on_count(instances)
    model = instances.first.class
    count = instances.count

    I18n.t("activerecord.models.#{model.model_name.singular}", count:)
  end

  # Takes a model class and a count, and returns a pluralised human-readable model name based on the count.
  #
  # @example Get pluralised model name based on count:
  #   pluralise_model(User, 5)
  #   # => "Users"
  #
  # @param model [Class] Model class.
  # @param count [Integer] Count of instances.
  #
  # @note One needs to fill in the i18n keys one and other for the model in question.
  #
  # @return [String] Pluralised human-readable model name based on the count.
  #
  def pluralise_model(model, count)
    I18n.t("activerecord.models.#{model.model_name.singular}", count:)
  end

  # Takes a notification key and a model class and returns the translated notification message.
  #
  # @example Get notification message:
  #   notification_model(:created, UserCard)
  #   # => "User Card was successfully created."
  #
  # @return [String] Translated notification message.
  #
  def notification_model(notification, model)
    I18n.t("notification.#{notification}", model: model.model_name.human)
  end

  def notification_model_or_history_lock(record, notification, model)
    history_lock_payload_for(record) || notification_model(notification, model)
  end

  def failure_notifications_for(record, notification, model)
    [
      notification_model(notification, model),
      *failure_detail_notifications_for(record)
    ].compact
  end

  # Takes a model instance or class and an attribute name, and returns a human-readable attribute name based on the model and attribute.
  #
  # @example Get human-readable attribute name:
  #   model_attribute(User, :first_name)
  #   # => "First Name"
  #
  # @param model [ActiveRecord::Base] Model instance or class.
  # @param attribute [Symbol] Attribute name.
  #
  # @note One needs to fill in the i18n attribute keys of the model in question.
  #
  # @return [String] Human-readable attribute name based on the model and attribute.
  #
  def model_attribute(model, attribute, fallback = nil)
    model = model.class if model.is_a?(ActiveRecord::Base)
    model = model.model_name.singular

    return I18n.t("activerecord.attributes.#{model}.#{attribute}") if fallback.nil?
    return I18n.t("activerecord.attributes.#{model}.#{attribute}") if I18n.exists?("activerecord.attributes.#{model}.#{attribute}")

    fallback
  end

  # Dynamically generates a panel title based on the current controller action and the singularised capitalised name of the controller.
  #
  # @example Get panel title:
  #   panel_title
  #   # => "Creating User" or "Editing Post" (depending on the controller action)
  #
  # @return [String] Panel title for the current controller action.
  #
  def panel_title
    "#{I18n.t("gerund.#{action_name}")} #{controller_name.singularize.capitalize}"
  end

  # @return [String] Action shortcut for I18n.
  #
  def action_message(action)
    I18n.t("actions.#{action}")
  end

  # Dynamically generates an action model based on the current controller action and the singularised capitalised name of the model.
  #
  # @param action [String] Controller action.
  # @param model [String] Model name.
  #
  # @return [String] Action model for the current controller action and model.
  #
  def action_model(action, model, count = 1)
    "#{I18n.t("actions.#{action}")} #{I18n.t("activerecord.models.#{model.model_name.singular}", count:)}"
  end

  def action_attribute(action, model, attribute)
    "#{I18n.t("actions.#{action}")} #{model_attribute(model, attribute)}"
  end

  # Convert price from cent based (integer in the database) to float
  #
  # @return [String]
  def from_cent_based_to_float(price, currency = nil)
    price = price.to_s
    negative = price.starts_with?("-")

    price = price.delete("-").rjust(3, "0")
    price.insert(-3, ".") if price.length > 2
    price.insert(-7, ",") if price.length > 6

    price = "-#{price}" if negative

    [ currency, price ].compact.join(" ")
  end

  # @example
  #   pretty_installments(1, 2)
  #   # => "01/02"
  #
  # @return [String]
  def pretty_installments(installment_number, installments_count)
    [ Kernel.format("%02d", installment_number), Kernel.format("%02d", installments_count) ].join("/")
  end

  # Generate a link to change the locale
  #
  # @return [String]
  def locale_link(locale, options = {}, &)
    button_to(update_locale_path(locale:), method: :patch, **options, &)
  end

  private

  def history_lock_payload_for(record)
    each_record_with_errors(record).lazy.map { |candidate| specific_history_error_payload(candidate) }.find(&:present?)
  end

  def failure_detail_notifications_for(record)
    each_record_with_errors(record).flat_map do |candidate|
      payload = specific_history_error_payload(candidate)
      next [ payload ] if payload.present?

      candidate.errors.full_messages.reject do |message|
        generic_invalid_error?(candidate, message)
      end
    end.uniq
  end

  def generic_invalid_error?(record, message)
    record.errors.details[:base].any? { |detail| detail[:error] == :invalid } && message == record.errors.full_message(:base, :invalid)
  end

  def each_record_with_errors(record, seen = [])
    return [] if record.blank?
    return [] if seen.include?(record.object_id)

    seen << record.object_id

    [ record, *nested_records_with_errors(record).flat_map { |candidate| each_record_with_errors(candidate, seen) } ]
  end

  def specific_history_error_payload(record)
    history_error_keys = Array(record.errors.details[:base]).filter_map { |detail| detail[:error] }
    history_error_key = %i[
      exchange_return_price_correction_confirmation_required
      paid_amount_correction_confirmation_required
      same_cycle_history_correction_confirmation_required
      same_month_paid_state_correction_confirmation_required
      month_boundary_history_correction_confirmation_required
      destroy_locked_after_payment
      paid_history_locked
      allocation_locked_after_payment
      counterpart_paid_state_sync_missing
    ]
                        .find { |key| history_error_keys.include?(key) }
    return if history_error_key.blank?

    message = record.errors.full_messages_for(:base).find do |candidate|
      candidate == I18n.t("activerecord.errors.models.#{record.model_name.singular}.attributes.base.#{history_error_key}")
    end
    return if message.blank?

    payload = {
      message:,
      workaround_label: I18n.t("notification.workaround"),
      workaround: history_workaround_for(record, history_error_key)
    }

    action = history_lock_action_for(record, history_error_key)
    payload[:action] = action if action.present?

    payload
  end

  def nested_records_with_errors(record)
    nested_collection_names.filter_map do |association_name|
      next unless record.respond_to?(association_name)

      record.public_send(association_name).reject(&:marked_for_destruction?)
    end.flatten
  end

  def nested_collection_names
    %i[cash_transactions card_transactions cash_installments card_installments entity_transactions exchanges]
  end

  def history_workaround_for(record, history_error_key)
    scoped_key = "notification.history_workarounds.#{history_error_key}.#{record.model_name.singular}"
    return I18n.t(scoped_key) if I18n.exists?(scoped_key)

    default_key = "notification.history_workarounds.#{history_error_key}.default"
    return I18n.t(default_key) if I18n.exists?(default_key)

    I18n.t("notification.history_workarounds.#{history_error_key}")
  end

  def history_lock_action_for(record, history_error_key)
    return unless history_error_key == :destroy_locked_after_payment
    return unless record.respond_to?(:destroy_confirmation_candidate?, true) && record.send(:destroy_confirmation_candidate?)

    {
      label: I18n.t("actions.confirm_historical_change"),
      href: destroy_confirmation_href_for(record),
      method: :delete
    }
  end

  def destroy_confirmation_href_for(record)
    case record
    when CashTransaction
      cash_transaction_path(record, historical_correction_confirmation: true)
    when CardTransaction
      card_transaction_path(
        record,
        card_installment_id: params[:card_installment_id].presence,
        historical_correction_confirmation: true
      )
    end
  end
end
