# frozen_string_literal: true

class Ledgers::Presenters::Header
  attr_reader :owner_name, :entity_name, :entity_avatar_name, :context_name, :last_updated_at, :external

  def initialize(access:, result:)
    @owner_name = access.user.display_name.presence || access.user.full_name
    @entity_name = access.entity.entity_name
    @entity_avatar_name = access.entity.avatar_name
    @context_name = access.context.name
    @last_updated_at = result.last_updated_at
    @external = access.share.present?
  end

  def external?
    external
  end
end
