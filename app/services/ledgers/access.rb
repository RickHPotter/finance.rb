# frozen_string_literal: true

module Ledgers::Access
  Result = Data.define(:user, :entity, :context, :share)
end
