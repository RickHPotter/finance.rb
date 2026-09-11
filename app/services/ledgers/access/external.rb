# frozen_string_literal: true

class Ledgers::Access::External
  def self.call(token:, at: Time.current)
    share = Ledgers::Shares::Resolve.call(token:, at:)
    return if share.blank?

    Ledgers::Access::Result.new(user: share.context.user, entity: share.entity, context: share.context, share:)
  end
end
