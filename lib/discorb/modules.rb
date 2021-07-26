# frozen_string_literal: true

require_relative 'components'
require_relative 'utils'
module Discorb
  module Messageable
    def post(content = nil, tts: false, embed: nil, embeds: nil, allowed_mentions: nil,
             message_reference: nil, components: nil, file: nil, files: nil)
      Async do |_task|
        payload = {}
        payload[:content] = content if content
        payload[:tts] = tts
        tmp_embed = if embed
                      [embed]
                    elsif embeds
                      embeds
                    end
        payload[:embeds] = tmp_embed.map(&:to_hash) if tmp_embed
        payload[:allowed_mentions] =
          allowed_mentions ? allowed_mentions.to_hash(@client.allowed_mentions) : @client.allowed_mentions.to_hash
        payload[:message_reference] = message_reference.to_reference if message_reference
        if components
          tmp_components = []
          tmp_row = []
          components.each do |c|
            case c
            when Array
              tmp_components << tmp_row
              tmp_row = []
              tmp_components << c
            when SelectMenu
              tmp_components << tmp_row
              tmp_row = []
              tmp_components << [c]
            else
              tmp_row << c
            end
          end
          tmp_components << tmp_row
          payload[:components] = tmp_components.filter { |c| c.length.positive? }.map { |c| { type: 1, components: c.map(&:to_hash) } }
        end
        files = [file] if file
        if files
          boundary = "DiscorbChannels#{@channel_id}MessagesPost#{Time.now.to_f}"
          headers = {
            'content-type' => "multipart/form-data; boundary=#{boundary}"
          }
          str_payloads = [<<~HTTP
            Content-Disposition: form-data; name="payload_json"
            Content-Type: application/json

            #{payload.to_json}
          HTTP
          ]
          files.each do |single_file|
            str_payloads << <<~HTTP
              Content-Disposition: form-data; name="file"; filename="#{single_file.filename}"
              Content-Type: #{single_file.content_type}

              #{single_file.io.read}
            HTTP
          end
          payload = "--#{boundary}\n#{str_payloads.join("\n--#{boundary}\n")}\n--#{boundary}--"
        else
          headers = {}
        end
        _resp, data = @client.internet.post("#{base_url.wait}/messages", payload, headers: headers).wait
        Message.new(@client, data.merge({ guild_id: @guild_id.to_s }))
      end
    end

    def fetch_message(id)
      Async do
        _resp, data = @client.internet.get("#{base_url.wait}/messages/#{id}").wait
        Message.new(@client, data.merge({ guild_id: @guild_id.to_s }))
      end
    end

    def close
      Async do
        @client.internet.delete(base_url.wait.to_s).wait
        @deleted = true
        self
      end
    end

    def fetch_messages(limit = 50, before: nil, after: nil, around: nil)
      Async do
        params = {
          limit: limit,
          before: Discorb::Utils.try(after, :id),
          after: Discorb::Utils.try(around, :id),
          around: Discorb::Utils.try(before, :id)
        }.filter { |_k, v| !v.nil? }.to_h
        _resp, messages = @client.internet.get("#{base_url.wait}/messages?#{URI.encode_www_form(params)}").wait
        messages.map { |m| Message.new(@client, m.merge({guild_id: @guild_id.to_s})) }
      end
    end
  end
end
