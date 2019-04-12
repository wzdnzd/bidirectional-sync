--   @Author  : kevinx
--   @Time    : 2019-03-20

-- need install lua lib 'lua-socket' (yum install -y lua-socket)
local socket = require("socket")

-- get current script path
function get_path()
    local info = debug.getinfo(1, "S")
    local path = info.source
    path = string.sub(path, 2, -1)
    path = string.match(path, "^.*/")

    return path
end

local curr_dir = get_path()

-- load json library
package.path = package.path .. ";" .. curr_dir .. "json.lua"
local json = require("json")

config_file = curr_dir .. "/config.json"
status_file = curr_dir .. "/status"

function parse_config(path)
    local file = io.open(path, "r")
    if file == nil then
        log('Error', 'config file not exists.')
        terminate(-1)
    end

    local text = file:read("*a")
    file:close()

    return json.decode(text)
end

function write_file(path, content)
    local file = io.open(path, 'w+')
    if file == nil then
        log('Error', 'open file failed.')
    end

    file:write(content)
    file:close()
end

function record_status(obj)
    local content = ''
    if type(obj) == 'string' then
        content = obj
    elseif type(obj) == 'table' then
        for k, v in pairs(obj) do
            content = content .. k .. "=" .. tostring(v) .. "\n"
        end
    end
    write_file(status_file, content)
end

string.split = function(str, sep)
    local result = {}
    string.gsub(str, '[^' .. sep .. ']+', function(w)
        table.insert(result, w)
    end)
    return result
end

string.startswith = function(str, substr)
    if str == nil or substr == nil then
        return nil, "the string or the sub-string is nil"
    end
    if string.find(str, substr) ~= 1 then
        return false
    else
        return true
    end
end

function str2boolean(arg)
    if type(arg) ~= 'string' then
        if type(arg) == 'boolean' then
            return arg
        else
            return false
        end
    else
        if arg == 'true' then
            return true
        else
            return false
        end
    end
end

if not default
then
    error('default not loaded');
end

function collect(agent, exitcode)
    local config = agent.config

    if not agent.isList and agent.etype == 'Init'
    then
        local rc = config.rsyncExitCodes[exitcode]

        if rc == 'ok'
        then
            log('Normal', 'Startup of "', agent.source, '" finished: ', exitcode)
        elseif rc == 'again'
        then
            if settings('insist')
            then
                log('Normal', 'Retrying startup of "', agent.source, '": ', exitcode)
            else
                log(
                        'Error',
                        'Temporary or permanent failure on startup of "',
                        agent.source, '". Terminating since "insist" is not set.'
                )

                terminate(-1) -- ERRNO
            end
        elseif rc == 'die'
        then
            log('Error', 'Failure on startup of "', agent.source, '": ', exitcode)
        else
            log('Error', 'Unknown exitcode on startup of "', agent.source, ': "', exitcode)

            rc = 'die'
        end

        return rc
    end

    if agent.isList
    then
        local rc = config.rsyncExitCodes[exitcode]

        if rc == 'ok'
        then
            log('Normal', 'Finished (list): ', exitcode)
        elseif rc == 'again'
        then
            log('Normal', 'Retrying (list): ', exitcode)
        elseif rc == 'die'
        then
            log('Error', 'Failure (list): ', exitcode)
        else
            log('Error', 'Unknown exitcode (list): ', exitcode)

            rc = 'die'
        end
        return rc
    else
        local rc = config.sshExitCodes[exitcode]

        if rc == 'ok'
        then
            log('Normal', 'Finished ', agent.etype, ' ', agent.sourcePath, ': ', exitcode)
        elseif rc == 'again'
        then
            log('Normal', 'Retrying ', agent.etype, ' ', agent.sourcePath, ': ', exitcode)
        elseif rc == 'die'
        then
            log('Normal', 'Failure ', agent.etype, ' ', agent.sourcePath, ': ', exitcode)
        else
            log('Error', 'Unknown exitcode ', agent.etype, ' ', agent.sourcePath, ': ', exitcode)

            rc = 'die'
        end

        return rc
    end

end

-- status record file format:
-- domain.change=true
-- domain.start=598738
-- domain.end=598969
-- ...

function init_status(path)
    local result = {}
    local file = io.open(path, 'r')
    if file ~= nil then
        for line in file:lines(path) do
            local tmp = string.split(line, '=')
            result[tmp[1]] = tmp[2]
        end
    end

    return result
end

profile = parse_config(config_file)

-- record status init
status = init_status(status_file)

settings {
    logfile = "/var/log/lsyncd/lsyncd.log",
    statusFile = "/var/log/lsyncd/lsyncd.status",
    inotifyMode = "CloseWrite or Modify",
    maxProcesses = 20,
    statusInterval = 15,
    nodaemon = true,
    maxDelays = profile.maxDelays
}

payload = {}
for _, v in pairs(profile) do
    if type(v) == 'table' then
        local option = {
            source = v.source,
            target = v.host .. ":" .. v.targetDir,
            excludeFrom = v.excludeFrom,
            exclude = v.exclude,
            delay = v.delay,
            delete = v.delete,
            rsync = {
                binary = v.script,
                archive = true,
                compress = true,
                verbose = true,
                perms = true,
                rsh = "/usr/bin/ssh -p 22 -o StrictHostKeyChecking=no"
            }
        }

        if profile.bwlimit then
            option.rsync._extra = { "--bwlimit=" .. tostring(profile.bwlimit) }
        end

        local params = {}
        params.domain = v.domain
        params.option = option
        params.timeout = v.waitTime

        table.insert(payload, params)
    end
end

local bisync = {
    default.rsync,
    checkgauge = {
        default.rsync.checkgauge,
        domain = true,
        timeout = true,
        default = true,
        option = true,
        rsyncExitCodes = true
    },
    maxProcesses = 10,
    action = function(inlet)
        local config = inlet.getConfig()

        -- detect if dns changes
        local change = str2boolean(status[config.domain .. '.change'])

        if not change then
            -- local cmd = "ping " .. config.domain .. " -c 1 |  sed '1{s/[^(]*(//;s/).*//;q}'"
            -- local current = io.popen(cmd):read("*a")
            local current = socket.dns.toip(config.domain)

            if current ~= nil and current ~= "" and current ~= status[config.domain .. '.last'] then
                change = true

                local now = os.time(os.date("!*t"))
                status[config.domain .. '.change'] = true
                status[config.domain .. '.last'] = current
                status[config.domain .. '.start'] = now
                status[config.domain .. '.end'] = now + config.timeout

                -- save status to file
                record_status(status)
            end
        end

        local event = inlet.getEvent()

        if change then
            local start = tonumber(status[config.domain .. '.start'])
            local during = os.time(os.date("!*t")) - start
            if config.timeout - during >= 0 then
                config.delay = config.timeout - during
            else
                config.delay = config.default
            end
        else
            local server = socket.dns.toip(profile.hostname)
            local tmp = string.split(server, '.')
            server = tmp[1] .. '.' .. tmp[2]
            if not string.startswith(current, server) then
                -- standby, discard
                inlet.discardEvent(event)
                return
            end
            config.delay = config.default
        end

        event.config = config
        return default.rsyncssh.action(event.inlet)
    end,
    collect = function(agent, exitcode)
        local config = agent.config
        local finish = tonumber(status[config.domain .. '.end'])

        -- sync success or timeout
        if exitcode == 0 or exitcode == 23 or exitcode == 24 or os.time(os.date("!*t")) > finish then
            local change = str2boolean(status[config.domain .. '.change'])
            if change then
                status[config.domain .. '.change'] = false
                record_status(status)
            end
        end
        return collect(agent, exitcode)
    end,
    prepare = function(config, level)
        if not config.domain then
            error("bisync needs 'domain' configured", 4)
        end

        if not config.timeout then
            error("bisync needs 'timeout' configured", 4)
        elseif type(config.timeout) ~= 'number' or config.timeout < 0 then
            error("timeout must be a number greet than 0", 4)
        end

        if config.option then
            if type(config.option) ~= 'table' then
                error("bisync needs 'option' configured and must be a table", 4)
            else
                for k, v in pairs(config.option) do
                    config[k] = v
                end
            end
        end

        -- save delay user configured
        if config.delay then
            config.default = config.delay
        else
            config.default = 15
        end

        -- if status file not exists, init it
        local flag = false
        for key, _ in pairs(status) do
            if string.startswith(key, config.domain) then
                local finish = tonumber(status[config.domain .. '.end'])
                -- if some reasons cause the status not to be updated in time, then it need init again
                if finish < os.time(os.date("!*t")) then
                    flag = true
                end
                break
            end
        end

        if not flag then
            local start = os.time(os.date("!*t"))

            status[config.domain .. '.start'] = start
            status[config.domain .. '.end'] = start + config.delay
            status[config.domain .. '.change'] = false
            status[config.domain .. '.last'] = socket.dns.toip(config.domain)

            record_status(status)
        end

        config.rsyncExitCodes = default.rsyncExitCodes
        return default.rsync.prepare(config, level)
    end
}

for _, value in ipairs(payload) do
    sync {
        bisync,
        domain = value.domain,
        option = value.option,
        timeout = value.timeout
    }
end
