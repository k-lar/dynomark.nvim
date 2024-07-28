if vim.fn.has("nvim-0.7.0") == 0 then
	vim.api.nvim_err_writeln("dynomark requires at least nvim-0.7.0.1")
	return
end

-- prevent loading file twice
if vim.g.loaded_dynomark == 1 then
	return
end
vim.g.loaded_dynomark = 1

-- user can disable plugin by setting
if vim.g.loaded_dynomark == 0 then
	return
end
