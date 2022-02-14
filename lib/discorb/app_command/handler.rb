# frozen_string_literal: true

module Discorb
  #
  # Handles application commands.
  #
  module ApplicationCommand
    #
    # Module to handle application commands.
    #
    module Handler
      #
      # Add new top-level command.
      #
      # @param [String] command_name Command name.
      # @param [String] description Command description.
      # @param [Hash{String => Hash{:description => String, :optional => Boolean, :type => Object}}] options Command options.
      #   The key is the option name, the value is a hash with the following keys:
      #
      #   | Key | Type | Description |
      #   | --- | --- | --- |
      #   | `:description` | `String` | Description of the option. |
      #   | `:required` | Whether the argument is required. `optional` will be used if not specified. |
      #   | `:optional` | Whether the argument is optional. `required` will be used if not specified. |
      #   | `:type` | `Object` | Type of the option. |
      #   | `:choice` | `Hash{String => String, Integer, Float}` | Type of the option. |
      #   | `:default` | `Object` | Default value of the option. |
      #   | `:channel_types` | `Array<Class<Discorb::Channel>>` | Type of the channel option. |
      #   | `:autocomplete` | `Proc` | Autocomplete function. |
      #   | `:range` | `Range` | Range of the option. Only valid for numeric options. (`:int`, `:float`) |
      #
      # @param [Array<#to_s>, false, nil] guild_ids Guild IDs to set the command to. `false` to global command, `nil` to use default.
      # @param [Proc] block Command block.
      #
      # @return [Discorb::ApplicationCommand::Command::SlashCommand] Command object.
      #
      # @see file:docs/application_command.md#register-slash-command Application Comamnds: Register Slash Command
      # @see file:docs/cli/setup.md CLI: setup
      #
      def slash(command_name, description, options = {}, guild_ids: nil, &block)
        command = Discorb::ApplicationCommand::Command::SlashCommand.new(command_name, description, options, guild_ids, block, 1, "")
        @commands << command
        @bottom_commands << command
        command
      end

      #
      # Add new command with group.
      #
      # @param [String] command_name Command name.
      # @param [String] description Command description.
      # @param [Array<#to_s>, false, nil] guild_ids Guild IDs to set the command to. `false` to global command, `nil` to use default.
      #
      # @yield Block to yield with the command.
      # @yieldparam [Discorb::ApplicationCommand::Command::GroupCommand] group Group command.
      #
      # @return [Discorb::ApplicationCommand::Command::GroupCommand] Command object.
      #
      # @see file:docs/application_command.md Application Commands
      # @see file:docs/cli/setup.md CLI: setup
      #
      def slash_group(command_name, description, guild_ids: nil, &block)
        command = Discorb::ApplicationCommand::Command::GroupCommand.new(command_name, description, guild_ids, nil, self)
        command.yield_self(&block) if block_given?
        @commands << command
        command
      end

      #
      # Add message context menu command.
      #
      # @param [String] command_name Command name.
      # @param [Array<#to_s>, false, nil] guild_ids Guild IDs to set the command to. `false` to global command, `nil` to use default.
      # @param [Proc] block Command block.
      # @yield [interaction, message] Block to execute.
      # @yieldparam [Discorb::CommandInteraction::UserMenuCommand] interaction Interaction object.
      # @yieldparam [Discorb::Message] message Message object.
      #
      # @return [Discorb::ApplicationCommand::Command] Command object.
      #
      def message_command(command_name, guild_ids: nil, &block)
        command = Discorb::ApplicationCommand::Command.new(command_name, guild_ids, block, 3)
        @commands << command
        command
      end

      #
      # Add user context menu command.
      #
      # @param [String] command_name Command name.
      # @param [Array<#to_s>, false, nil] guild_ids Guild IDs to set the command to. `false` to global command, `nil` to use default.
      # @param [Proc] block Command block.
      # @yield [interaction, user] Block to execute.
      # @yieldparam [Discorb::CommandInteraction::UserMenuCommand] interaction Interaction object.
      # @yieldparam [Discorb::User] user User object.
      #
      # @return [Discorb::ApplicationCommand::Command] Command object.
      #
      def user_command(command_name, guild_ids: nil, &block)
        command = Discorb::ApplicationCommand::Command.new(command_name, guild_ids, block, 2)
        @commands << command
        command
      end

      #
      # Setup commands.
      # @async
      # @see Client#initialize
      #
      # @param [String] token Bot token.
      # @param [Array<#to_s>, false, nil] guild_ids Guild IDs to use as default. If `false` is given, it will be global command.
      #
      # @note `token` parameter only required if you don't run client.
      #
      def setup_commands(token = nil, guild_ids: nil)
        Async do
          @token ||= token
          @http = HTTP.new(self)
          global_commands = @commands.select { |c| c.guild_ids == false or c.guild_ids == [] }
          local_commands = @commands.select { |c| c.guild_ids.is_a?(Array) and c.guild_ids.any? }
          default_commands = @commands.select { |c| c.guild_ids.nil? }
          if guild_ids.is_a?(Array)
            default_commands.each do |command|
              command.instance_variable_set(:@guild_ids, guild_ids)
            end
            local_commands += default_commands
          else
            global_commands += default_commands
          end
          final_guild_ids = local_commands.map(&:guild_ids).flatten.map(&:to_s).uniq
          app_info = fetch_application.wait
          unless global_commands.empty?
            @http.request(
              Route.new(
                "/applications/#{app_info.id}/commands",
                "//applications/:application_id/commands",
                :put
              ),
              global_commands.map(&:to_hash)
            ).wait
          end
          if ENV["DISCORB_CLI_FLAG"] == "setup"
            sputs "Registered commands for global:"
            global_commands.each do |command|
              iputs "- #{command.name}"
            end
          end
          unless final_guild_ids.empty?
            final_guild_ids.each do |guild_id|
              commands = local_commands.select { |c| c.guild_ids.include?(guild_id) }
              @http.request(
                Route.new("/applications/#{app_info.id}/guilds/#{guild_id}/commands",
                          "//applications/:application_id/guilds/:guild_id/commands",
                          :put),
                commands.map(&:to_hash)
              ).wait
              sputs "Registered commands for #{guild_id}:"
              commands.each do |command|
                iputs "- #{command.name}"
              end
            end
          end
          @log.info "Successfully setup commands"
        end
      end
    end
  end
end