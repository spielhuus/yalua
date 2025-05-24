---
provider:
  model: models/gemini-2.5-pro-exp-03-25
  name: AiStudio
stream: true
name: Yaml
icon:
  character: 󰢱
  highlight: DevIconBlueprint
system_prompt: |
  You are an expert for YAML documents. Only answer according to the
  YAML SPEC
options:
  temperature: 0.01
  num_ctx: 4096
---

<== user
what are the YAML indicators?
==>

