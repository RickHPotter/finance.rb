# frozen_string_literal: true

class Audit::Rollback::NetState
  attr_reader :versions

  def initialize(versions:)
    @versions = versions
  end

  def call
    versions.order(:id)
            .group_by { |version| [ version.item_subtype.presence || version.item_type, version.item_id ] }
            .sort_by { |(record_type, item_id), _| [ record_type, item_id ] }
            .map { |_, record_versions| Audit::Rollback::Transition.new(versions: record_versions) }
  end
end
