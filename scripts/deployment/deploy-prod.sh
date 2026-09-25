#!/bin/bash
#
# deploy-prod.sh - Deploy Sertantai Compliance to production server
#
# This script deploys to production:
#   - Frontend: Docker container (pull + restart)
#   - Backend: Phoenix Docker container (pull + restart)
#   - Electric: ElectricSQL sync service (safe restart)
#
# Usage:
#   ./scripts/deployment/deploy-prod.sh --version X.Y.Z [options]
#
# Releases are pinned: --version is required to deploy the frontend or backend
# ('latest' is refused). It sets SERTANTAI_COMPLIANCE_VERSION in the server's
# .env (one variable pins both images, so they always ship together), records
# the deploy in compliance-deploy-history.log on the server, and checks the
# live /health reports the version. Roll back with --version <previous>.
# See docs/RELEASING.md.
#
# Options:
#   --version X.Y.Z    Release to deploy (required unless --check-only/--electric)
#   --skip-backup      Don't dump the database before a backend deploy (default:
#                      dump, because the backend runs migrations on start)
#   --all              Deploy both frontend and backend (default)
#   --frontend         Deploy frontend only
#   --backend          Deploy backend only
#   --electric         Restart ElectricSQL only (safe restart)
#   --with-electric    Also restart ElectricSQL when deploying backend
#   --electric-clear-cache  Restart Electric and clear shape cache
#   --migrate          Run database migrations
#   --check-only       Only check status, don't deploy
#   --logs             Follow logs after deployment
#   --help             Show this help message
#
# ElectricSQL Notes:
#   - Uses 'docker restart' for safe restarts (preserves database)
#   - NEVER uses 'docker compose up electric' without --no-deps (can wipe database!)
#   - Clear cache when schema changes or shapes are stale
#   - Electric container: sertantai_compliance_electric
#
# Prerequisites:
#   - SSH access to sertantai-hz server configured
#   - Backend: Image pushed to GHCR
#   - Frontend: Image pushed to GHCR
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER="sertantai-hz"
DEPLOY_PATH="~/infrastructure/docker"
BACKEND_SERVICE="sertantai-compliance"
FRONTEND_SERVICE="sertantai-compliance-frontend"
ELECTRIC_CONTAINER="sertantai_compliance_electric"
ELECTRIC_COMPOSE_SERVICE="sertantai-compliance-electric"
SITE_URL="https://compliance.sertantai.com"
ELECTRIC_URL="${SITE_URL}/electric"
BACKEND_PORT=4004
# Compliance shares legal's prod database (see sertantai-stack docker-compose.yml)
DB_CONTAINER="shared_postgres"
DB_NAME="sertantai_legal_prod"
BACKUP_DIR="~/backups/compliance"
ELECTRIC_INTERNAL_PORT=3000

# Parse command line options
DEPLOY_FRONTEND=true
DEPLOY_BACKEND=true
DEPLOY_ELECTRIC=false
WITH_ELECTRIC=false
ELECTRIC_CLEAR_CACHE=false
RUN_MIGRATIONS=false
CHECK_ONLY=false
FOLLOW_LOGS=false
RELEASE_VERSION=""
SKIP_BACKUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            RELEASE_VERSION="${2:-}"
            shift 2
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --all)
            DEPLOY_FRONTEND=true
            DEPLOY_BACKEND=true
            shift
            ;;
        --frontend)
            DEPLOY_FRONTEND=true
            DEPLOY_BACKEND=false
            shift
            ;;
        --backend)
            DEPLOY_FRONTEND=false
            DEPLOY_BACKEND=true
            shift
            ;;
        --electric)
            DEPLOY_FRONTEND=false
            DEPLOY_BACKEND=false
            DEPLOY_ELECTRIC=true
            shift
            ;;
        --with-electric)
            WITH_ELECTRIC=true
            shift
            ;;
        --electric-clear-cache)
            DEPLOY_FRONTEND=false
            DEPLOY_BACKEND=false
            DEPLOY_ELECTRIC=true
            ELECTRIC_CLEAR_CACHE=true
            shift
            ;;
        --migrate)
            RUN_MIGRATIONS=true
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --logs)
            FOLLOW_LOGS=true
            shift
            ;;
        --help)
            echo "Usage: $0 --version X.Y.Z [options]"
            echo ""
            echo "Options:"
            echo "  --version X.Y.Z    Release to deploy (required to deploy frontend/backend)"
            echo "  --skip-backup      Skip the pre-deploy database dump (backend deploys)"
            echo "  --all              Deploy both frontend and backend (default)"
            echo "  --frontend         Deploy frontend only"
            echo "  --backend          Deploy backend only"
            echo "  --electric         Restart ElectricSQL only (safe restart)"
            echo "  --with-electric    Also restart ElectricSQL when deploying backend"
            echo "  --electric-clear-cache  Restart Electric and clear shape cache"
            echo "  --migrate          Run database migrations"
            echo "  --check-only       Only check status, don't deploy"
            echo "  --logs             Follow logs after deployment"
            echo "  --help             Show this help message"
            echo ""
            echo "Production Details:"
            echo "  Server:        ${SERVER}"
            echo "  Infrastructure: ${DEPLOY_PATH}"
            echo "  Backend:       ${BACKEND_SERVICE}"
            echo "  Frontend:      ${FRONTEND_SERVICE}"
            echo "  Electric:      ${ELECTRIC_CONTAINER}"
            echo "  URL:           ${SITE_URL}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Navigate to project root
cd "$(dirname "$0")/../.."

# Releases are pinned to a version (docs/RELEASING.md)
if [ "$CHECK_ONLY" = false ] && { [ "$DEPLOY_FRONTEND" = true ] || [ "$DEPLOY_BACKEND" = true ]; }; then
    if [ -z "$RELEASE_VERSION" ]; then
        echo -e "${RED}✗ --version X.Y.Z is required (prod runs pinned releases)${NC}"
        exit 1
    fi
    if [ "$RELEASE_VERSION" = "latest" ] || ! [[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]]; then
        echo -e "${RED}✗ Invalid version '${RELEASE_VERSION}': use X.Y.Z or X.Y.Z-rc.N ('latest' is refused)${NC}"
        exit 1
    fi
    if [ "$DEPLOY_FRONTEND" != "$DEPLOY_BACKEND" ]; then
        echo -e "${YELLOW}⚠ Partial deploy: both images share SERTANTAI_COMPLIANCE_VERSION, so the other${NC}"
        echo -e "${YELLOW}  service will also run ${RELEASE_VERSION} the next time it restarts.${NC}"
    fi
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Sertantai Compliance - Production Deployment${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Server:${NC} ${SERVER}"
echo -e "${YELLOW}URL:${NC} ${SITE_URL}"
[ -n "$RELEASE_VERSION" ] && echo -e "${YELLOW}Version:${NC} ${RELEASE_VERSION}"

# Show what will be deployed
if [ "$DEPLOY_ELECTRIC" = true ]; then
    if [ "$ELECTRIC_CLEAR_CACHE" = true ]; then
        echo -e "${YELLOW}Deploying:${NC} ElectricSQL (with cache clear)"
    else
        echo -e "${YELLOW}Deploying:${NC} ElectricSQL only"
    fi
elif [ "$DEPLOY_FRONTEND" = true ] && [ "$DEPLOY_BACKEND" = true ]; then
    if [ "$WITH_ELECTRIC" = true ]; then
        echo -e "${YELLOW}Deploying:${NC} Full stack (frontend + backend + electric)"
    else
        echo -e "${YELLOW}Deploying:${NC} Full stack (frontend + backend)"
    fi
elif [ "$DEPLOY_FRONTEND" = true ]; then
    echo -e "${YELLOW}Deploying:${NC} Frontend only"
elif [ "$DEPLOY_BACKEND" = true ]; then
    if [ "$WITH_ELECTRIC" = true ]; then
        echo -e "${YELLOW}Deploying:${NC} Backend + ElectricSQL"
    else
        echo -e "${YELLOW}Deploying:${NC} Backend only"
    fi
fi
echo ""

# Check SSH connectivity
echo -e "${BLUE}Checking SSH connection to ${SERVER}...${NC}"
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${SERVER}" "echo 'SSH OK'" > /dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to ${SERVER}${NC}"
    echo -e "${YELLOW}  Check your SSH configuration and try again${NC}"
    exit 1
fi
echo -e "${GREEN}✓ SSH connection OK${NC}"
echo ""

# ============================================================
# CHECK-ONLY MODE
# ============================================================
if [ "$CHECK_ONLY" = true ]; then
    echo -e "${BLUE}Checking production status...${NC}"
    echo ""

    echo -e "${BLUE}Deployed version:${NC}"
    echo "  .env:    $(ssh "${SERVER}" "grep -E '^SERTANTAI_COMPLIANCE_VERSION=' ${DEPLOY_PATH}/.env | cut -d= -f2" 2>/dev/null || echo unknown)"
    echo "  /health: $(curl -sf "${SITE_URL}/health" | sed -nE 's/.*"version":"([^"]+)".*/\1/p')"
    ssh "${SERVER}" "tail -n 3 ${DEPLOY_PATH}/compliance-deploy-history.log" 2>/dev/null | sed 's/^/  /' || true
    echo ""

    echo -e "${BLUE}Backend Status:${NC}"
    ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose ps ${BACKEND_SERVICE}" 2>/dev/null || echo "  Backend not running"
    echo ""

    echo -e "${BLUE}Frontend Status:${NC}"
    ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose ps ${FRONTEND_SERVICE}" 2>/dev/null || echo "  Frontend not running"
    echo ""

    echo -e "${BLUE}ElectricSQL Status:${NC}"
    ssh "${SERVER}" "docker ps --filter name=${ELECTRIC_CONTAINER} --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" || echo "  Electric not running"

    # Check Electric health
    if ssh "${SERVER}" "docker exec ${ELECTRIC_CONTAINER} curl -sf http://localhost:3000/v1/health" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Electric health check passed"
    else
        echo -e "  ${YELLOW}⚠${NC} Electric health check failed"
    fi
    echo ""

    echo -e "${BLUE}Recent Backend Logs:${NC}"
    ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose logs --tail=15 ${BACKEND_SERVICE}" 2>/dev/null || echo "  No logs available"

    echo ""
    echo -e "${GREEN}Status check complete${NC}"
    exit 0
fi

# ============================================================
# PIN VERSION
# ============================================================
PREVIOUS_VERSION=""
if [ -n "$RELEASE_VERSION" ] && { [ "$DEPLOY_FRONTEND" = true ] || [ "$DEPLOY_BACKEND" = true ]; }; then
    PREVIOUS_VERSION="$(ssh "${SERVER}" "grep -E '^SERTANTAI_COMPLIANCE_VERSION=' ${DEPLOY_PATH}/.env | cut -d= -f2" 2>/dev/null || true)"
    echo -e "${BLUE}Pinning SERTANTAI_COMPLIANCE_VERSION: ${PREVIOUS_VERSION:-unset} → ${RELEASE_VERSION}${NC}"
    if ssh "${SERVER}" "cd ${DEPLOY_PATH} && cp .env .env.compliance-previous && \
        if grep -q '^SERTANTAI_COMPLIANCE_VERSION=' .env; then \
          sed -i 's/^SERTANTAI_COMPLIANCE_VERSION=.*/SERTANTAI_COMPLIANCE_VERSION=${RELEASE_VERSION}/' .env; \
        else echo 'SERTANTAI_COMPLIANCE_VERSION=${RELEASE_VERSION}' >> .env; fi && \
        grep -qx 'SERTANTAI_COMPLIANCE_VERSION=${RELEASE_VERSION}' .env"; then
        echo -e "${GREEN}✓ Version pinned (previous .env saved as .env.compliance-previous)${NC}"
    else
        echo -e "${RED}✗ Failed to set the version in ${DEPLOY_PATH}/.env${NC}"
        exit 1
    fi
    echo ""
fi

# ============================================================
# BACKUP (backend deploys run migrations on container start)
# ============================================================
if [ "$DEPLOY_BACKEND" = true ] && [ "$SKIP_BACKUP" = false ]; then
    BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}-$(date -u +%Y%m%dT%H%M%SZ)-pre-${RELEASE_VERSION}.dump"
    echo -e "${BLUE}Backing up ${DB_NAME} → ${BACKUP_FILE}...${NC}"
    if ssh "${SERVER}" "mkdir -p ${BACKUP_DIR} && docker exec ${DB_CONTAINER} sh -c 'pg_dump -U \"\$POSTGRES_USER\" -Fc ${DB_NAME}' > ${BACKUP_FILE} && test -s ${BACKUP_FILE}"; then
        echo -e "${GREEN}✓ Backup written ($(ssh "${SERVER}" "du -h ${BACKUP_FILE} | cut -f1"))${NC}"
        echo -e "  Restore: ssh ${SERVER} \"docker exec -i ${DB_CONTAINER} pg_restore -U postgres --clean -d ${DB_NAME} < ${BACKUP_FILE}\""
    else
        echo -e "${RED}✗ Backup failed; not deploying (use --skip-backup to override)${NC}"
        exit 1
    fi
    echo ""
fi

# Track deployment success
FRONTEND_SUCCESS=true
BACKEND_SUCCESS=true
ELECTRIC_SUCCESS=true

# ============================================================
# DEPLOY FRONTEND
# ============================================================
if [ "$DEPLOY_FRONTEND" = true ]; then
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  Deploying Frontend (container)                         │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${BLUE}[1/3] Pulling frontend ${RELEASE_VERSION} from GHCR...${NC}"
    if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose pull ${FRONTEND_SERVICE}"; then
        echo -e "${GREEN}✓ Frontend image pulled${NC}"
    else
        echo -e "${RED}✗ Failed to pull frontend image${NC}"
        FRONTEND_SUCCESS=false
    fi
    echo ""

    if [ "$FRONTEND_SUCCESS" = true ]; then
        echo -e "${BLUE}[2/3] Restarting frontend container...${NC}"
        if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose up -d ${FRONTEND_SERVICE}"; then
            echo -e "${GREEN}✓ Frontend container restarted${NC}"
        else
            echo -e "${RED}✗ Failed to restart frontend container${NC}"
            FRONTEND_SUCCESS=false
        fi
        echo ""
    fi

    if [ "$FRONTEND_SUCCESS" = true ]; then
        echo -e "${BLUE}[3/3] Checking frontend health...${NC}"
        sleep 3
        FRONTEND_STATUS=$(ssh "${SERVER}" "docker inspect --format='{{.State.Health.Status}}' sertantai_compliance_frontend" 2>/dev/null || echo "unknown")
        if [ "$FRONTEND_STATUS" = "healthy" ]; then
            echo -e "${GREEN}✓ Frontend container is healthy${NC}"
        else
            echo -e "${YELLOW}⚠ Frontend health status: ${FRONTEND_STATUS} (may still be starting)${NC}"
        fi
        echo ""
    fi

    echo -e "${BLUE}Reloading nginx...${NC}"
    if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose exec -T nginx nginx -s reload" 2>/dev/null; then
        echo -e "${GREEN}✓ Nginx reloaded${NC}"
    else
        echo -e "${YELLOW}⚠ Could not reload nginx (may need manual reload)${NC}"
    fi
    echo ""
fi

# ============================================================
# DEPLOY BACKEND
# ============================================================
if [ "$DEPLOY_BACKEND" = true ]; then
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  Deploying Backend                                      │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""

    echo -e "${BLUE}[1/3] Pulling backend ${RELEASE_VERSION} from GHCR...${NC}"
    if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose pull ${BACKEND_SERVICE}"; then
        echo -e "${GREEN}✓ Image pulled successfully${NC}"
    else
        echo -e "${RED}✗ Failed to pull image${NC}"
        BACKEND_SUCCESS=false
    fi
    echo ""

    if [ "$BACKEND_SUCCESS" = true ]; then
        echo -e "${BLUE}[2/3] Restarting container...${NC}"
        if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose up -d ${BACKEND_SERVICE}"; then
            echo -e "${GREEN}✓ Container restarted${NC}"
        else
            echo -e "${RED}✗ Failed to restart container${NC}"
            BACKEND_SUCCESS=false
        fi
        echo ""
    fi

    # Run migrations if requested
    if [ "$BACKEND_SUCCESS" = true ] && [ "$RUN_MIGRATIONS" = true ]; then
        echo -e "${BLUE}[2b] Running migrations...${NC}"
        if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose exec -T ${BACKEND_SERVICE} /app/bin/sertantai_compliance eval 'SertantaiCompliance.Release.migrate'"; then
            echo -e "${GREEN}✓ Migrations complete${NC}"
        else
            echo -e "${RED}✗ Migration failed${NC}"
            BACKEND_SUCCESS=false
        fi
        echo ""
    fi

    if [ "$BACKEND_SUCCESS" = true ]; then
        echo -e "${BLUE}[3/3] Waiting for backend to become healthy...${NC}"
        BACKEND_HEALTHY=false
        for i in 1 2 3 4 5 6; do
            sleep 5
            BACKEND_STATUS=$(ssh "${SERVER}" "docker inspect --format='{{.State.Health.Status}}' sertantai_compliance_app" 2>/dev/null || echo "unknown")
            if [ "$BACKEND_STATUS" = "healthy" ]; then
                BACKEND_HEALTHY=true
                break
            fi
            echo -e "${YELLOW}  Attempt ${i}/6: status=${BACKEND_STATUS} — retrying in 5s...${NC}"
        done

        if [ "$BACKEND_HEALTHY" = true ]; then
            echo -e "${GREEN}✓ Backend is healthy${NC}"
        else
            echo -e "${YELLOW}⚠ Backend health status: ${BACKEND_STATUS} after 30s${NC}"
            echo -e "${YELLOW}  Check logs: ssh ${SERVER} 'cd ${DEPLOY_PATH} && docker compose logs --tail=20 ${BACKEND_SERVICE}'${NC}"
        fi
        echo ""
    fi
fi

# ============================================================
# DEPLOY ELECTRICSQL
# ============================================================
if [ "$DEPLOY_ELECTRIC" = true ] || ([ "$WITH_ELECTRIC" = true ] && [ "$DEPLOY_BACKEND" = true ]); then
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│  Deploying ElectricSQL                                  │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # CRITICAL: Use docker restart, NOT docker-compose up without --no-deps
    # docker-compose up can recreate dependent containers and WIPE the database!

    if [ "$ELECTRIC_CLEAR_CACHE" = true ]; then
        echo -e "${BLUE}[1/3] Stopping Electric container...${NC}"
        if ssh "${SERVER}" "docker stop ${ELECTRIC_CONTAINER}" 2>/dev/null; then
            echo -e "${GREEN}✓ Container stopped${NC}"
        else
            echo -e "${YELLOW}⚠ Container was not running${NC}"
        fi
        echo ""

        echo -e "${BLUE}[2/3] Removing container and clearing cache...${NC}"
        ssh "${SERVER}" "docker rm ${ELECTRIC_CONTAINER}" 2>/dev/null || true
        echo -e "${GREEN}✓ Container removed (cache will be cleared on restart)${NC}"
        echo ""

        echo -e "${BLUE}[3/3] Recreating Electric container (safe - no deps)...${NC}"
        if ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose up -d ${ELECTRIC_COMPOSE_SERVICE} --no-deps"; then
            echo -e "${GREEN}✓ Electric container recreated${NC}"
        else
            echo -e "${RED}✗ Failed to recreate Electric container${NC}"
            ELECTRIC_SUCCESS=false
        fi
    else
        echo -e "${BLUE}[1/1] Restarting Electric container (safe restart)...${NC}"
        if ssh "${SERVER}" "docker restart ${ELECTRIC_CONTAINER}"; then
            echo -e "${GREEN}✓ Electric container restarted${NC}"
        else
            echo -e "${RED}✗ Failed to restart Electric container${NC}"
            echo -e "${YELLOW}  Container may not exist. Try --electric-clear-cache to recreate.${NC}"
            ELECTRIC_SUCCESS=false
        fi
    fi
    echo ""

    if [ "$ELECTRIC_SUCCESS" = true ]; then
        echo -e "${BLUE}Waiting for Electric startup...${NC}"
        sleep 3

        echo -e "${BLUE}Checking Electric health...${NC}"
        ELECTRIC_STATUS=$(ssh "${SERVER}" "docker inspect --format='{{.State.Health.Status}}' ${ELECTRIC_CONTAINER}" 2>/dev/null || echo "unknown")
        if [ "$ELECTRIC_STATUS" = "healthy" ]; then
            echo -e "${GREEN}✓ Electric is healthy${NC}"
        else
            echo -e "${YELLOW}⚠ Electric health status: ${ELECTRIC_STATUS}${NC}"
            echo -e "${YELLOW}  Electric may still be starting up${NC}"
        fi
        echo ""

        echo -e "${BLUE}Electric container status:${NC}"
        ssh "${SERVER}" "docker ps --filter name=${ELECTRIC_CONTAINER} --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
        echo ""
    fi
fi

# ============================================================
# SUMMARY
# ============================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$FRONTEND_SUCCESS" = true ] && [ "$BACKEND_SUCCESS" = true ] && [ "$ELECTRIC_SUCCESS" = true ]; then
    echo -e "${GREEN}✓ Deployment complete!${NC}"

    if [ -n "$RELEASE_VERSION" ] && { [ "$DEPLOY_FRONTEND" = true ] || [ "$DEPLOY_BACKEND" = true ]; }; then
        COMPONENTS="$([ "$DEPLOY_BACKEND" = true ] && echo -n backend)$([ "$DEPLOY_FRONTEND" = true ] && [ "$DEPLOY_BACKEND" = true ] && echo -n +)$([ "$DEPLOY_FRONTEND" = true ] && echo -n frontend)"
        ssh "${SERVER}" "echo '$(date -u +%FT%TZ) ${PREVIOUS_VERSION:-unset} -> ${RELEASE_VERSION} ${COMPONENTS} by $(whoami)@$(hostname -s) from $(git rev-parse --short HEAD)' >> ${DEPLOY_PATH}/compliance-deploy-history.log" \
            && echo -e "${GREEN}✓ Recorded in ${DEPLOY_PATH}/compliance-deploy-history.log${NC}"

        if [ "$DEPLOY_BACKEND" = true ]; then
            LIVE_VERSION="$(curl -sf "${SITE_URL}/health" | sed -nE 's/.*"version":"([^"]+)".*/\1/p')"
            if [ "$LIVE_VERSION" = "$RELEASE_VERSION" ]; then
                echo -e "${GREEN}✓ ${SITE_URL}/health reports ${LIVE_VERSION}${NC}"
            else
                echo -e "${YELLOW}⚠ ${SITE_URL}/health reports '${LIVE_VERSION:-nothing}', expected ${RELEASE_VERSION}${NC}"
            fi
        fi
        [ -n "$PREVIOUS_VERSION" ] && echo -e "  Roll back with: ${YELLOW}$0 --version ${PREVIOUS_VERSION}${NC}"
    fi
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Application:${NC} ${SITE_URL}"
    echo -e "${YELLOW}API:${NC} ${SITE_URL}/api"
    echo -e "${YELLOW}Health:${NC} ${SITE_URL}/health"
    if [ "$DEPLOY_ELECTRIC" = true ] || [ "$WITH_ELECTRIC" = true ]; then
        echo -e "${YELLOW}Electric:${NC} ${ELECTRIC_URL}/v1/health"
    fi
    echo ""

    if [ "$DEPLOY_BACKEND" = true ]; then
        echo -e "${BLUE}Recent backend logs:${NC}"
        ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose logs --tail=10 ${BACKEND_SERVICE}"
        echo ""
    fi

    if [ "$FOLLOW_LOGS" = true ] && [ "$DEPLOY_BACKEND" = true ]; then
        echo -e "${BLUE}Following logs (Ctrl+C to exit)...${NC}"
        echo ""
        ssh "${SERVER}" "cd ${DEPLOY_PATH} && docker compose logs -f ${BACKEND_SERVICE}"
    else
        echo -e "${BLUE}To follow logs:${NC}"
        echo -e "  ${YELLOW}ssh ${SERVER} 'cd ${DEPLOY_PATH} && docker compose logs -f ${BACKEND_SERVICE}'${NC}"
        echo ""
    fi
else
    echo -e "${RED}✗ Deployment failed${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if [ "$DEPLOY_FRONTEND" = true ] && [ "$FRONTEND_SUCCESS" = false ]; then
        echo -e "${RED}  ✗ Frontend deployment failed${NC}"
    fi
    if [ "$DEPLOY_BACKEND" = true ] && [ "$BACKEND_SUCCESS" = false ]; then
        echo -e "${RED}  ✗ Backend deployment failed${NC}"
    fi
    if ([ "$DEPLOY_ELECTRIC" = true ] || [ "$WITH_ELECTRIC" = true ]) && [ "$ELECTRIC_SUCCESS" = false ]; then
        echo -e "${RED}  ✗ ElectricSQL deployment failed${NC}"
    fi
    echo ""
    echo -e "${YELLOW}Check the output above for error details${NC}"
    exit 1
fi
