# frozen_string_literal: true

class IssuePlacementWorker
  include ApplicationWorker

  idempotent!
  feature_category :issue_tracking
  urgency :high
  worker_resource_boundary :cpu
  weight 2

  # Move at most the most recent 100 issues
  QUERY_LIMIT = 100

  # rubocop: disable CodeReuse/ActiveRecord
  def perform(issue_id, project_id = nil)
    issue = find_issue(issue_id, project_id)
    return unless issue

    # Move the oldest 100 unpositioned items to the end.
    # This is to deal with out-of-order execution of the worker,
    # while preserving creation order.
    to_place = Issue
      .relative_positioning_query_base(issue)
      .where(relative_position: nil)
      .order({ created_at: :asc }, { id: :asc })
      .limit(QUERY_LIMIT + 1)
      .to_a

    leftover = to_place.pop if to_place.count > QUERY_LIMIT

    Issue.move_nulls_to_end(to_place)
    Issues::BaseService.new(nil).rebalance_if_needed(to_place.max_by(&:relative_position))
    IssuePlacementWorker.perform_async(nil, leftover.project_id) if leftover.present?
  rescue RelativePositioning::NoSpaceLeft => e
    Gitlab::ErrorTracking.log_exception(e, issue_id: issue_id, project_id: project_id)
    IssueRebalancingWorker.perform_async(nil, project_id.presence || issue.project_id)
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def find_issue(issue_id, project_id)
    return Issue.id_in(issue_id).first if issue_id

    project = Project.id_in(project_id).first
    return unless project

    project.issues.first
  end
end
