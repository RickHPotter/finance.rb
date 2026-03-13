# frozen_string_literal: true

module Linter
  class Base
    attr_reader :dry_run, :locale

    def initialize(dry_run: false, locale: nil)
      @dry_run = dry_run
      @locale = locale
    end

    private

    def with_record_locale(record, &)
      I18n.with_locale(locale || record&.user&.locale || I18n.locale, &)
    end

    def no_change(record)
      {
        record: record_payload(record),
        changes: {}
      }
    end

    def apply_update(record, attributes)
      changed_attributes = attributes.compact_blank.to_h do |attribute, value|
        if record.public_send(attribute) == value
          [ attribute, nil ]
        else
          [ attribute, value ]
        end
      end.compact

      return no_change(record) if changed_attributes.empty?

      previous_attributes = changed_attributes.to_h do |attribute, _|
        [ attribute, record.public_send(attribute) ]
      end

      record.update_columns(changed_attributes) unless dry_run

      {
        record: record_payload(record),
        changes: changed_attributes,
        previous_attributes:
      }
    end

    def record_payload(record)
      record.slice(:id, :user_id).merge(type: record.class.name)
    end
  end
end
