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
  def model_attribute(model, attribute)
    model = model.class if model.is_a?(ActiveRecord::Base)
    model = model.model_name.singular
    I18n.t("activerecord.attributes.#{model}.#{attribute}")
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

  # Dynamically generates a submit button label based on the current controller action.
  #
  # @example Get submit button label:
  #   submit
  #   # => "Create" or "Update" (depending on the controller action)
  #
  # @return [String] Submit button label for the current controller action.
  #
  def submit
    I18n.t("actions.#{action_name}")
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
    path = request.path
    path_with_locale = "#{path}?locale=#{locale}"
    link_to(path_with_locale, class: options[:class], &)
  end
end
