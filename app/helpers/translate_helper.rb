# frozen_string_literal: true

# Helper for Translations with i18n for model / attributes
module TranslateHelper
  # This method takes a collection of model instances, extracts the model class,
  # counts the instances, and returns a pluralised human-readable model name.
  #
  # @example Get pluralised model name based on instance count
  #   model_on_count(@users) # @users = User.all
  #   # => "Users" or "User" (depending on the count)
  #
  # @param instances [ActiveRecord::Relation] Collection of model instances.
  #
  # @note One needs to fill in the i18n keys one and other for the model in question.
  #
  # @return [String] Pluralised human-readable model name based on the count of instances.
  #
  def model_on_count(instances)
    model = instances.first.class
    count = instances.count
    model.model_name.human.pluralize(count)
  end

  # This method takes a model class and a count, and returns a pluralised
  # human-readable model name based on the count.
  #
  # @example Get pluralised model name based on count
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
    model.model_name.human.pluralize(count)
  end

  # This method takes a model instance or class and an attribute name, and returns
  # a human-readable attribute name based on the model and attribute.
  #
  # @example Get human-readable attribute name
  #   attribute_model(User, :first_name)
  #   # => "First Name"
  #
  # @param model [ActiveRecord::Base] Model instance or class.
  # @param attribute [Symbol] Attribute name.
  #
  # @note One needs to fill in the i18n attribute keys of the model in question.
  #
  # @return [String] Human-readable attribute name based on the model and attribute.
  #
  def attribute_model(model, attribute)
    model = model.class if model.class.is_a?(Class)
    model = model.model_name.singular
    I18n.t("activerecord.attributes.#{model}.#{attribute}")
  end

  # This method dynamically generates a panel title based on the current controller
  # action and the singularised capitalised name of the controller.
  #
  # @example Get panel title
  #   panel_title
  #   # => "Creating User" or "Editing Post" (depending on the controller action)
  #
  # @return [String] Panel title for the current controller action.
  #
  def panel_title
    "#{I18n.t("gerund.#{action_name}")} #{controller_name.singularize.capitalize}"
  end

  # This method dynamically generates a submit button label based on the current
  # controller action.
  #
  # @example Get submit button label
  #   submit
  #   # => "Create" or "Update" (depending on the controller action)
  #
  # @return [String] Submit button label for the current controller action.
  #
  def submit
    I18n.t("actions.#{action_name}")
  end
end
