# frozen_string_literal: true

module Projects
  module ContainerRepository
    class DeleteTagsService < BaseService
      LOG_DATA_BASE = { service_class: self.to_s }.freeze

      def execute(container_repository)
        @container_repository = container_repository
        return error('access denied') unless can?(current_user, :destroy_container_image, project)

        @tag_names = params[:tags]
        return error('not tags specified') if @tag_names.blank?

        delete_tags
      end

      private

      def delete_tags
        delete_service.execute
                      .tap(&method(:log_response))
      end

      def delete_service
        fast_delete_enabled = Feature.enabled?(:container_registry_fast_tag_delete, default_enabled: true)

        if fast_delete_enabled && @container_repository.client.supports_tag_delete?
          ::Projects::ContainerRepository::Gitlab::DeleteTagsService.new(@container_repository, @tag_names)
        else
          ::Projects::ContainerRepository::ThirdParty::DeleteTagsService.new(@container_repository, @tag_names)
        end
      end

      def log_response(response)
        log_data = LOG_DATA_BASE.merge(
          container_repository_id: @container_repository.id,
          message: 'deleted tags'
        )

        if response[:status] == :success
          log_data[:deleted_tags_count] = response[:deleted].size
          log_info(log_data)
        else
          log_data[:message] = response[:message]
          log_error(log_data)
        end
      end
    end
  end
end
