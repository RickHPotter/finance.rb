# frozen_string_literal: true

class Views::Subscriptions::FormSubmissionSkeleton < Views::Base
  def view_template
    div(class: "space-y-5", id: "subscription_form_submission_skeleton") do
      div(class: "flex justify-center") do
        Skeleton(class: "h-7 w-28 rounded-sm")
      end

      div(class: "space-y-5") do
        Skeleton(class: "h-16 w-full rounded-md")
        Skeleton(class: "h-24 w-full rounded-lg")
      end

      div(class: "mb-6 grid grid-cols-1 gap-3 lg:grid-cols-3 lg:gap-2") do
        Skeleton(class: "h-10 w-full rounded-md")
        Skeleton(class: "h-10 w-full rounded-md")
        Skeleton(class: "h-10 w-full rounded-md")
      end

      div(class: "flex flex-1 flex-col space-y-4") do
        div(class: "flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between") do
          div(class: "flex flex-wrap items-center gap-3") do
            Skeleton(class: "h-7 w-36 rounded-sm")
            Skeleton(class: "h-7 w-12 rounded-full")
            Skeleton(class: "h-7 w-28 rounded-full")
          end

          div(class: "flex gap-2") do
            Skeleton(class: "h-10 w-20 rounded-sm")
            Skeleton(class: "h-10 w-24 rounded-sm")
          end
        end

        div(class: "min-h-56 max-h-56 space-y-3 overflow-hidden border border-slate-200 bg-white/80 p-3 shadow-inner") do
          3.times do |index|
            render_transaction_row_skeleton(index:, kind: index.even? ? :cash : :card)
          end
        end
      end

      div(class: "grid w-full grid-cols-1 items-center justify-items-center gap-2 pt-4 sm:grid-flow-col sm:auto-cols-fr") do
        Skeleton(class: "h-10 w-64 rounded-md")
        Skeleton(class: "h-10 w-64 rounded-md opacity-80")
      end
    end
  end

  private

  def render_transaction_row_skeleton(index:, kind:)
    div(class: "#{transaction_row_class(kind)} #{'opacity-70' if index == 2}") do
      div(class: "flex items-start justify-between gap-3") do
        div(class: "min-w-0 flex-1 space-y-2") do
          Skeleton(class: "h-4 w-24 rounded-sm #{accent_skeleton_class(kind)}")
          Skeleton(class: "h-5 w-40 max-w-full rounded-sm")
        end

        div(class: "min-w-0 flex-1 space-y-2") do
          Skeleton(class: "h-5 w-36 max-w-full rounded-sm")
          Skeleton(class: "h-5 w-24 rounded-sm")
        end

        div(class: "flex items-center gap-1") do
          Skeleton(class: "size-6 rounded-sm")
          Skeleton(class: "size-6 rounded-sm")
        end
      end
    end
  end

  def transaction_row_class(kind)
    base_class = "rounded-lg border p-2"
    return "#{base_class} border-emerald-200 bg-emerald-50" if kind == :cash

    "#{base_class} border-orange-200 bg-orange-50"
  end

  def accent_skeleton_class(kind)
    kind == :cash ? "bg-emerald-200" : "bg-orange-200"
  end
end
