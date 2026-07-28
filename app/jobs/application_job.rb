# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  attr_accessor :audit_parent_operation_id, :audit_actor_id, :audit_context_id

  before_enqueue do |job|
    next unless Audit::Current.active?

    job.audit_parent_operation_id ||= Audit::Current.operation_id
    job.audit_actor_id ||= Audit::Current.actor_id
    job.audit_context_id ||= Audit::Current.context_id
  end

  around_perform do |job, block|
    Audit::Operation.run(
      actor: job.audit_actor_id || Audit::Current.actor_id,
      context: job.audit_context_id || Audit::Current.context_id,
      source: :background_job,
      parent_operation_id: job.audit_parent_operation_id || Audit::Current.operation_id,
      metadata: { job_class: job.class.name, job_id: job.job_id },
      join_existing: false,
      &block
    )
  end

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  def serialize
    super.merge(
      "audit_parent_operation_id" => audit_parent_operation_id,
      "audit_actor_id" => audit_actor_id,
      "audit_context_id" => audit_context_id
    )
  end

  def deserialize(job_data)
    super
    self.audit_parent_operation_id = job_data["audit_parent_operation_id"]
    self.audit_actor_id = job_data["audit_actor_id"]
    self.audit_context_id = job_data["audit_context_id"]
  end
end
