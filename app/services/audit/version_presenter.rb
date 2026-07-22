# frozen_string_literal: true

class Audit::VersionPresenter
  Change = Data.define(:attribute, :label, :before, :after)

  MONEY_ATTRIBUTES = %w[
    balance card_transactions_total cash_transactions_total credit_limit min_spend price
    price_to_be_returned remaining_value return_price starting_price starting_value value
  ].freeze

  attr_reader :version

  def initialize(version)
    @version = version
  end

  def model_name
    model_class&.model_name&.human || version.item_subtype.presence || version.item_type
  end

  def changes
    version.object_changes.to_h.sort.map do |attribute, values|
      before_value, after_value = Array(values)
      Change.new(
        attribute:,
        label: attribute_label(attribute),
        before: format_value(attribute, before_value),
        after: format_value(attribute, after_value)
      )
    end
  end

  def attribute_label(attribute)
    model_class&.human_attribute_name(attribute, default: attribute.humanize) || attribute.humanize
  end

  def format_value(attribute, value)
    return I18n.t("audit.values.empty") if value.nil?
    return I18n.t("audit.values.#{value}") if value.in?([ true, false ])
    return format_money(value) if attribute.in?(MONEY_ATTRIBUTES) && value.is_a?(Numeric)

    case model_class&.type_for_attribute(attribute)&.type
    when :datetime then I18n.l(Time.zone.parse(value.to_s), format: :short)
    when :date then I18n.l(Date.parse(value.to_s), format: :default)
    else value.to_s
    end
  rescue ArgumentError
    value.to_s
  end

  def raw_payload
    {
      item_type: version.item_type,
      item_subtype: version.item_subtype,
      item_id: version.item_id,
      event: version.event,
      object: version.object,
      object_changes: version.object_changes,
      metadata: version.metadata
    }
  end

  private

  def model_class
    @model_class ||= (version.item_subtype.presence || version.item_type).safe_constantize
  end

  def format_money(value)
    cents = value.to_i
    sign = cents.negative? ? "-" : ""
    digits = cents.abs.to_s.rjust(3, "0")
    whole = digits[0...-2].reverse.scan(/.{1,3}/).join(I18n.t("number.currency.format.delimiter")).reverse
    decimal = digits[-2, 2]
    "#{sign}#{I18n.t('number.currency.format.unit')} #{whole}#{I18n.t('number.currency.format.separator')}#{decimal}"
  end
end
