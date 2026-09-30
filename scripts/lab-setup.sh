#!/bin/bash
# =============================================================================
# CeruleanPay Lab Setup Script
# =============================================================================
# Run each section in order on the appropriate machine:
#   Option 1 (GitHub Org Setup)   - run from your attacker workstation
#   Option 2 (Runner Setup)       - run on the 4GB VPS
#   Option 3 (Azure Setup)        - run from your attacker workstation
#   Option 4 (Azure DevOps Setup) - run from your attacker workstation
#   Option 5 (Validate Lab)       - run from your attacker workstation
# =============================================================================

set -euo pipefail

GH_ORG="ceruleanpay"
GH_RUNNER_TOKEN_FILE="/tmp/ceruleanpay_runner_token.txt"
GH_SECRETS_FILE="/tmp/ceruleanpay_github_secrets.txt"
RUNNER_NAME="ceruleanpay-runner"
RUNNER_LABELS="self-hosted,ceruleanpay-runner,linux"
RUNNER_VERSION="2.319.1"
RUNNER_OS="linux"
RUNNER_ARCH="x64"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")/lab"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC}  $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
step() { echo -e "\n${CYAN}${BOLD}── $* ──${NC}"; }

check_tool() {
  if ! command -v "$1" &>/dev/null; then
    err "Required tool not found: $1. Install it first."
    return 1
  fi
}

show_menu() {
  clear
  echo -e "${BOLD}"
  echo "  ╔═══════════════════════════════════════════════════╗"
  echo "  ║          CeruleanPay Lab Setup                    ║"
  echo "  ║          CI/CD Insider Threat Assessment          ║"
  echo "  ╠═══════════════════════════════════════════════════╣"
  echo "  ║                                                   ║"
  echo "  ║  [1]  GitHub Org Setup       (workstation)        ║"
  echo "  ║  [2]  Runner Setup           (VPS)                ║"
  echo "  ║  [3]  Azure Setup            (workstation)        ║"
  echo "  ║  [4]  Azure DevOps Setup     (workstation)        ║"
  echo "  ║  [5]  Validate Lab           (workstation)        ║"
  echo "  ║                                                   ║"
  echo "  ║  [0]  Exit                                        ║"
  echo "  ╚═══════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -n "  Select option: "
}

# =============================================================================
# OPTION 1: GitHub Org Setup
# Prerequisites:
#   - GitHub org "ceruleanpay" already created manually at github.com
#   - gh CLI authenticated as vamsi.krishna (org owner):  gh auth login
# =============================================================================
setup_github_org() {
  step "GitHub Org Setup"
  check_tool gh
  check_tool git

  GH_USER=$(gh api user --jq .login)
  info "Authenticated as: $GH_USER"

  if ! gh api "orgs/$GH_ORG" -q .login &>/dev/null; then
    err "GitHub org '$GH_ORG' not found."
    err "Create it at: github.com -> + -> New organization -> Free plan -> name: $GH_ORG"
    return 1
  fi
  ok "Org $GH_ORG found"

  step "Creating Repositories"
  for repo in payment-api infrastructure helm-charts; do
    if gh api "repos/$GH_ORG/$repo" -q .name &>/dev/null 2>&1; then
      warn "Repo $GH_ORG/$repo already exists - skipping"
    else
      gh repo create "$GH_ORG/$repo" --private -y
      ok "Created: $GH_ORG/$repo"
    fi
  done

  step "Creating Teams"
  for team in developers devops security-admins; do
    gh api "orgs/$GH_ORG/teams" --method POST -f name="$team" -f privacy=closed -q .slug 2>/dev/null && \
      ok "Created team: $team" || warn "Team $team may already exist"
  done

  step "Setting Organization Secrets"
  if [ -f "$GH_SECRETS_FILE" ]; then
    set -a; source "$GH_SECRETS_FILE"; set +a
    ok "Loaded Azure credentials from $GH_SECRETS_FILE"
  else
    warn "$GH_SECRETS_FILE not found - run Option 3 (Azure Setup) first"
    AZURE_CLIENT_ID="PLACEHOLDER"; AZURE_TENANT_ID="PLACEHOLDER"
    AZURE_SUBSCRIPTION_ID="PLACEHOLDER"; DB_PASSWORD="PLACEHOLDER"
  fi

  set_secret() { echo "$2" | gh secret set "$1" --org "$GH_ORG" --visibility all && ok "Secret: $1"; }

  set_secret "AZURE_CLIENT_ID"       "${AZURE_CLIENT_ID:-PLACEHOLDER}"
  set_secret "AZURE_TENANT_ID"       "${AZURE_TENANT_ID:-PLACEHOLDER}"
  set_secret "AZURE_SUBSCRIPTION_ID" "${AZURE_SUBSCRIPTION_ID:-PLACEHOLDER}"
  set_secret "ACR_NAME"              "ceruleanpaycr"
  set_secret "KEY_VAULT_NAME"        "ceruleanpay-kv"
  set_secret "DB_HOST"               "127.0.0.1"
  set_secret "DB_PORT"               "5432"
  set_secret "DB_NAME"               "ceruleanpay"
  set_secret "DB_USER"               "cerulean_app"
  set_secret "DB_PASSWORD"           "${DB_PASSWORD:-PLACEHOLDER}"
  set_secret "PAYMENT_API_KEY"       "cp_live_$(openssl rand -hex 24 2>/dev/null || echo PLACEHOLDER)"
  set_secret "SCANNER_API_KEY"       "scanner_$(openssl rand -hex 16 2>/dev/null || echo PLACEHOLDER)"
  set_secret "CI_BOT_PAT"            "REPLACE_WITH_CI_BOT_PAT"

  warn "MISCONFIGURATION: All secrets org-wide, accessible to all repos"
  warn "MISCONFIGURATION: GITHUB_TOKEN set to read-write below"

  step "Pushing Lab Code to GitHub"
  push_repo() {
    local dir="$1" repo="$2"
    [ -d "$dir" ] || { warn "$dir not found, skipping"; return; }
    local tmp=$(mktemp -d)
    cp -r "$dir/." "$tmp/"
    cd "$tmp"
    git init -b main
    git config user.email "anjali.v@ceruleanpay.in"
    git config user.name "Anjali V"
    git add .
    git commit -m "Initial commit - CeruleanPay $repo" --no-gpg-sign
    git remote add origin "https://github.com/$GH_ORG/$repo.git"
    git push -u origin main --force
    cd - > /dev/null; rm -rf "$tmp"
    ok "Pushed $dir -> $GH_ORG/$repo"
  }
  push_repo "$LAB_DIR/payment-api" "payment-api"
  push_repo "$LAB_DIR/infrastructure" "infrastructure"

  step "Generating Runner Registration Token"
  RUNNER_TOKEN=$(gh api --method POST "orgs/$GH_ORG/actions/runners/registration-token" --jq .token)
  echo "$RUNNER_TOKEN" > "$GH_RUNNER_TOKEN_FILE"
  ok "Runner token saved to $GH_RUNNER_TOKEN_FILE (expires in 1 hour)"

  step "Configuring Org Settings"
  gh api --method PUT "orgs/$GH_ORG/actions/permissions" \
    -f enabled_repositories=all -f allowed_actions=all -q .allowed_actions
  ok "GitHub Actions: allowed from all sources"
  warn "MISCONFIGURATION: org allows Actions from untrusted publishers"

  gh api --method PUT "orgs/$GH_ORG/actions/permissions/workflow" \
    -f default_workflow_permissions=write -F can_approve_pull_request_reviews=true \
    -q .default_workflow_permissions 2>/dev/null || \
    warn "Could not set workflow permissions via API - set manually in org settings"

  echo ""
  ok "GitHub org setup complete. Run Option 2 on VPS next."
}

# =============================================================================
# OPTION 2: Runner Setup (run on VPS as root)
# Prerequisites: Ubuntu 22.04 or 24.04, 4GB RAM, root access
# =============================================================================
setup_runner() {
  step "Runner Setup"

  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq curl wget git jq unzip build-essential \
    docker.io docker-compose-v2 postgresql-client ca-certificates gnupg

  if ! node --version 2>/dev/null | grep -q "^v18"; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
  fi
  ok "Node.js: $(node --version)"

  systemctl enable --now docker
  ok "Docker: $(docker --version)"

  if ! systemctl is-active --quiet postgresql; then
    apt-get install -y postgresql postgresql-contrib
    systemctl enable --now postgresql
  fi
  ok "PostgreSQL: $(psql --version)"

  RUNNER_TOKEN_VALUE=""
  if [ -f "$GH_RUNNER_TOKEN_FILE" ]; then
    RUNNER_TOKEN_VALUE=$(cat "$GH_RUNNER_TOKEN_FILE")
    info "Loaded runner token from file"
  else
    echo -n "Paste runner registration token (from Option 1): "
    read -r RUNNER_TOKEN_VALUE
  fi
  [ -z "$RUNNER_TOKEN_VALUE" ] && { err "Runner token required."; return 1; }

  echo -n "Enter DB_PASSWORD: "
  read -r -s DB_PASS; echo ""
  su - postgres -c "psql -c \"CREATE ROLE cerulean_app WITH LOGIN PASSWORD '$DB_PASS';\"" 2>/dev/null || true
  su - postgres -c "psql -c \"CREATE DATABASE ceruleanpay OWNER cerulean_app;\"" 2>/dev/null || true
  ok "PostgreSQL database: ceruleanpay"

  RUNNER_DIR="/home/runner/actions-runner"
  useradd -m -s /bin/bash runner 2>/dev/null || true
  mkdir -p "$RUNNER_DIR"; chown runner:runner "$RUNNER_DIR"

  RUNNER_ARCHIVE="actions-runner-${RUNNER_OS}-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
  if [ ! -f "$RUNNER_DIR/config.sh" ]; then
    curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_ARCHIVE}" \
      -o "/tmp/$RUNNER_ARCHIVE"
    tar xzf "/tmp/$RUNNER_ARCHIVE" -C "$RUNNER_DIR"
    chown -R runner:runner "$RUNNER_DIR"
    ok "Runner extracted to $RUNNER_DIR"
  fi

  # MISCONFIGURATION: RUNNER_ALLOW_RUNASROOT
  export RUNNER_ALLOW_RUNASROOT=1
  cd "$RUNNER_DIR"
  RUNNER_ALLOW_RUNASROOT=1 ./config.sh \
    --url "https://github.com/$GH_ORG" \
    --token "$RUNNER_TOKEN_VALUE" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --runnergroup Default \
    --unattended --replace

  ok "Runner configured: $RUNNER_NAME"
  warn "MISCONFIGURATION: Runner in Default group, no approval gate for fork PRs"

  RUNNER_ALLOW_RUNASROOT=1 ./svc.sh install 2>/dev/null || true
  RUNNER_ALLOW_RUNASROOT=1 ./svc.sh start  2>/dev/null || true

  ok "Runner setup complete. Run Option 3 (Azure Setup) on workstation."
}

# =============================================================================
# OPTION 3: Azure Setup
# Prerequisites: az login, jq, openssl
# =============================================================================
setup_azure() {
  step "Azure Setup"
  check_tool az; check_tool jq; check_tool openssl
  AZURE_SCRIPT="$LAB_DIR/infrastructure/azure/setup.sh"
  [ -f "$AZURE_SCRIPT" ] || { err "$AZURE_SCRIPT not found"; return 1; }
  chmod +x "$AZURE_SCRIPT"
  bash "$AZURE_SCRIPT"
  info "Add secrets from $GH_SECRETS_FILE to: github.com/organizations/$GH_ORG/settings/secrets/actions"
}

# =============================================================================
# OPTION 4: Azure DevOps Setup (White Knight Labs path)
# =============================================================================
setup_azure_devops() {
  step "Azure DevOps Setup"
  check_tool az
  az extension add --name azure-devops --only-show-errors 2>/dev/null || true

  echo -n "Azure DevOps org name (from dev.azure.com/<name>): "
  read -r ADO_ORG
  echo -n "Azure DevOps PAT: "
  read -r -s ADO_PAT; echo ""
  export AZURE_DEVOPS_EXT_PAT="$ADO_PAT"

  az devops configure --defaults organization="https://dev.azure.com/$ADO_ORG"

  az devops project create --name CeruleanPay --visibility private \
    --source-control git --process Agile 2>/dev/null || warn "Project may already exist"

  warn "Manual step required:"
  warn "  Go to: dev.azure.com/$ADO_ORG/CeruleanPay/_settings/agentqueues"
  warn "  Create pool: ceruleanpay-agents"
  warn "  Check 'Grant access permission to all pipelines' (MISCONFIGURATION)"
  warn "  Then: New agent -> Linux -> follow instructions to register on VPS"

  ok "Azure DevOps org configured at dev.azure.com/$ADO_ORG"
}

# =============================================================================
# OPTION 5: Validate Lab
# =============================================================================
validate_lab() {
  step "Lab Validation"
  PASS=0; FAIL=0; WARN_COUNT=0

  check_pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS++)); }
  check_fail() { echo -e "  ${RED}[FAIL]${NC} $1"; ((FAIL++)); }
  check_warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; ((WARN_COUNT++)); }

  echo "GitHub:"
  gh api "orgs/$GH_ORG" -q .login &>/dev/null 2>&1 && check_pass "Org $GH_ORG exists" || check_fail "Org $GH_ORG not found"
  for repo in payment-api infrastructure; do
    gh api "repos/$GH_ORG/$repo" -q .name &>/dev/null 2>&1 && \
      check_pass "Repo $GH_ORG/$repo exists" || check_fail "Repo $GH_ORG/$repo missing"
  done

  RUNNER_STATUS=$(gh api "orgs/$GH_ORG/actions/runners" --jq ".runners[] | select(.name==\"$RUNNER_NAME\") | .status" 2>/dev/null || echo "")
  [ "$RUNNER_STATUS" = "online" ]  && check_pass "Runner $RUNNER_NAME is online" || \
  [ "$RUNNER_STATUS" = "offline" ] && check_warn "Runner $RUNNER_NAME registered but offline" || \
    check_fail "Runner $RUNNER_NAME not found"

  for secret in AZURE_CLIENT_ID AZURE_TENANT_ID DB_PASSWORD PAYMENT_API_KEY; do
    gh api "orgs/$GH_ORG/actions/secrets/$secret" -q .name &>/dev/null 2>&1 && \
      check_pass "Secret $secret exists" || check_fail "Secret $secret missing"
  done

  CI_WF=$(gh api "repos/$GH_ORG/payment-api/contents/.github/workflows/ci.yml" -q .content 2>/dev/null | base64 -d 2>/dev/null || echo "")
  echo "$CI_WF" | grep -q "pull_request_target" && check_pass "VULN: pull_request_target in ci.yml" || check_warn "pull_request_target not found"
  echo "$CI_WF" | grep -q 'pull_request.title'  && check_pass "VULN: expression injection in ci.yml" || check_warn "expression injection not found"

  DEPLOY_WF=$(gh api "repos/$GH_ORG/payment-api/contents/.github/workflows/deploy.yml" -q .content 2>/dev/null | base64 -d 2>/dev/null || echo "")
  echo "$DEPLOY_WF" | grep -q "id-token: write" && check_pass "VULN: OIDC token in deploy.yml"   || check_warn "OIDC token permission not found"
  echo "$DEPLOY_WF" | grep -q "printenv"        && check_pass "VULN: printenv in deploy.yml"     || check_warn "printenv not found"

  echo ""
  echo "Azure:"
  az group show --name ceruleanpay-rg &>/dev/null 2>&1 && check_pass "Resource group ceruleanpay-rg" || check_fail "Resource group ceruleanpay-rg missing"
  az acr show --name ceruleanpaycr    &>/dev/null 2>&1 && check_pass "ACR ceruleanpaycr"              || check_fail "ACR ceruleanpaycr missing"
  az keyvault show --name ceruleanpay-kv &>/dev/null 2>&1 && check_pass "Key Vault ceruleanpay-kv"   || check_fail "Key Vault ceruleanpay-kv missing"

  APP_ID=$(az ad app list --display-name ceruleanpay-cicd --query '[0].appId' -o tsv 2>/dev/null || echo "")
  [ -n "$APP_ID" ] && check_pass "App registration ceruleanpay-cicd ($APP_ID)" || check_fail "App registration not found"
  if [ -n "$APP_ID" ]; then
    FED=$(az ad app federated-credential list --id "$APP_ID" --query '[0].subject' -o tsv 2>/dev/null || echo "")
    echo "$FED" | grep -q '\*' && check_pass "VULN: OIDC wildcard subject: $FED" || check_warn "OIDC subject (expected wildcard): $FED"
  fi

  echo ""
  echo "═══════════════════════════════════════"
  echo -e "  ${GREEN}$PASS passed${NC}, ${YELLOW}$WARN_COUNT warnings${NC}, ${RED}$FAIL failed${NC}"
  echo "═══════════════════════════════════════"
  [ "$FAIL" -eq 0 ] && ok "Lab ready for attack exercises." || warn "Fix failures before proceeding."
}

# =============================================================================
# Main
# =============================================================================
main() {
  if [ $# -gt 0 ]; then
    case "$1" in
      1) setup_github_org ;;
      2) setup_runner ;;
      3) setup_azure ;;
      4) setup_azure_devops ;;
      5) validate_lab ;;
      *) echo "Usage: $0 [1|2|3|4|5]"; exit 1 ;;
    esac
    exit 0
  fi

  while true; do
    show_menu; read -r choice; echo ""
    case "$choice" in
      1) setup_github_org ;;
      2) setup_runner ;;
      3) setup_azure ;;
      4) setup_azure_devops ;;
      5) validate_lab ;;
      0) echo "Exiting."; exit 0 ;;
      *) echo "Invalid option." ;;
    esac
    echo -n "Press Enter to continue..."; read -r
  done
}

main "$@"
