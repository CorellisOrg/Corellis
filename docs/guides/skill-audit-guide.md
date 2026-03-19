# Skill Security Audit Guide

## Usage
```bash
# Scan installed skill
bash /shared/company-config/skill-audit.sh ~/workspace/skills/<skill-name>

# Strict mode (MEDIUM and above blocked)
bash /shared/company-config/skill-audit.sh ~/workspace/skills/<skill-name> --strict
```

## Decision Criteria
- **exit 0** → ✅ Pass
- **exit 1** → ⚠️ Risk detected, notify owner and show report, wait for confirmation
- **exit 2** → ❌ Critical risk, prohibit usage, delete and report

## Scan Scope (7 Dimensions)
1. 🐚 Reverse Shell / Remote Code Execution
2. 🔑 Data Exfiltration / API Key Theft
3. 🎭 Code Obfuscation / Encoding Bypass
4. 📦 Malicious Dependencies (typosquatting, install scripts)
5. 📁 Unauthorized File System Access
6. 🌐 Suspicious Network Activity
7. 🔒 Non-auditable Binary Files