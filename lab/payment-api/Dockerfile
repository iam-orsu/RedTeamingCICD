FROM node:18-alpine AS base

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Build stage
FROM base AS build

COPY src/ ./src/

# FIXME: srinivas.k - we need to move this to Key Vault before v3 release
# Temporary: build arg so CI can inject during docker build
ARG PAYMENT_API_KEY
ENV PAYMENT_API_KEY=${PAYMENT_API_KEY}

ARG BUILD_DATE
ARG GIT_COMMIT
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"
LABEL org.opencontainers.image.title="ceruleanpay-payment-api"
LABEL org.opencontainers.image.vendor="CeruleanPay Technologies Pvt Ltd"

# Production stage
FROM build AS production

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

USER node

CMD ["node", "src/app.js"]
