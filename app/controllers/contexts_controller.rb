# frozen_string_literal: true

class ContextsController < ApplicationController
  include TabsConcern

  before_action :set_context_tabs

  def index
    contexts = current_user.contexts.order(:created_at)
    render Views::Contexts::Index.new(contexts:, current_context:)
  end

  def show
    context = current_user.contexts.find(params[:id])
    render_context_overlay Views::Contexts::Show.new(context:, current_context:)
  end

  def new
    context = current_user.contexts.new(source_context: source_context)
    render_context_overlay Views::Contexts::New.new(context:, source_context:)
  end

  def create
    context = Logic::ContextCloneService.new(
      source_context:,
      name: context_params[:name],
      description: context_params[:description]
    ).call

    redirect_to context_path(context), status: :see_other
  end

  def destroy
    context = current_user.contexts.find(params[:id])
    invalid_destroy_response = invalid_destroy_response_for(context)
    return invalid_destroy_response if invalid_destroy_response

    Logic::ContextPurgeService.new(context:, user: current_user).call
    session[:current_context_id] = current_user.main_context.id if current_context == context

    redirect_to contexts_path, notice: t("contexts.destroy.success"), status: :see_other
  rescue Logic::ContextPurgeService::CrossContextDependencyError
    redirect_to context_path(context), alert: t("contexts.destroy.cross_context_dependencies"), status: :see_other
  rescue Logic::ContextPurgeService::InvariantViolation
    redirect_to context_path(context), alert: t("contexts.destroy.main_context_guard_failed"), status: :see_other
  end

  def dismiss
    render inline: helpers.turbo_frame_tag(:context_overlay), layout: false
  end

  def archive
    context = current_user.contexts.find(params[:id])

    if context.main?
      redirect_to contexts_path, alert: t("contexts.archive.main_forbidden"), status: :see_other
      return
    end

    context.update!(archived_at: Time.current)
    session[:current_context_id] = current_user.main_context.id if current_context == context

    redirect_to contexts_path, notice: t("contexts.archive.success"), status: :see_other
  end

  def unarchive
    context = current_user.contexts.find(params[:id])

    if context.main?
      redirect_to contexts_path, alert: t("contexts.archive.main_forbidden"), status: :see_other
      return
    end

    context.update!(archived_at: nil)

    redirect_to contexts_path, notice: t("contexts.unarchive.success"), status: :see_other
  end

  def switch
    context = current_user.contexts.find(params[:id])
    session[:current_context_id] = context.id
    @context_switch_navigation = Navigation::ContextSwitch.new(
      raw: params[:return_to].presence || request.referer,
      fallback: root_path,
      current_user:,
      current_context: context
    )

    redirect_to @context_switch_navigation.destination, **switch_flash_options, status: :see_other
  end

  private

  def context_params
    params.require(:context).permit(:name, :description, :source_context_id)
  end

  def source_context
    source_context_id = params.dig(:context, :source_context_id) || params[:source_context_id]
    @source_context ||= current_user.contexts.find(source_context_id)
  end

  def set_context_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :context)
  end

  def render_context_overlay(view)
    return render(view, layout: false) if turbo_frame_request?

    render view
  end

  def switch_flash_options
    return { notice: t("contexts.switch.redirected_to_index") } if @context_switch_navigation.redirected_conversation?

    {}
  end

  def invalid_destroy_response_for(context)
    return redirect_to(contexts_path, alert: t("contexts.destroy.main_forbidden"), status: :see_other) if context.main?
    return redirect_to(context_path(context), alert: t("contexts.destroy.archive_required"), status: :see_other) unless context.archived?
    return redirect_to(context_path(context), alert: t("contexts.destroy.has_children"), status: :see_other) if context.derived_contexts.exists?

    nil
  end
end
