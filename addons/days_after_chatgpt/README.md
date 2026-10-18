# DAY'S AFTER ChatGPT Helper (Godot 4.x)

This optional editor dock is designed as a low-cost bridge for the Godot Android Editor. It does **not** call the OpenAI API, store credentials, or modify game files. It uses the ChatGPT app/site you already access, so it does not add API charges.

## Install in a separate test copy first

1. Make a separate copy/branch of the DAY'S AFTER project before trying the plugin.
2. Copy the folder `addons/days_after_chatgpt/` into the project copy.
3. Open the copy in Godot 4.x.
4. Open **Project → Project Settings → Plugins** and enable **DAY'S AFTER ChatGPT Helper**.
5. The dock should appear on the right side of the editor. If it is hidden, check the editor's dock layout.

## Use it

1. Enter one specific task in the top field.
2. Optionally paste the relevant script or error. Never paste passwords, signing keys, API keys, or tokens.
3. Tap **Copy safe prompt**.
4. Tap **Open ChatGPT**, paste the prompt into ChatGPT, and ask for the proposed fix.
5. Paste the answer into the response field if you want to keep it visible while working.
6. Review and apply code manually to the separate test copy. Run the project and test before moving any changes to your main branch.

## Important limitations

- This is a prompt bridge, not a live API-powered chat window.
- It does not read project files automatically, apply generated code, or run tests.
- Using the OpenAI API directly would be a separate integration and may incur API charges. A ChatGPT subscription does not automatically include API usage.
- The Godot Android Editor has platform limitations; this plugin uses standard editor/GDScript APIs and should still be tested on the exact Godot version installed on your phone.

## Safe rollout

The original `main` branch is not changed by this feature branch. Keep this plugin optional until it has been tested on a duplicate project and confirmed not to affect the game.
