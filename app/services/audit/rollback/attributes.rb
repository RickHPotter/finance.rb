# frozen_string_literal: true

class Audit::Rollback::Attributes
  class << self
    def for(adapter)
      attributes = adapter.before_state.to_h
      attributes = attributes.slice(*adapter.transition.net_changed_attributes) if adapter.action == "update"
      attributes.except("id", *ignored_attributes(adapter))
    end

    def comparable_for(row)
      row.before_state.to_h.except(*ignored_attributes(row.adapter))
    end

    private

    def ignored_attributes(adapter)
      adapter.class.const_get(:DERIVED_ATTRIBUTES)
    end
  end
end
