require 'net/http'

module Webhook
  class WebhookListener < Redmine::Hook::Listener

    def skip_webhooks(context)
      request = context[:request]
      if request.headers['X-Skip-Webhooks']
        return true
      end
      return false
    end

    def controller_issues_edit_after_save(context = {})
      return if skip_webhooks(context)
      journal = context[:journal]
      controller = context[:controller]
      issue = context[:issue]
      project = issue.project
      return unless project.module_enabled?('webhook')
      post(journal_to_json(issue, journal, controller))
    end

    private
    def journal_to_json(issue, journal, controller)
      {
        :payload => {
          :action => 'updated',
          :issue => Webhook::IssueWrapper.new(issue).to_hash,
          :journal => Webhook::JournalWrapper.new(journal).to_hash,
          :url => controller.issue_url(issue)
        }
      }.to_json
    end

    def post(request_body)
      Thread.start do
          begin
              url = Setting.plugin_webhook['url']
              if url.nil? || url == ''
                  raise 'Url is not defined for webhook plugin'
              end
              url = URI(url)
	      headers = {
                  'Content-Type' => 'application/json',
                  'X-Redmine-Event' => 'Edit Issue',
              }
              req = Net::HTTP::Post.new(url, headers)
	      req.body = request_body
	      Net::HTTP.start(url.hostname, url.port) do |http|
                  http.request(req)
              end
          rescue => e
            Rails.logger.error e
          end
	end
    end
  end
end
