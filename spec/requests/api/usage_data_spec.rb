# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::UsageData do
  let_it_be(:user) { create(:user) }

  describe 'POST /usage_data/increment_unique_users' do
    let(:endpoint) { '/usage_data/increment_unique_users' }
    let(:known_event) { 'g_compliance_dashboard' }
    let(:unknown_event) { 'unknown' }

    context 'without CSRF token' do
      it 'returns forbidden' do
        stub_feature_flags(usage_data_api: true)
        allow(Gitlab::RequestForgeryProtection).to receive(:verified?).and_return(false)

        post api(endpoint, user), params: { event: known_event }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'usage_data_api feature not enabled' do
      it 'returns not_found' do
        stub_feature_flags(usage_data_api: false)

        post api(endpoint, user), params: { event: known_event }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'without authentication' do
      it 'returns 401 response' do
        post api(endpoint), params: { event: known_event }

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'with authentication' do
      before do
        stub_feature_flags(usage_data_api: true)
        stub_feature_flags("usage_data_#{known_event}" => true)
        stub_application_setting(usage_ping_enabled: true)
        allow(Gitlab::RequestForgeryProtection).to receive(:verified?).and_return(true)
      end

      context 'when event is missing from params' do
        it 'returns bad request' do
          post api(endpoint, user), params: {}

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'with correct params' do
        it 'returns status ok' do
          expect(Gitlab::Redis::HLL).to receive(:add)

          post api(endpoint, user), params: { event: known_event }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'with unknown event' do
        it 'returns status ok' do
          expect(Gitlab::Redis::HLL).not_to receive(:add)

          post api(endpoint, user), params: { event: unknown_event }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end
  end
end
