# frozen_string_literal: true

class HealthCheck::NamingConventions::Preview
  attr_reader :apply_token, :digest, :results, :scope

  def initialize(scope:, results: nil)
    @scope = scope
    @results = results || analysis.call(dry_run: true)
    @digest = self.class.digest_for(@results).freeze
    @apply_token = HealthCheck::NamingConventions::PreviewToken.generate(token_payload).freeze
    freeze
  end

  def self.digest_for(results)
    Digest::SHA256.hexdigest(HealthCheck::Repairs::Payload.canonical_json(results))
  end

  private

  def analysis
    HealthCheck::NamingConventions::Analysis.new(user: scope.user, context: scope.context)
  end

  def token_payload
    {
      "actor_id" => scope.user.id,
      "context_id" => scope.context.id,
      "digest" => digest
    }
  end
end
