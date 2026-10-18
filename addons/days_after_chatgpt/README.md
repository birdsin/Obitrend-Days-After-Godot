# DAY'S AFTER ChatGPT Assistant (Godot 4.x)

This optional editor dock provides a direct OpenAI API mode and a copy-prompt workflow for ChatGPT. It does not apply generated code automatically.

## Install safely
1. Download this branch as a ZIP and extract it to a separate folder, or copy `addons/days_after_chatgpt/` into a duplicate project.
2. Open the duplicate in Godot 4.x Android Editor.
3. Open Project → Project Settings → Plugins and enable DAY'S AFTER ChatGPT Assistant.
4. Confirm the dock appears. Test only in the duplicate project before considering any changes to the original.

## Live API mode
1. Create/use an OpenAI API key from your OpenAI Platform account. API billing is separate from a ChatGPT subscription.
2. Enter it into the masked API-key field in the dock.
3. Keep the model as `gpt-5-mini` unless your API project has access to another model.
4. Tap Save API settings on this device, then Ask OpenAI.
5. The key is saved in local Godot editor settings, not in the project files. Never place it in a script, scene, repository, or game build.
6. Requests send the task and any pasted context to OpenAI. Do not include private information.

## Safety and limitations
- API usage may incur charges.
- This direct API mode is for your own local editor. Do not ship a personal key with a game or share it with other users. Public/team tools should use an authenticated backend with server-side secrets and usage limits.
- The assistant does not index files automatically, apply changes, or run tests. Review suggestions and apply them manually in the test copy.
- Android editor compatibility still needs to be verified on your exact Godot version.
