module SlackSup
  module Commands
    class Set < SlackRubyBot::Commands::Base
      include SlackSup::Commands::Mixins::Subscribe

      class << self
        def set_api(client, team, data, user, v)
          if user.is_admin? || v.nil?
            team.api = v.to_b unless v.nil?
            message = [
              "Team data access via the API is #{team.api_changed? ? 'now ' : ''}#{team.api? ? 'on' : 'off'}.",
              team.api_url
            ].compact.join("\n")
            client.say(channel: data.channel, text: message)
            team.save! if team.api_changed?
          else
            client.say(channel: data.channel, text: 'Only a Slack team admin can turn data access via the API on and off, sorry.')
          end
          logger.info "SET: #{team}, user=#{user.user_name}, api=#{team.api? ? 'on' : 'off'}"
        end

        def set_day(client, team, data, user, v)
          if user.is_admin? || v.nil?
            team.sup_wday = Date.parse(v).wday unless v.nil?
            client.say(channel: data.channel, text: "Team S'Up is#{team.sup_wday_changed? ? ' now' : ''} on #{team.sup_day}.")
            team.save! if team.sup_wday_changed?
          else
            client.say(channel: data.channel, text: "Team S'Up is on #{team.sup_day}. Only a Slack team admin can change that, sorry.")
          end
          logger.info "SET: #{team}, user=#{user.user_name}, sup_day=#{team.sup_day}."
        rescue ArgumentError
          raise SlackSup::Error, "Day _#{v}_ is invalid, try _Monday_, _Tuesday_, etc. Team S'Up is on #{team.sup_day}."
        end

        def set_timezone(client, team, data, user, v)
          if user.is_admin? || v.nil?
            unless v.nil?
              timezone = ActiveSupport::TimeZone.new(v)
              raise SlackSup::Error, "TimeZone _#{v}_ is invalid, see https://github.com/rails/rails/blob/5.1.3/activesupport/lib/active_support/values/time_zone.rb#L30 for a list. Team S'Up timezone is currently #{team.sup_tzone}." unless timezone
              team.sup_tz = timezone.name
            end
            client.say(channel: data.channel, text: "Team S'Up timezone is#{team.sup_tz_changed? ? ' now' : ''} #{team.sup_tzone}.")
            team.save! if team.sup_tz_changed?
          else
            client.say(channel: data.channel, text: "Team S'Up timezone is #{team.sup_tzone}. Only a Slack team admin can change that, sorry.")
          end
          logger.info "SET: #{team} user=#{user.user_name}, timezone=#{team.sup_tzone}."
        end

        def set_custom_profile_team_field(client, team, data, user, v = nil)
          if user.is_admin? || v.nil?
            team.team_field_label = v unless v.nil?
            if team.team_field_label_changed?
              team.save!
              client.say(channel: data.channel, text: "Custom profile team field is now _#{team.team_field_label || 'not set'}_.")
            else
              client.say(channel: data.channel, text: "Custom profile team field is _#{team.team_field_label || 'not set'}_.")
            end
          else
            client.say(channel: data.channel, text: "Custom profile team field is _#{team.team_field_label || 'not set'}_. Only a Slack team admin can change that, sorry.")
          end
          logger.info "SET: #{team}, user=#{user.user_name}, team_field_label=#{team.team_field_label || '(not set)'}."
        end

        def unset_custom_profile_team_field(client, team, data, user)
          if user.is_admin?
            team.team_field_label = nil
            if team.team_field_label_changed?
              team.save!
              client.say(channel: data.channel, text: 'Custom profile team field is now _not set_.')
            else
              client.say(channel: data.channel, text: 'Custom profile team field is not set.')
            end
          else
            client.say(channel: data.channel, text: "Custom profile team field is _#{team.team_field_label || 'not set'}_. Only a Slack team admin can change that, sorry.")
          end
          logger.info "UNSET: #{team}, user=#{user.user_name}, team_field_label=#{team.team_field_label || '(not set)'}."
        end

        def set(client, team, data, user, k, v)
          case k
          when 'api' then
            set_api client, team, data, user, v
          when 'day' then
            set_day client, team, data, user, v
          when 'tz', 'timezone' then
            set_timezone client, team, data, user, v
          when 'teamfield' then
            set_custom_profile_team_field client, team, data, user, v
          else
            raise SlackSup::Error, "Invalid setting _#{k}_, see _help_ for available options."
          end
        end

        def unset(client, team, data, user, k)
          case k
          when 'api' then
            set_api client, team, data, user, false
          when 'teamfield' then
            unset_custom_profile_team_field client, team, data, user
          else
            raise SlackSup::Error, "Invalid setting _#{k}_, see _help_ for available options."
          end
        end

        def parse_expression(m)
          m['expression']
            .gsub(/^team field/, 'teamfield')
            .split(/[\s]+/, 2)
        end
      end

      command 'set' do |client, data, match|
        user = ::User.find_create_or_update_by_slack_id!(client, data.user)
        if !match['expression']
          client.say(channel: data.channel, text: 'Missing setting, see _help_ for available options.')
          logger.info "SET: #{client.owner} - #{user.user_name}, failed, missing setting"
        else
          k, v = parse_expression(match)
          set client, client.owner, data, user, k, v
        end
      end

      command 'unset' do |client, data, match|
        user = ::User.find_create_or_update_by_slack_id!(client, data.user)
        if !match['expression']
          client.say(channel: data.channel, text: 'Missing setting, see _help_ for available options.')
          logger.info "UNSET: #{client.owner} - #{user.user_name}, failed, missing setting"
        else
          k, = parse_expression(match)
          unset client, client.owner, data, user, k
        end
      end
    end
  end
end
