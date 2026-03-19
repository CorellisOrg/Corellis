# GitHub Token Self-Service Configuration

## Check if Already Configured
```bash
gh auth status
```

## Configuration Process

1. Guide user to visit https://github.com/settings/tokens?type=beta to create a Fine-grained PAT
2. Select needed repos and permissions (recommend minimal permissions)
3. After receiving the token:
   ```bash
   echo "<token>" | gh auth login --with-token
   gh auth status  # verify
   ```
4. Record in MEMORY.md: "GH token configured, stored in ~/.config/gh/, YYYY-MM-DD"

## Notes
- `gh` CLI is pre-installed (v4+)
- Token is stored in `~/.config/gh/`, persists after container restart
- No central control approval needed
- Can also use `gh auth login` interactive Device Flow