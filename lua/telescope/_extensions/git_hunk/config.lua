local M = {}
M.config = {}

M.setup = function(ext_config, _config)
	for k, v in pairs(ext_config) do
		M.config[k] = v
	end
end
return M
