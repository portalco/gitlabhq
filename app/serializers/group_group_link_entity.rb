# frozen_string_literal: true

class GroupGroupLinkEntity < Grape::Entity
  expose :id
  expose :created_at
  expose :expires_at do |group_link|
    group_link.expires_at&.to_time
  end

  expose :access_level do
    expose :human_access, as: :string_value
    expose :group_access, as: :integer_value
  end

  expose :shared_with_group do
    expose :avatar_url do |group_link|
      group_link.shared_with_group.avatar_url(only_path: false)
    end

    expose :web_url do |group_link|
      group_link.shared_with_group.web_url
    end

    expose :shared_with_group, merge: true, using: GroupBasicEntity
  end
end
