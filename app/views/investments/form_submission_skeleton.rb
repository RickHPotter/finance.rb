# frozen_string_literal: true

class Views::Investments::FormSubmissionSkeleton < Views::Base
  def view_template
    div(class: "space-y-5", id: "investment_form_submission_skeleton") do
      # hint badge
      div(class: "flex justify-center") do
        Skeleton(class: "h-7 w-28 rounded-sm")
      end

      div(class: "space-y-5") do
        # description
        Skeleton(class: "hidden lg:block h-16 w-full rounded-md")
        Skeleton(class: "block lg:hidden h-10 w-full rounded-md")
      end

      # second row
      div(class: "grid grid-cols-1 gap-3 lg:grid-cols-4") do
        # account
        div(class: "space-y-2") do
          Skeleton(class: "h-10 w-full rounded-md")
        end

        # investment type
        div(class: "space-y-2") do
          Skeleton(class: "h-10 w-full rounded-md")
        end

        # date
        div(class: "space-y-2") do
          render_date_skeleton
        end

        # price
        div(class: "space-y-2") do
          Skeleton(class: "h-10 w-full rounded-md")
        end
      end

      div(class: "space-y-3") do
        # create more checkbox
        Skeleton(class: "mx-auto h-5 w-32 rounded-sm")

        # submit buttons
        div(class: "grid grid-cols-1 gap-2 sm:grid-flow-col sm:auto-cols-fr") do
          3.times do
            Skeleton(class: "h-10 w-full rounded-md")
          end
        end
      end
    end
  end

  private

  def render_date_skeleton
    div(class: "lg:hidden") do
      render_calendar_skeleton
    end

    div(class: "hidden lg:block") do
      Skeleton(class: "h-10 w-full rounded-md")
      # Skeleton(class: "mt-2 h-4 w-20 rounded-sm")
      Skeleton(class: "mt-1 mx-auto h-3 w-20 rounded-sm")
    end
  end

  def render_calendar_skeleton
    div(class: "rounded-md border border-slate-200 bg-white p-3 shadow-sm") do
      div(class: "mb-3 flex items-center justify-between") do
        Skeleton(class: "h-4 w-7 rounded-md")
        Skeleton(class: "h-4 w-20 rounded-sm")
        Skeleton(class: "h-4 w-7 rounded-md")
      end

      div(class: "grid grid-cols-7 gap-1") do
        35.times do
          Skeleton(class: "aspect-square w-full rounded-md")
        end
      end
    end
  end
end
