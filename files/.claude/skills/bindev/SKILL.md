---
name: bindev
description: Start the local development server in a tmux session and open the homepage. Use when the user wants to start development, run the app locally, fire up the dev server, or invokes /bindev.
---

# bindev

Start `bin/dev` (the Procfile.dev fleet: web + tailwind watcher + Solid Queue
worker) in a detached tmux session and open the homepage in the browser.

## Workflow

1. Run the startup script:
   ```bash
   bash .claude/skills/bindev/scripts/start_dev.sh
   ```

2. Interpret the output:
   - `ALREADY_RUNNING` + `READY` — server was already up, open the browser
   - `STARTED` + `READY` — server started cleanly, open the browser
   - `STARTED` + `TIMEOUT` — process started but didn't respond in 20s; warn
     the user and have them `tmux attach -t APPNAME-dev` to see the logs

3. Open the homepage:
   ```bash
   open http://localhost:APPNAME_PORT
   ```

4. Confirm to the user that the dev server is up and the homepage is open.

## Tmux session

The fleet runs in a tmux session named `APPNAME-dev`. Useful commands:

- Attach: `tmux attach -t APPNAME-dev`
- Kill: `tmux kill-session -t APPNAME-dev`
- List: `tmux ls`
