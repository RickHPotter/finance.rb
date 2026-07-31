# frozen_string_literal: true

class HealthCheck::Scope
  class Invalid < StandardError
    attr_reader :code

    def initialize(code)
      @code = code.to_s
      super(@code)
    end
  end

  attr_reader :connected_user, :context, :locale, :user

  def initialize(user:, context:, connected_user: nil, locale: I18n.locale)
    @user = user
    @context = context
    @connected_user = connected_user
    @locale = locale.to_s

    validate!
    freeze
  end

  def to_h
    {
      user_id: user.id,
      context_id: context.id,
      connected_user_id: connected_user&.id,
      locale:
    }.freeze
  end

  def all_connections?
    connected_user.nil?
  end

  def connected_users
    User.where(id: user.entities.that_are_users.map(&:entity_user_id).uniq)
        .order(:first_name, :last_name, :id)
        .to_a
  end

  def scenario_key
    context.scenario_key
  end

  def for_entry(entry)
    raise Invalid, :check_unregistered unless entry.is_a?(HealthCheck::Registry::Entry)
    return self if entry.connection_scoped? || connected_user.nil?

    self.class.new(user:, context:, locale:)
  end

  private

  def validate!
    raise Invalid, :admin_required unless persisted_user?(user) && user.admin?
    raise Invalid, :context_not_found unless context.is_a?(Context) && context.persisted?
    raise Invalid, :context_mismatch unless context.user_id == user.id
    raise Invalid, :context_archived if context.archived?
    raise Invalid, :unsupported_locale unless locale.in?(I18n.available_locales.map(&:to_s))

    validate_connected_user!
  end

  def validate_connected_user!
    return if connected_user.nil?

    raise Invalid, :connected_user_not_found unless persisted_user?(connected_user)
    raise Invalid, :connected_user_invalid if connected_user.id == user.id
    raise Invalid, :connected_user_unrelated unless user.entities.that_are_users.where_entity_user_id(connected_user.id).exists?
  end

  def persisted_user?(candidate)
    candidate.is_a?(User) && candidate.persisted?
  end
end
