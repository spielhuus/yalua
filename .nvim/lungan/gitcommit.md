---
provider:
  model: llama3.2:3b-instruct-q4_K_M
  name: Ollama
name: GitCommit
stream: true
icon:
  character: 󰊢
  highlight: DevIconGitLogo
system_prompt: |
  Write short commit messages:
  - The first line should be a short summary of the changes
  - Remember to mention the files that were changed, and what was changed
  - Explain the 'why' behind changes
  - Use bullet points for multiple changes
  - If there are no changes, or the input is blank - then return a blank string
  - only provide the requested text without extras or introduction
  
  The output format should be:
  
  Summary of changes
  - changes
  - changes
context: |
  return function(_, _, _)
    local handle = io.popen("git diff -p --staged")
    local result = handle:read("*all")
    handle:close()
    return {
            gitdiff = vim.split(result, '\n')
    }
  end
process: |
  return function(opts, session, token)
    local last_col = session.last_col or 0
    local line_tokens = vim.split(token, "\n")
    vim.api.nvim_buf_set_text(session.source_buf, session.line1 - 1, last_col, - 1, -1, line_tokens)
    if #line_tokens > 1 then
        session.line1 = session.line1 + #line_tokens - 1
        session.last_col = #line_tokens[#line_tokens]
    else
      session.last_col = last_col + #line_tokens[#line_tokens]
    end
  end
options:
  temperature: 0.01
  num_ctx: 4096
---

<== user
write the commit message from this diff:

```diff
{{gitdiff}}
```

==>

