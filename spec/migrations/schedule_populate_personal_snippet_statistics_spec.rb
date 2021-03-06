# frozen_string_literal: true

require 'spec_helper'

require Rails.root.join('db', 'post_migrate', '20200714075739_schedule_populate_personal_snippet_statistics.rb')

RSpec.describe SchedulePopulatePersonalSnippetStatistics do
  let(:users) { table(:users) }
  let(:snippets) { table(:snippets) }
  let(:projects) { table(:projects) }
  let(:user1) { users.create!(id: 1, email: 'user1@example.com', projects_limit: 10, username: 'test1', name: 'Test1', state: 'active') }
  let(:user2) { users.create!(id: 2, email: 'user2@example.com', projects_limit: 10, username: 'test2', name: 'Test2', state: 'active') }
  let(:user3) { users.create!(id: 3, email: 'user3@example.com', projects_limit: 10, username: 'test3', name: 'Test3', state: 'active') }

  def create_snippet(id, user_id, type = 'PersonalSnippet')
    params = {
      id: id,
      type: type,
      author_id: user_id,
      file_name: 'foo',
      content: 'bar'
    }

    snippets.create!(params)
  end

  it 'correctly schedules background migrations' do
    # Creating the snippets in different order
    create_snippet(1, user1.id)
    create_snippet(2, user2.id)
    create_snippet(3, user1.id)
    create_snippet(4, user3.id)
    create_snippet(5, user3.id)
    create_snippet(6, user1.id)
    # Creating a project snippet to ensure we don't pick it
    create_snippet(7, user1.id, 'ProjectSnippet')

    stub_const("#{described_class}::BATCH_SIZE", 4)

    Sidekiq::Testing.fake! do
      freeze_time do
        migrate!

        aggregate_failures do
          expect(described_class::MIGRATION)
            .to be_scheduled_migration([1, 3, 6, 2])

          expect(described_class::MIGRATION)
            .to be_scheduled_delayed_migration(2.minutes, [4, 5])

          expect(BackgroundMigrationWorker.jobs.size).to eq(2)
        end
      end
    end
  end
end
