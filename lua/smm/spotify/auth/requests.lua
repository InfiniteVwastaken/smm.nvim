local config = require 'smm.spotify.auth.config'
local api_sync = require 'smm.utils.api_sync'
local logger = require 'smm.utils.logger'

---@alias SMM_AuthInfo { access_token: string, token_type: string, expires_in: integer, expires_at: integer, refresh_token: string, scope: string }

local M = {}

local function process_token_response(response_body, status_code, operation)
  if status_code ~= 200 then
    local detail = 'no error details returned'
    if type(response_body) == 'table' then
      local error_name = response_body.error
      local error_description = response_body.error_description
      if error_name or error_description then
        detail = tostring(error_name or 'OAuth error')
        if error_description then
          detail = detail .. ': ' .. tostring(error_description)
        end
      end
    end
    logger.warn('Spotify %s failed (HTTP %s): %s', operation, tostring(status_code), detail)
    return nil
  end

  if type(response_body) ~= 'table' or type(response_body.expires_in) ~= 'number' then
    logger.warn('Spotify %s returned an invalid token response (HTTP %s)', operation, tostring(status_code))
    return nil
  end

  response_body.expires_at = os.time() + response_body.expires_in
  return response_body
end

---@param code string
---@param code_verifier string
---@param redirect_uri string
---@return SMM_AuthInfo|nil
function M.get_access_token(code, code_verifier, redirect_uri)
  local url = 'https://accounts.spotify.com'
  local endpoint = 'api/token'

  local body = {
    code = code,
    redirect_uri = redirect_uri,
    grant_type = 'authorization_code',
    client_id = config.get().client_id,
    code_verifier = code_verifier,
  }

  logger.debug('URL: %s/%s', url, endpoint)

  local response_body, _, status_code = api_sync.send_post_request {
    base_url = url,
    endpoint = endpoint,
    body = body,
  }

  return process_token_response(response_body, status_code, 'authorization-code exchange')
end

---@param refresh_token
---@return SMM_AuthInfo|nil
function M.refresh_access_token(refresh_token)
  local url = 'https://accounts.spotify.com'
  local endpoint = 'api/token'

  local body = {
    grant_type = 'refresh_token',
    refresh_token = refresh_token,
    client_id = config.get().client_id,
  }

  local response_body, _, status_code = api_sync.send_post_request {
    base_url = url,
    endpoint = endpoint,
    body = body,
  }

  local auth_info = process_token_response(response_body, status_code, 'refresh-token request')
  if not auth_info then
    return nil
  end

  auth_info.refresh_token = auth_info.refresh_token or refresh_token

  return auth_info
end

return M
