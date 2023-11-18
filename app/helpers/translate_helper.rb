# frozen_string_literal: true

# TranslateHelper for i18n and model / attributes
module TranslateHelper
  def model_on_count(instances)
    model = instances.first.class
    count = instances.count
    model.model_name.human.pluralize(count)
  end

  def pluralise_model(model, count)
    model.model_name.human.pluralize(count)
  end

  def attribute_model(model, attribute)
    model = model.class if model.class.is_a?(Class)
    model = model.model_name.singular
    I18n.t("activerecord.attributes.#{model}.#{attribute}")
  end

  def panel_title
    "#{I18n.t("gerund.#{action_name}")} #{controller_name.singularize.capitalize}"
  end

  def submit
    I18n.t("actions.#{action_name}")
  end
end
